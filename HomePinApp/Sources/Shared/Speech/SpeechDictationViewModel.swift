import Foundation
import os

/// 받아쓰기 입력기의 UI 상태 소유자. 별도 인식 "엔진"이 아니라, 마이크로 들은 말을 텍스트로
/// 바꿔 호출 측이 활성 입력 필드(추가=`text`, 검색=`searchText`)에 그대로 채워 넣게 하는
/// 컨트롤러다. 텍스트 입력 경로는 항상 살아 있으므로 이 입력기가 불가용·거부여도 폴백된다.
///
/// 실제 권한/오디오/모델/변환은 비-MainActor `SpeechDictationEngine` 이 담당하고, ViewModel 은
/// 그 엔진이 emit 하는 `DictationEvent` 스트림을 **단일 세션 Task** 로 소비해 `state`/`transcript`
/// 로 매핑한다. 단일 Task 소유 + stop/재토글 시 cancel 로, `.preparing` 중 재토글해도 고아
/// 엔진 자원이 새지 않는다.
@MainActor
@Observable
final class SpeechDictationViewModel {
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

  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "SpeechDictationViewModel")

  /// 현재 받아쓰기 세션을 소비하는 단일 Task. 동시에 둘 이상 두지 않는다.
  private var sessionTask: Task<Void, Never>?

  /// 최종 확정된 텍스트 누적분. volatile 결과는 이 뒤에 임시로 덧붙여 `transcript` 를 만든다.
  private var finalizedText = ""

  /// 무음(텍스트 무변화) 자동 종료 임계 시간. 이 시간 동안 `transcript` 가 안 바뀌면 녹음을 멈춘다.
  private let inactivityTimeout: Duration = .seconds(3)

  /// 무음 자동 종료 타이머. `.recording` 동안만 무장하고, transcript 가 바뀔 때마다 리셋한다.
  /// 세션이 끝나는 모든 경로에서 cancel + nil 로 정리해 고아 타이머가 다음 세션으로 새지 않게 한다.
  private var inactivityTask: Task<Void, Never>?

  // MARK: - 공개 API (CaptureSheet 호출부와 동일 시그니처)

  /// 녹음 중이면 멈추고, 아니면 시작한다.
  func toggle() async {
    if state == .recording || state == .preparing {
      stop()
    } else {
      await start()
    }
  }

  /// 받아쓰기를 시작한다. 이전 세션 Task 는 취소(자원 정리)하고 새 세션을 연다.
  func start() async {
    guard state != .recording, state != .preparing else { return }
    reset()

    let engine = SpeechDictationEngine()
    let stream = engine.start()

    sessionTask = Task { [weak self] in
      await self?.consume(stream)
    }
  }

  /// 녹음을 멈추고 세션 Task 를 취소한다(엔진 자원은 스트림 종료로 정리). 누적 텍스트는 유지.
  func stop() {
    cancelSession()
    if state == .recording || state == .preparing {
      state = .idle
    }
  }

  /// 누적 텍스트와 상태를 초기화한다(다음 받아쓰기를 위해). 세션도 함께 정리한다.
  func reset() {
    cancelSession()
    finalizedText = ""
    transcript = ""
    if state == .recording || state == .preparing {
      state = .idle
    }
  }

  // MARK: - 이벤트 소비

  /// 엔진 이벤트 스트림을 소비해 `state`/`transcript` 로 매핑한다. 단일 세션 Task 에서만 돈다.
  private func consume(_ stream: AsyncThrowingStream<DictationEvent, Error>) async {
    do {
      for try await event in stream {
        apply(event)
      }
    } catch {
      // 스트림이 끝났으므로 무음 타이머도 더 살아 있을 이유가 없다.
      cancelInactivityTimer()
      logger.error("받아쓰기 이벤트 소비 실패: \(error.localizedDescription, privacy: .public)")
      if state == .recording || state == .preparing {
        state = .unavailable(reason: "받아쓰기를 사용할 수 없어요.")
      }
      return
    }

    // 스트림이 사용자 stop 없이 자연 종료됨(인터럽션·인식 자연 종료 등). 이 경로로 빠지면
    // `state` 가 아직 `.recording`/`.preparing` 에 끼어 마이크 버튼이 "멈추기" 로 고착되므로
    // `.idle` 로 되돌린다. transcript 누적분은 그대로 둔다.
    // cancel(stop()/reset()) 로 인한 종료는 그쪽에서 이미 상태를 정하므로 건드리지 않는다.
    // 스트림 자연 종료도 세션 끝 — 고아 무음 타이머가 다음 세션으로 새지 않게 정리한다.
    cancelInactivityTimer()
    guard !Task.isCancelled else { return }
    if state == .recording || state == .preparing {
      state = .idle
    }
  }

  /// 단일 이벤트를 상태/텍스트로 반영한다.
  private func apply(_ event: DictationEvent) {
    switch event {
    case .preparing:
      // 모델 다운로드가 3초를 넘을 수 있어 `.preparing` 중에는 무장하지 않는다.
      state = .preparing
    case .recording:
      state = .recording
      // 실제 녹음 진입 시점에 무음 타이머를 무장한다.
      armInactivityTimer()
    case let .partialTranscript(text):
      updateTranscript(finalizedText + text)
    case let .finalTranscript(text):
      finalizedText += text
      updateTranscript(finalizedText)
    case .permissionDenied:
      state = .denied
    case let .unavailable(reason):
      state = .unavailable(reason: reason)
    }
  }

  /// `transcript` 를 갱신하되, **값이 실제로 바뀐 경우에만** 무음 타이머를 리셋한다("텍스트 변화" 기준).
  private func updateTranscript(_ newValue: String) {
    guard newValue != transcript else { return }
    transcript = newValue
    armInactivityTimer()
  }

  // MARK: - 무음 자동 종료 타이머

  /// 무음 타이머를 (재)무장한다. `.recording` 상태에서만 동작하며, 기존 타이머는 교체된다.
  /// 만료(3초 무변화) 시 `stop()` 으로 graceful 종료한다(사용자 직접 종료와 동일). 멱등.
  private func armInactivityTimer() {
    guard state == .recording else { return }
    inactivityTask?.cancel()
    inactivityTask = Task { [weak self] in
      try? await Task.sleep(for: self?.inactivityTimeout ?? .seconds(3))
      guard !Task.isCancelled else { return }
      guard let self, self.state == .recording else { return }
      // stop() 안에서 inactivityTask 를 cancel 하므로 재진입 없이 안전하게 자기 자신을 정리한다.
      self.stop()
    }
  }

  /// 무음 타이머를 정리한다. 세션이 끝나는 모든 경로에서 호출해 고아 타이머를 막는다. 멱등.
  private func cancelInactivityTimer() {
    inactivityTask?.cancel()
    inactivityTask = nil
  }

  /// 현재 세션 Task 를 취소한다. cancel 이 엔진 스트림의 `onTermination` 을 트리거해
  /// 오디오/analyzer 자원이 정리된다. 무음 타이머도 함께 정리한다. 멱등.
  private func cancelSession() {
    cancelInactivityTimer()
    sessionTask?.cancel()
    sessionTask = nil
  }
}
