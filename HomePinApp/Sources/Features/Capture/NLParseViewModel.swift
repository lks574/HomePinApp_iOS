import Foundation
import os
import SwiftData

/// 자연어 추가 파싱의 UI 상태 소유자. 추론은 비-MainActor `NLItemParser` 가 하고,
/// 이 ViewModel 은 가용성 게이트·파싱 상태·**단일 세션 Task** 소유/cancel 을 맡는다
/// (STT 의 `SpeechDictationViewModel` 패턴 복제).
///
/// 텍스트·음성 공용 단일 경로: `CaptureSheet.add()` 가 같은 텍스트로 `parse(...)` 를
/// 부른다. 가용하지 않거나 실패·취소·빈 결과면 `state` 가 `.unavailable`/`.failed` 로
/// 떨어져 호출 측이 현 단건 스텁(이름 prefill)으로 폴백한다 — 텍스트 경로는 항상 산다.
@MainActor
@Observable
final class NLParseViewModel {
  enum State: Equatable {
    case idle
    /// 추론 중(진행 표시 + 취소 가능).
    case parsing
    /// 파싱 성공 — 확인 드래프트 배열을 보유. 화면 push 트리거.
    case drafts([AddDraft])
    /// 모델 미지원·미설치 등으로 파서 경로 불가(폴백 신호).
    case unavailable
    /// 추론 실패·취소·빈 결과(폴백 신호).
    case failed

    static func == (lhs: State, rhs: State) -> Bool {
      switch (lhs, rhs) {
      case (.idle, .idle), (.parsing, .parsing), (.unavailable, .unavailable), (.failed, .failed):
        true
      case let (.drafts(l), .drafts(r)):
        l.map(\.id) == r.map(\.id)
      default:
        false
      }
    }
  }

  private(set) var state: State = .idle

  private let parser = NLItemParser()
  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "NLParseViewModel")

  /// 현재 파싱을 수행하는 단일 Task. 동시에 둘 이상 두지 않는다.
  private var parseTask: Task<Void, Never>?

  /// 파서 경로를 쓸 수 있는가(모델 `.available`). 그 외면 호출 측은 단건 스텁으로 간다.
  var isAvailable: Bool {
    if case .available = NLItemParser.availability { return true }
    return false
  }

  var isParsing: Bool {
    state == .parsing
  }

  /// 가용성 게이트를 통과하면 파싱을 시작한다. grounding/매칭은 MainActor(SwiftData)에서
  /// 준비하고, 추출만 비-MainActor 파서에 넘긴다. 미가용이면 즉시 `.unavailable`.
  func parse(_ text: String, in modelContext: ModelContext) {
    guard isAvailable else {
      state = .unavailable
      return
    }
    cancel()
    state = .parsing

    let grounding = AddDraftResolver.grounding(in: modelContext)
    let parser = self.parser

    parseTask = Task { [weak self] in
      do {
        let parsed = try await parser.parse(text, grounding: grounding)
        guard !Task.isCancelled else { return }
        let drafts = AddDraftResolver.makeDrafts(from: parsed, in: modelContext)
        guard !drafts.isEmpty else {
          self?.state = .failed
          return
        }
        self?.state = .drafts(drafts)
      } catch is CancellationError {
        // 취소는 호출 측이 상태를 정한다(stub 폴백/dismiss). 여기서 덮어쓰지 않는다.
      } catch {
        self?.logger.error("자연어 파싱 실패: \(error.localizedDescription, privacy: .public)")
        self?.state = .failed
      }
    }
  }

  /// 진행 중 파싱을 취소한다(사용자 취소·시트 종료). 멱등.
  func cancel() {
    parseTask?.cancel()
    parseTask = nil
    if state == .parsing {
      state = .idle
    }
  }

  /// 상태를 초기화한다(다음 입력을 위해). 진행 중 Task 도 정리한다.
  func reset() {
    cancel()
    state = .idle
  }
}
