import Foundation
import SwiftData

/// 레시피 — 저장 + 재고 연동. 재료(`RecipeIngredient`)는 재고(`Item`)와 매칭해
/// 보유/부족을 판정한다(상세: Decision 노트 "레시피 모델").
@Model
final class Recipe {
  @Attribute(.unique) var id: UUID
  var title: String
  var summary: String?
  var servings: Int?
  var totalMinutes: Int?
  /// 요리권(한식/일식/중식/양식/분식 등). 목록 필터·에디터 칩과 연동.
  var cuisine: String?
  /// 요리 종류(국·찌개/볶음/구이/조림/밥·면/반찬 등). 목록 필터·에디터 칩과 연동.
  var dishType: String?
  var sourceURL: String?
  /// 조리 단계(값 배열, 순서=배열 순서).
  var steps: [RecipeStep]
  var createdAt: Date
  var updatedAt: Date

  @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
  var ingredients: [RecipeIngredient]

  @Relationship(inverse: \Tag.recipes)
  var tags: [Tag]

  init(
    id: UUID = UUID(),
    title: String,
    summary: String? = nil,
    servings: Int? = nil,
    totalMinutes: Int? = nil,
    cuisine: String? = nil,
    dishType: String? = nil,
    sourceURL: String? = nil,
    steps: [RecipeStep] = [],
    createdAt: Date = .now,
    updatedAt: Date = .now,
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.servings = servings
    self.totalMinutes = totalMinutes
    self.cuisine = cuisine
    self.dishType = dishType
    self.sourceURL = sourceURL
    self.steps = steps
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.ingredients = []
    self.tags = []
  }

  /// 재고에 없는 재료(매칭 Item 없음 또는 수량 0) 목록.
  var missingIngredients: [RecipeIngredient] {
    ingredients.filter { !$0.isInStock }
  }

  /// 없는 재료가 0이면 지금 만들 수 있다.
  var isReadyToCook: Bool {
    missingIngredients.isEmpty
  }

  /// 보유 중인 재료 수.
  var inStockCount: Int {
    ingredients.filter(\.isInStock).count
  }

  /// 임박(곧 만료) 재료를 하나라도 쓰는가.
  var usesExpiringIngredient: Bool {
    ingredients.contains { $0.item?.isExpiringSoon ?? false }
  }
}
