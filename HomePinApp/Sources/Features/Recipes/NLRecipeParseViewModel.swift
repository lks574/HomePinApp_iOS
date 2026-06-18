import Foundation
import os

/// 레시피 자연어 파싱의 UI 상태 소유자. 추론은 비-MainActor `NLRecipeParser` 가 하고,
/// 이 ViewModel 은 가용성 게이트·파싱 상태·**단일 세션 Task** 소유/cancel 을 맡는다.
///
/// 텍스트·붙여넣기·음성 공용 단일 경로: 레시피 입력 화면이 같은 텍스트로 `parse(...)` 를
/// 부른다. 가용하지 않거나 실패·취소·빈 결과면 `state` 가 `.unavailable`/`.failed` 로 떨어져
/// 호출 측이 수동 에디터(빈 또는 제목만 prefill)로 폴백한다 — 수동 입력 경로는 항상 산다.
@MainActor
@Observable
final class NLRecipeParseViewModel {
  enum State: Equatable {
    case idle
    /// 추론 중(진행 표시 + 취소 가능).
    case parsing
    /// 파싱 성공 — 에디터 prefill 을 보유. 확인 시트 제시 트리거.
    case prefill(RecipeEditorPrefill)
    /// 모델 미지원·미설치 등으로 파서 경로 불가(폴백 신호).
    case unavailable
    /// 추론 실패·취소·빈 결과(폴백 신호).
    case failed

    static func == (lhs: State, rhs: State) -> Bool {
      switch (lhs, rhs) {
      case (.idle, .idle), (.parsing, .parsing), (.unavailable, .unavailable), (.failed, .failed):
        true
      case let (.prefill(l), .prefill(r)):
        l.title == r.title && l.ingredients.count == r.ingredients.count && l.steps == r.steps
      default:
        false
      }
    }
  }

  private(set) var state: State = .idle

  private let parser = NLRecipeParser()
  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "NLRecipeParseViewModel")

  /// 현재 파싱을 수행하는 단일 Task. 동시에 둘 이상 두지 않는다.
  private var parseTask: Task<Void, Never>?

  /// 파서 경로를 쓸 수 있는가(모델 `.available`). 그 외면 호출 측은 수동 에디터로 간다.
  var isAvailable: Bool {
    if case .available = NLRecipeParser.availability { return true }
    return false
  }

  var isParsing: Bool {
    state == .parsing
  }

  /// 가용성 게이트를 통과하면 파싱을 시작한다. grounding 은 `RecipeDraftResolver`(정적 분류
  /// 후보)에서 준비하고, 추출만 비-MainActor 파서에 넘긴다. 미가용이면 즉시 `.unavailable`.
  func parse(_ text: String) {
    guard isAvailable else {
      state = .unavailable
      return
    }
    cancel()
    state = .parsing

    let grounding = RecipeDraftResolver.grounding
    let parser = self.parser

    parseTask = Task { [weak self] in
      do {
        let parsed = try await parser.parse(text, grounding: grounding)
        guard !Task.isCancelled else { return }
        let prefill = RecipeDraftResolver.prefill(from: parsed)
        guard !prefill.title.isEmpty || !prefill.ingredients.isEmpty || !prefill.steps.isEmpty else {
          self?.state = .failed
          return
        }
        self?.state = .prefill(prefill)
      } catch is CancellationError {
        // 취소는 호출 측이 상태를 정한다(폴백/dismiss). 여기서 덮어쓰지 않는다.
      } catch {
        self?.logger.error("레시피 자연어 파싱 실패: \(error.localizedDescription, privacy: .public)")
        self?.state = .failed
      }
    }
  }

  /// 진행 중 파싱을 취소한다(사용자 취소·화면 종료). 멱등.
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
