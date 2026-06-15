import AVFoundation
import Foundation
import os
import Speech

/// 온디바이스 받아쓰기 엔진. 권한·모델·`AVAudioEngine`·tap·변환·결과 소비를 담당하고,
/// UI 가 해석할 의미 단위만 `DictationEvent` 스트림으로 emit 한다.
///
/// `@MainActor` 가 아니다. `AVAudioEngine`/`AVAudioConverter` 의 `Sendable` 경계가 애매하고,
/// 시스템 콜백(권한 TCC, 오디오 tap)을 MainActor 컨텍스트에서 만들면 런타임 격리 트랩으로
/// 크래시났던 이력이 있어서다. 대신 **"엔진 객체는 `start()` 가 만든 단일 소비 Task 안에서만
/// 접근한다"** 는 생명주기 규칙으로 동시성을 푼다. ViewModel 이 그 Task 를 소유하고 cancel 한다.
///
/// 음성 스택은 iOS 26 의 온디바이스 API 를 쓴다 — `SpeechTranscriber`(한국어)를
/// `SpeechAnalyzer` 로 구동하고, inputNode tap 으로 모은 PCM 버퍼를 입력 스트림으로 흘려
/// 보낸다. 결과 시퀀스는 `result.isFinal` 로 partial/final 을 구분해 이벤트로 내보낸다.
/// `@unchecked Sendable` 는 검사를 끄는 것이 아니라 위 생명주기 규칙을 컴파일러에 약속하는
/// 것이다 — 엔진의 가변 상태(audioEngine/transcriber/analyzer/continuation)는 `start()` 가
/// 만든 단일 run Task 안에서만 변경되고 읽히며, `tearDown()` 도 그 Task 안에서만(완료/취소
/// 양쪽 경로의 `defer`) 한 번 호출되어 멱등이다. 스트림 종료 콜백(`onTermination`)은 엔진
/// 상태를 직접 만지지 않고 run Task 를 cancel 하기만 한다 — 종료 컨텍스트(ViewModel MainActor)와
/// run Task 가 같은 상태를 동시에 건드리는 창을 없앤다. 따라서 여러 스레드가 상태를 동시에
/// 건드리지 않는다.
final class SpeechDictationEngine: @unchecked Sendable {
  private let locale = Locale(identifier: "ko-KR")
  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "SpeechDictationEngine")

  private let audioEngine = AVAudioEngine()
  private var transcriber: SpeechTranscriber?
  private var analyzer: SpeechAnalyzer?
  private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?

  // MARK: - 공개 API

  /// 받아쓰기를 시작하고 이벤트 스트림을 돌려준다. 호출 측(ViewModel)은 반환된 스트림을
  /// 단일 Task 로 소비하고, 그 Task 를 cancel 하면 `onTermination` 으로 자원이 정리된다.
  ///
  /// 권한 거부·모델 미지원·시뮬레이터 등은 throw 가 아니라 `permissionDenied`/`unavailable`
  /// 이벤트로 emit 한 뒤 스트림을 finish 한다(텍스트 폴백 보장).
  func start() -> AsyncThrowingStream<DictationEvent, Error> {
    AsyncThrowingStream { continuation in
      let runTask = Task {
        await self.run(emitting: continuation)
      }
      // 스트림 종료(정상 완료/소비 Task cancel/에러)는 모두 여기로 모은다.
      // run Task 를 cancel 하기만 한다 — 자원 teardown 은 run Task 컨텍스트(`run()` 의 defer)
      // 에서만 일어나, 종료 컨텍스트(ViewModel MainActor)와 엔진 상태를 동시에 만지지 않는다.
      // cancel 은 run Task 의 취소 핸들러를 통해 입력 스트림을 finish 시켜 결과 루프를 깨운다.
      continuation.onTermination = { _ in
        runTask.cancel()
      }
    }
  }

  // MARK: - 구동

  /// 권한 → 모델 → analyzer → 오디오 tap → 결과 소비를 순서대로 수행하며 이벤트를 emit 한다.
  /// 어떤 단계든 실패하면 정합한 종료 이벤트를 내보내고 스트림을 finish 한다.
  private func run(emitting continuation: AsyncThrowingStream<DictationEvent, Error>.Continuation) async {
    continuation.yield(.preparing)

    guard await ensurePermissions() else {
      continuation.yield(.permissionDenied)
      continuation.finish()
      return
    }

    if isRunningOnSimulator {
      continuation.yield(.unavailable(reason: "시뮬레이터에서는 받아쓰기를 사용할 수 없어요."))
      continuation.finish()
      return
    }

    guard SpeechTranscriber.isAvailable else {
      continuation.yield(.unavailable(reason: "이 기기에서는 받아쓰기를 사용할 수 없어요."))
      continuation.finish()
      return
    }
    guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
      continuation.yield(.unavailable(reason: "한국어 받아쓰기를 아직 지원하지 않아요."))
      continuation.finish()
      return
    }

    let transcriber = SpeechTranscriber(locale: supportedLocale, preset: .progressiveTranscription)
    self.transcriber = transcriber

    do {
      guard try await ensureModelInstalled(for: transcriber, emitting: continuation) else {
        // ensureModelInstalled 가 unavailable 이벤트를 emit 했다.
        continuation.finish()
        return
      }
    } catch {
      logger.error("모델 준비 실패: \(error.localizedDescription, privacy: .public)")
      continuation.yield(.unavailable(reason: "받아쓰기 언어 모델을 준비할 수 없어요."))
      continuation.finish()
      return
    }

    if Task.isCancelled {
      continuation.finish()
      return
    }

    let (stream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
    self.inputContinuation = inputContinuation

    // 자원이 하나라도 잡힌 시점부터는 어떤 경로(성공·실패·취소)로 빠져나가도 정확히 한 번
    // teardown 한다. teardown 은 이 run Task 컨텍스트에서만 실행되어 엔진 상태 단일 소유를 지킨다.
    defer { tearDown() }

    let analyzer = SpeechAnalyzer(modules: [transcriber])
    self.analyzer = analyzer
    let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

    do {
      try startAudioEngine(continuation: inputContinuation, analysisFormat: analysisFormat)
      try await analyzer.start(inputSequence: stream)
    } catch {
      logger.error("받아쓰기 시작 실패: \(error.localizedDescription, privacy: .public)")
      continuation.yield(.unavailable(reason: "받아쓰기를 시작할 수 없어요."))
      continuation.finish()
      return
    }

    continuation.yield(.recording)
    // 결과 루프(`transcriber.results`)는 Task.cancel 만으로는 깨지 않을 수 있으므로, 취소 시
    // 입력 스트림을 finish 시켜 analyzer→결과 시퀀스를 끝낸다. `Continuation.finish()` 는
    // 스레드 안전·멱등이라 종료 컨텍스트에서 호출해도 엔진 `var` 상태를 건드리지 않는다.
    //
    // 결과 소비와 오디오 인터럽션 감시를 같은 run Task 생명주기 안에서 함께 돈다. 둘 중
    // 무엇이 먼저 끝나든(결과 자연 종료 / 인터럽션 `.began`) 입력 스트림을 finish 시키고
    // 그룹의 남은 자식을 cancel 해 함께 정리한다 — 고아 Task 를 남기지 않는다.
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        await self.consumeResults(from: transcriber, emitting: continuation)
      }
      group.addTask {
        // 인터럽션 감시는 클로저 기반 addObserver 대신 구조적 동시성 친화 AsyncSequence 로
        // run Task 컨텍스트 안에서 소비한다(백그라운드 큐 콜백이 MainActor 격리를 상속해
        // 런타임 격리 트랩으로 크래시났던 이력 방지). `inputContinuation` 은 로컬 값으로
        // 캡처돼 finish() 만 호출 — 엔진 `self.var` 상태는 건드리지 않는다(스레드 안전·멱등).
        await monitorInterruptions(finishingInputWith: inputContinuation)
      }
      // 먼저 끝난 자식(결과 자연 종료 또는 인터럽션 `.began`) 처리 후, 입력 스트림을 finish
      // 시켜 다른 자식(analyzer→결과 루프 / 감시)을 깨우고 그룹 전체를 취소·정리한다.
      await group.next()
      inputContinuation.finish()
      group.cancelAll()
    }
    continuation.finish()
  }

  // MARK: - 권한

  /// 마이크 + 음성 인식 권한을 모두 확보한다. 하나라도 거부되면 false.
  private func ensurePermissions() async -> Bool {
    let micGranted = await requestMicrophonePermissionStatus()
    guard micGranted else { return false }
    return await requestSpeechPermissionStatus()
  }

  /// 한국어 모델 자산을 확인하고 필요하면 설치한다. 지원하지 않으면 false + unavailable emit.
  private func ensureModelInstalled(
    for transcriber: SpeechTranscriber,
    emitting continuation: AsyncThrowingStream<DictationEvent, Error>.Continuation,
  ) async throws -> Bool {
    let status = await AssetInventory.status(forModules: [transcriber])
    switch status {
    case .installed:
      return true
    case .unsupported:
      continuation.yield(.unavailable(reason: "한국어 받아쓰기를 아직 지원하지 않아요."))
      return false
    case .supported, .downloading:
      guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
        continuation.yield(.unavailable(reason: "받아쓰기 언어 모델을 준비할 수 없어요."))
        return false
      }
      try await request.downloadAndInstall()
      return true
    @unknown default:
      continuation.yield(.unavailable(reason: "받아쓰기 언어 모델을 준비할 수 없어요."))
      return false
    }
  }

  // MARK: - 오디오

  /// inputNode tap 으로 PCM 버퍼를 모아 analyzer 입력 스트림으로 흘려 보낸다.
  private func startAudioEngine(
    continuation: AsyncStream<AnalyzerInput>.Continuation,
    analysisFormat: AVAudioFormat?,
  ) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let inputNode = audioEngine.inputNode
    installAnalyzerInputTap(
      on: inputNode,
      continuation: continuation,
      analysisFormat: analysisFormat
    )

    audioEngine.prepare()
    try audioEngine.start()
  }

  /// transcriber 결과 시퀀스를 소비해 partial/final 이벤트로 emit 한다.
  private func consumeResults(
    from transcriber: SpeechTranscriber,
    emitting continuation: AsyncThrowingStream<DictationEvent, Error>.Continuation,
  ) async {
    do {
      for try await result in transcriber.results {
        let text = String(result.text.characters)
        if result.isFinal {
          continuation.yield(.finalTranscript(text))
        } else {
          continuation.yield(.partialTranscript(text))
        }
      }
    } catch {
      logger.error("받아쓰기 결과 소비 실패: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - 정리

  /// 오디오 엔진 tap·세션·analyzer 입력 스트림을 모두 정리한다. 멱등.
  /// `run()` 의 `defer`(정상 완료/실패/취소 모든 경로)에서만, 즉 run Task 컨텍스트에서만
  /// 호출된다 — 종료 컨텍스트와 엔진 상태를 동시에 만지지 않도록 단일 소유를 유지한다.
  private func tearDown() {
    inputContinuation?.finish()
    inputContinuation = nil

    if audioEngine.isRunning {
      audioEngine.stop()
    }
    audioEngine.inputNode.removeTap(onBus: 0)

    let analyzer = analyzer
    self.analyzer = nil
    transcriber = nil
    if let analyzer {
      Task { await analyzer.cancelAndFinishNow() }
    }

    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}

// MARK: - nonisolated 시스템 콜백 브리지

/// TCC 권한 콜백은 main queue 에서 실행된다는 보장이 없다. 콜백 클로저가 actor 격리를
/// 상속하지 않게 타입 밖 nonisolated 함수로 둔다.
private func requestMicrophonePermissionStatus() async -> Bool {
  switch AVAudioApplication.shared.recordPermission {
  case .granted:
    return true
  case .denied:
    return false
  case .undetermined:
    return await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  @unknown default:
    return false
  }
}

/// `SFSpeechRecognizer.requestAuthorization` 의 handler 는 임의의 큐에서 호출될 수 있다.
/// 이 함수는 actor 격리 상태를 건드리지 않고 권한 결과만 async 값으로 돌려준다(권한 게이트
/// 전용 — 인식 경로로는 쓰지 않는다).
private func requestSpeechPermissionStatus() async -> Bool {
  switch SFSpeechRecognizer.authorizationStatus() {
  case .authorized:
    return true
  case .denied, .restricted:
    return false
  case .notDetermined:
    return await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status == .authorized)
      }
    }
  @unknown default:
    return false
  }
}

/// `.recording` 동안 오디오 세션 인터럽션을 감시한다. `.began`(전화·Siri·타 앱 점유)이 오면
/// 입력 스트림을 finish 시켜 받아쓰기 세션을 깔끔히 끝낸다 — analyzer→결과 루프가 종료되고
/// `run()` 의 `defer` 가 teardown 하며, ViewModel `state` 는 스트림 자연 종료 경로로 `.idle`
/// 로 떨어진다(transcript 누적분은 보존).
///
/// 클로저 기반 `NotificationCenter.addObserver` 대신 구조적 동시성 친화 AsyncSequence 를
/// run Task 컨텍스트 안에서 `for await` 로 소비한다. 콜백이 임의 큐에서 호출돼 MainActor
/// 격리를 상속하며 런타임 격리 트랩으로 크래시났던 이력을 막는다. `.ended`(`.shouldResume`
/// 포함)에서는 받아쓰기를 자동 재개하지 않는다 — 사용자가 마이크를 다시 눌러 재시작한다.
private func monitorInterruptions(
  finishingInputWith inputContinuation: AsyncStream<AnalyzerInput>.Continuation,
) async {
  let notifications = NotificationCenter.default.notifications(
    named: AVAudioSession.interruptionNotification
  )
  for await notification in notifications {
    guard
      let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType)
    else { continue }
    if type == .began {
      // 입력 스트림만 닫는다(로컬 캡처값·멱등). 엔진 상태/teardown 은 run Task 가 담당.
      inputContinuation.finish()
      return
    }
    // `.ended` 등은 자동 재개하지 않고 계속 감시(취소되면 for-await 가 빠져나간다).
  }
}

/// 시뮬레이터 capability 분기. 엔진이 직접 들고 `unavailable` 이벤트로 내려보낸다.
private var isRunningOnSimulator: Bool {
  #if targetEnvironment(simulator)
    true
  #else
    false
  #endif
}

/// AVAudioEngine tap 은 오디오 스레드에서 호출된다. tap closure 생성 지점을 타입 밖에 둬
/// MainActor/actor 격리 상속을 피한다.
private func installAnalyzerInputTap(
  on inputNode: AVAudioInputNode,
  continuation: AsyncStream<AnalyzerInput>.Continuation,
  analysisFormat: AVAudioFormat?,
) {
  let recordingFormat = inputNode.outputFormat(forBus: 0)
  let converter = analysisFormat.flatMap { AVAudioConverter(from: recordingFormat, to: $0) }

  inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
    let outputBuffer: AVAudioPCMBuffer
    if let converter, let analysisFormat {
      guard let converted = convertAudioBuffer(buffer, using: converter, to: analysisFormat) else { return }
      outputBuffer = converted
    } else {
      // (a) 버그 수정: tap buffer 는 오디오 스레드가 재사용하므로 복사 없이 yield 하면
      // 데이터 레이스가 난다. 변환 없는 경로도 새 버퍼로 복사한 뒤 yield 한다.
      guard let copied = copyAudioBuffer(buffer) else { return }
      outputBuffer = copied
    }
    continuation.yield(AnalyzerInput(buffer: outputBuffer))
  }
}

/// tap 버퍼를 동일 포맷의 새 `AVAudioPCMBuffer` 로 깊은 복사한다. 오디오 스레드가 원본을
/// 재사용해도 소비 측이 안전하게 들고 있을 수 있도록 한다. 실패 시 nil.
private func copyAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
  guard
    let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity)
  else { return nil }
  copy.frameLength = buffer.frameLength

  let channelCount = Int(buffer.format.channelCount)
  let frameLength = Int(buffer.frameLength)

  if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
    for channel in 0..<channelCount {
      dst[channel].update(from: src[channel], count: frameLength)
    }
  } else if let src = buffer.int16ChannelData, let dst = copy.int16ChannelData {
    for channel in 0..<channelCount {
      dst[channel].update(from: src[channel], count: frameLength)
    }
  } else if let src = buffer.int32ChannelData, let dst = copy.int32ChannelData {
    for channel in 0..<channelCount {
      dst[channel].update(from: src[channel], count: frameLength)
    }
  } else {
    return nil
  }
  return copy
}

/// 녹음 포맷 버퍼를 analyzer 가 요구하는 포맷으로 변환한다. 실패 시 nil.
///
/// `AVAudioConverter` 의 입력 콜백은 `@Sendable` 로 취급되므로, 한 번만 버퍼를 넘기고 이후
/// 데이터 없음을 알리는 일회성 상태를 mutable 캡처 대신 참조 타입 박스(`OneShotInput`)에 담는다.
/// 변환 결과 버퍼는 새로 할당되므로 tap 버퍼 재사용과 분리된다.
private func convertAudioBuffer(
  _ buffer: AVAudioPCMBuffer,
  using converter: AVAudioConverter,
  to format: AVAudioFormat,
) -> AVAudioPCMBuffer? {
  let ratio = format.sampleRate / buffer.format.sampleRate
  let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
  guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

  let input = OneShotInput(buffer: buffer)
  var conversionError: NSError?
  converter.convert(to: output, error: &conversionError) { _, statusPointer in
    input.next(status: statusPointer)
  }
  if conversionError != nil { return nil }
  return output
}

/// 변환기 입력 콜백에 정확히 한 번 버퍼를 공급하는 일회성 박스. `AVAudioPCMBuffer`/콜백의
/// 동시성 제약을 우회하지 않고, 가변 상태를 참조 타입으로 격리한다.
private final class OneShotInput: @unchecked Sendable {
  private let buffer: AVAudioPCMBuffer
  private var consumed = false

  init(buffer: AVAudioPCMBuffer) {
    self.buffer = buffer
  }

  func next(status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
    if consumed {
      status.pointee = .noDataNow
      return nil
    }
    consumed = true
    status.pointee = .haveData
    return buffer
  }
}
