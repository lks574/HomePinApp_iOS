import AVFoundation
import Foundation
import os
import Speech

/// 온디바이스 받아쓰기 입력기. 별도 인식 "엔진"이 아니라, 마이크로 들은 말을 텍스트로
/// 바꿔 호출 측이 활성 입력 필드(추가=`text`, 검색=`searchText`)에 그대로 채워 넣게 하는
/// 컨트롤러다. 텍스트 입력 경로는 항상 살아 있으므로 이 입력기가 불가용·거부여도 폴백된다.
///
/// 음성 스택은 iOS 26 의 온디바이스 API 를 쓴다 — `SpeechTranscriber`(한국어) 모듈을
/// `SpeechAnalyzer` 로 구동하고, `AVAudioEngine` inputNode tap 으로 모은 PCM 버퍼를
/// 입력 스트림으로 흘려 보낸다. 결과 시퀀스는 volatile(부분)/finalized(최종)을 구분해
/// `transcript` 에 반영한다.
@MainActor
@Observable
final class SpeechDictation {
  enum State: Equatable {
    case idle
    case preparing
    case recording
    /// 기기/모델이 한국어 받아쓰기를 지원하지 않거나 모델 준비에 실패함.
    case unavailable(reason: String)
    /// 마이크 또는 음성 인식 권한이 거부됨.
    case denied
  }

  private(set) var transcript = ""
  private(set) var state: State = .idle

  private let locale = Locale(identifier: "ko-KR")
  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "SpeechDictation")

  private let audioEngine = AVAudioEngine()
  private var transcriber: SpeechTranscriber?
  private var analyzer: SpeechAnalyzer?
  private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
  private var recognitionTask: Task<Void, Never>?

  /// 최종 확정된 텍스트 누적분. volatile 결과는 이 뒤에 임시로 덧붙여 `transcript` 를 만든다.
  private var finalizedText = ""

  // MARK: - 공개 API

  /// 녹음 중이면 멈추고, 아니면 시작한다.
  func toggle() async {
    if state == .recording || state == .preparing {
      stop()
    } else {
      await start()
    }
  }

  /// 권한·모델을 확인하고 받아쓰기를 시작한다. 어떤 단계든 실패하면 정합 상태로 떨어뜨린다.
  func start() async {
    guard state != .recording, state != .preparing else { return }
    reset()
    state = .preparing

    guard await ensurePermissions() else {
      state = .denied
      return
    }

    if isRunningOnSimulator {
      state = .unavailable(reason: "시뮬레이터에서는 받아쓰기를 사용할 수 없어요.")
      return
    }

    do {
      try await beginTranscribing()
      // beginTranscribing 이 모델 미지원 등으로 .unavailable 을 설정했으면 그 상태를 유지한다.
      if state == .preparing {
        state = .recording
      }
    } catch {
      logger.error("받아쓰기 시작 실패: \(error.localizedDescription, privacy: .public)")
      tearDownAudio()
      state = .unavailable(reason: "받아쓰기를 시작할 수 없어요.")
    }
  }

  /// 녹음을 멈추고 오디오/분석 자원을 정리한다. 누적 텍스트는 유지한다.
  func stop() {
    guard state == .recording || state == .preparing else {
      tearDownAudio()
      return
    }
    tearDownAudio()
    state = .idle
  }

  /// 누적 텍스트와 상태를 초기화한다(다음 받아쓰기를 위해). 자원도 함께 정리한다.
  func reset() {
    tearDownAudio()
    finalizedText = ""
    transcript = ""
    if state == .recording || state == .preparing {
      state = .idle
    }
  }

  // MARK: - 권한

  /// 마이크 + 음성 인식 권한을 모두 확보한다. 하나라도 거부되면 false.
  private func ensurePermissions() async -> Bool {
    let micGranted = await requestMicrophonePermissionStatus()
    guard micGranted else { return false }
    let speechGranted = await requestSpeechPermissionStatus()
    return speechGranted
  }

  // MARK: - 받아쓰기 구동

  /// 모델 준비 → analyzer 구성 → 오디오 tap → 결과 소비 태스크 기동까지.
  /// 모델 미지원/미설치 시 `state = .unavailable` 로 떨어뜨리고 throw 하지 않는다.
  private func beginTranscribing() async throws {
    guard SpeechTranscriber.isAvailable else {
      state = .unavailable(reason: "이 기기에서는 받아쓰기를 사용할 수 없어요.")
      return
    }
    guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
      state = .unavailable(reason: "한국어 받아쓰기를 아직 지원하지 않아요.")
      return
    }

    let transcriber = SpeechTranscriber(locale: supportedLocale, preset: .progressiveTranscription)
    self.transcriber = transcriber

    guard try await ensureModelInstalled(for: transcriber) else {
      // ensureModelInstalled 가 state 를 .unavailable 로 설정함.
      return
    }

    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    inputContinuation = continuation

    let analyzer = SpeechAnalyzer(modules: [transcriber])
    self.analyzer = analyzer

    let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

    recognitionTask = Task { [weak self] in
      await self?.consumeResults(from: transcriber)
    }

    try startAudioEngine(continuation: continuation, analysisFormat: analysisFormat)
    try await analyzer.start(inputSequence: stream)
  }

  /// 한국어 모델 자산을 확인하고 필요하면 설치한다. 지원하지 않으면 false + state 설정.
  private func ensureModelInstalled(for transcriber: SpeechTranscriber) async throws -> Bool {
    let status = await AssetInventory.status(forModules: [transcriber])
    switch status {
    case .installed:
      return true
    case .unsupported:
      state = .unavailable(reason: "한국어 받아쓰기를 아직 지원하지 않아요.")
      return false
    case .supported, .downloading:
      guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
        state = .unavailable(reason: "받아쓰기 언어 모델을 준비할 수 없어요.")
        return false
      }
      try await request.downloadAndInstall()
      return true
    @unknown default:
      state = .unavailable(reason: "받아쓰기 언어 모델을 준비할 수 없어요.")
      return false
    }
  }

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

  /// transcriber 결과 시퀀스를 소비해 volatile/finalized 를 구분, `transcript` 를 갱신한다.
  private func consumeResults(from transcriber: SpeechTranscriber) async {
    do {
      var volatileText = ""
      for try await result in transcriber.results {
        let text = String(result.text.characters)
        if result.isFinal {
          finalizedText += text
          volatileText = ""
        } else {
          volatileText = text
        }
        transcript = finalizedText + volatileText
      }
    } catch {
      logger.error("받아쓰기 결과 소비 실패: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - 정리

  /// 오디오 엔진 tap·세션·analyzer 입력 스트림·결과 태스크를 모두 정리한다. 멱등.
  private func tearDownAudio() {
    inputContinuation?.finish()
    inputContinuation = nil

    if audioEngine.isRunning {
      audioEngine.stop()
    }
    audioEngine.inputNode.removeTap(onBus: 0)

    recognitionTask?.cancel()
    recognitionTask = nil

    let analyzer = analyzer
    self.analyzer = nil
    transcriber = nil
    if let analyzer {
      Task { await analyzer.cancelAndFinishNow() }
    }

    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}

/// TCC 권한 콜백은 main queue 에서 실행된다는 보장이 없다. `SpeechDictation` 은
/// `@MainActor` 타입이므로, 권한 브리지는 타입 밖 nonisolated 함수로 두어 콜백 클로저가
/// MainActor 격리를 상속하지 않게 한다.
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
/// 이 함수는 actor 격리 상태를 건드리지 않고 권한 결과만 async 값으로 돌려준다.
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

private var isRunningOnSimulator: Bool {
  #if targetEnvironment(simulator)
    true
  #else
    false
  #endif
}

/// AVAudioEngine tap 은 오디오 스레드에서 호출된다. `@MainActor` 타입 안에서 tap closure 를
/// 만들면 Swift 6 런타임 격리 검사에 걸릴 수 있어, closure 생성 지점을 타입 밖에 둔다.
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
      outputBuffer = buffer
    }
    continuation.yield(AnalyzerInput(buffer: outputBuffer))
  }
}

/// 녹음 포맷 버퍼를 analyzer 가 요구하는 포맷으로 변환한다. 실패 시 nil.
///
/// `AVAudioConverter` 의 입력 콜백은 `@Sendable` 로 취급되므로, 한 번만 버퍼를
/// 넘기고 이후 데이터 없음을 알리는 일회성 상태를 mutable 캡처 대신 참조 타입
/// 박스(`OneShotInput`)에 담아 동시성 경고 없이 전달한다.
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

/// 변환기 입력 콜백에 정확히 한 번 버퍼를 공급하는 일회성 박스. `AVAudioPCMBuffer`/
/// 콜백의 동시성 제약을 우회하지 않고, 가변 상태를 참조 타입으로 격리한다.
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
