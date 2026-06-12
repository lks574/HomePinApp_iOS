import Foundation

/// 조리 단계 — `Recipe.steps` 에 값 배열로 저장하는 Codable 값 타입(@Model 아님).
/// 순서는 배열 순서. `minutes` 는 단계 타이머용(선택).
struct RecipeStep: Codable, Hashable {
  var text: String
  var minutes: Int?

  init(text: String, minutes: Int? = nil) {
    self.text = text
    self.minutes = minutes
  }
}
