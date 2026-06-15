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
      logger.error("받아쓰기 이벤트 소비 실패: \(error.localizedDescription, privacy: .public)")
      if state == .recording || state == .preparing {
        state = .unavailable(reason: "받아쓰기를 사용할 수 없어요.")
      }
    }
  }

  /// 단일 이벤트를 상태/텍스트로 반영한다.
  private func apply(_ event: DictationEvent) {
    switch event {
    case .preparing:
      state = .preparing
    case .recording:
      state = .recording
    case let .partialTranscript(text):
      transcript = finalizedText + text
    case let .finalTranscript(text):
      finalizedText += text
      transcript = finalizedText
    case .permissionDenied:
      state = .denied
    case let .unavailable(reason):
      state = .unavailable(reason: reason)
    }
  }

  /// 현재 세션 Task 를 취소한다. cancel 이 엔진 스트림의 `onTermination` 을 트리거해
  /// 오디오/analyzer 자원이 정리된다. 멱등.
  private func cancelSession() {
    sessionTask?.cancel()
    sessionTask = nil
  }
}
