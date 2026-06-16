import FoundationModels
import os

/// 자연어(텍스트·음성·붙여넣기 공용) → 구조화 레시피 드래프트 추출 엔진. 온디바이스
/// Foundation Models(`LanguageModelSession`)로 레시피 덩어리 텍스트를 `ParsedRecipe` 로 뽑는다.
///
/// `NLItemParser`(물건 전용) 패턴을 그대로 본떴다 — **추출만** 한다. `Recipe`·SwiftData·
/// 재고 매칭은 일절 모른다. 출력은 전부 문자열/정수고, cuisine/dishType raw 매핑·재료
/// Item grounding 은 도메인 측(`RecipeDraftResolver`)이 확인 화면 prefill 직전에 한다.
/// 추출(엔진)과 매칭(도메인)을 분리해 모델 표류를 도메인 경계에서 흡수한다.
///
/// 동시성: `@MainActor` 가 아니다. 호출 측(`NLRecipeParseViewModel`)이 단일 파싱 Task 안에서만
/// `parse(...)` 를 호출하고 그 Task 를 cancel 한다 — `NLItemParser`·STT 엔진과 같은
/// "단일 소비 Task" 생명주기. `LanguageModelSession` 은 `parse(...)` 호출마다 새로 만들어
/// 메서드 스코프를 벗어나지 않으므로 공유 가변 상태가 없다.
struct NLRecipeParser {
  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "NLRecipeParser")

  /// 모델 가용성. `.available` 이 아니면 호출 측은 즉시 수동 에디터로 폴백한다.
  static var availability: SystemLanguageModel.Availability {
    SystemLanguageModel.default.availability
  }

  /// 자연어 레시피 텍스트에서 제목·재료·단계 등을 추출한다. 기존 분류(cuisine/dishType)
  /// 후보를 프롬프트에 주입해 자유 텍스트 표류를 줄인다. 실패·취소·빈 결과는 throw 하고,
  /// 호출 측이 수동 에디터(빈/이름만 prefill)로 폴백한다.
  func parse(_ text: String, grounding: NLRecipeGrounding) async throws -> ParsedRecipe {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw RecipeParseError.emptyInput }

    let session = LanguageModelSession(instructions: Self.instructions(grounding))
    let prompt = "다음 텍스트에서 레시피를 구조화해 뽑아줘:\n\(trimmed)"

    let response = try await session.respond(to: prompt, generating: ParsedRecipe.self)
    return response.content
  }

  /// 분류 후보를 주입한 시스템 지시문. 후보가 비면 그 줄을 생략한다.
  private static func instructions(_ grounding: NLRecipeGrounding) -> String {
    var lines = [
      "너는 가정용 레시피 관리 앱의 입력 도우미다. 사용자가 한국어로 말하거나 적거나 붙여넣은",
      "텍스트(블로그·메모·메신저 등)에서 레시피 하나를 구조화해 뽑는다.",
      "재료는 이름과 수량(예: \"돼지고기 200g\", \"김치 한 컵\")으로 분리하고, 단계는 조리 순서대로",
      "한 줄씩 나눈다. 텍스트에 없는 값은 지어내지 말고 빈 문자열·0·빈 배열로 둔다.",
      "인분·총 조리시간(분)은 단서가 있을 때만 채운다.",
      "각 재료의 isOptional 은 필수 주재료면 false, 곁들임·취향껏·선택적 부재료(예: \"기호에 따라\",",
      "\"있으면\", \"고명/토핑\")면 true 로 둔다. 애매하면 false(주재료)로 둔다.",
    ]
    if !grounding.cuisines.isEmpty {
      lines.append("요리권(cuisine) 후보: \(grounding.cuisines.joined(separator: ", ")). 해당하면 이 중 하나를 쓰고 아니면 비운다.")
    }
    if !grounding.dishTypes.isEmpty {
      lines.append("요리 종류(dishType) 후보: \(grounding.dishTypes.joined(separator: ", ")). 해당하면 이 중 하나를 쓰고 아니면 비운다.")
    }
    return lines.joined(separator: "\n")
  }
}

/// 프롬프트에 주입할 분류 후보(raw 키 문자열). 도메인 측이 `RecipeClassification` 에서
/// 모아 엔진에 넘긴다 — 엔진은 SwiftData·도메인을 모른다.
struct NLRecipeGrounding: Sendable {
  var cuisines: [String]
  var dishTypes: [String]

  static let empty = NLRecipeGrounding(cuisines: [], dishTypes: [])
}

/// 레시피 파싱 실패 사유. 빈 입력은 별도 케이스로 구분해 호출 측이 폴백 메시지를 정한다.
enum RecipeParseError: Error {
  case emptyInput
}

/// 추출한 레시피. 전부 문자열/정수 — 도메인 매칭(분류 raw·재료 Item)은 확인 화면 prefill
/// 직전에 한다. 단계별 타이머는 파싱 대상 아님(확인 화면에서 수동 입력).
@Generable
struct ParsedRecipe {
  @Guide(description: "레시피 제목")
  var title: String
  @Guide(description: "요리권: 한식/일식/중식/양식/분식 등. 단서 없으면 빈 문자열")
  var cuisine: String
  @Guide(description: "요리 종류: 국·찌개/볶음/구이/조림/밥·면/반찬 등. 단서 없으면 빈 문자열")
  var dishType: String
  @Guide(description: "인분 수. 단서 없으면 0")
  var servings: Int
  @Guide(description: "총 조리시간(분). 단서 없으면 0")
  var totalMinutes: Int
  @Guide(description: "재료 목록(이름과 수량)")
  var ingredients: [ParsedIngredient]
  @Guide(description: "조리 단계 목록. 한 단계당 한 문자열, 순서대로")
  var steps: [String]
}

/// 추출한 단일 재료. 수량은 자유 문자열(예: \"200g\", \"한 컵\", \"2\")로 둔다 — 단위 분해는
/// 확인 화면에서 사용자가 한다.
@Generable
struct ParsedIngredient {
  @Guide(description: "재료 이름")
  var name: String
  @Guide(description: "수량(예: 200g, 한 컵, 2). 단서 없으면 빈 문자열")
  var quantity: String
  @Guide(description: "필수 주재료는 false, 곁들임·취향껏·선택적 부재료면 true. 애매하면 false")
  var isOptional: Bool
}
