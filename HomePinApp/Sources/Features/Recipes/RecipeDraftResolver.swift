import Foundation

/// 파서가 뽑은 순수 문자열(`ParsedRecipe`)과 레시피 도메인 사이의 경계.
/// 엔진은 추출만 하고(분류/재고 무지), 분류 raw 정규화·draft 행 변환은 전부 여기서 한다.
///
/// 재료 Item grounding(재고 매칭)은 `RecipeEditorModel.save(into:)` 가 저장 직전에
/// `availableItems` 와 이름 정규화로 수행하므로(기존 수동 에디터와 동일 경로), 여기서는
/// 사전 매칭하지 않고 draft 값만 채운다 — 매칭 로직 중복을 피한다.
enum RecipeDraftResolver {
  /// 엔진 프롬프트에 주입할 분류 후보(raw 키). 단일 소스 `RecipeClassification` 에서 모은다.
  static var grounding: NLRecipeGrounding {
    NLRecipeGrounding(
      cuisines: RecipeClassification.cuisineKeys,
      dishTypes: RecipeClassification.dishTypeKeys
    )
  }

  /// 추출된 레시피를 에디터 prefill 로 해석한다(저장 아님). 분류는 raw 후보에 정확히
  /// 일치할 때만 채우고(표류 흡수), 인분·시간은 0 이면 빈 문자열로 둔다. 재료 수량은
  /// 자유 문자열이라 단위 분리 없이 quantity 에 그대로 넣는다(확인 화면에서 사용자가 정리).
  static func prefill(from parsed: ParsedRecipe) -> RecipeEditorPrefill {
    RecipeEditorPrefill(
      title: parsed.title.trimmingCharacters(in: .whitespacesAndNewlines),
      cuisine: matchedKey(parsed.cuisine, in: RecipeClassification.cuisineKeys),
      dishType: matchedKey(parsed.dishType, in: RecipeClassification.dishTypeKeys),
      servings: positiveOrEmpty(parsed.servings),
      totalMinutes: positiveOrEmpty(parsed.totalMinutes),
      ingredients: parsed.ingredients.compactMap { ingredient in
        let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return RecipeEditorPrefill.Ingredient(
          name: name,
          quantity: ingredient.quantity.trimmingCharacters(in: .whitespacesAndNewlines),
          unit: "",
          isOptional: ingredient.isOptional
        )
      },
      steps: parsed.steps
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    )
  }

  /// raw 후보 키와 정규화 일치하면 그 raw 키를 반환, 아니면 빈 문자열(미선택).
  private static func matchedKey(_ raw: String, in keys: [String]) -> String {
    let normalized = Item.normalize(raw)
    guard !normalized.isEmpty else { return "" }
    return keys.first { Item.normalize($0) == normalized } ?? ""
  }

  /// 양수면 문자열로, 0 이하면 빈 문자열(에디터의 빈 필드 표현).
  private static func positiveOrEmpty(_ value: Int) -> String {
    value > 0 ? String(value) : ""
  }
}

/// AI 파싱 결과를 `RecipeEditorModel` create prefill 로 옮기는 값 묶음.
/// 분류는 이미 raw 키로 정규화된 값이고, 재료/단계는 trim·필터가 끝난 값이다.
struct RecipeEditorPrefill {
  struct Ingredient {
    var name: String
    var quantity: String
    var unit: String
    var isOptional: Bool = false
  }

  var title: String
  var cuisine: String
  var dishType: String
  var servings: String
  var totalMinutes: String
  var ingredients: [Ingredient]
  var steps: [String]
}
