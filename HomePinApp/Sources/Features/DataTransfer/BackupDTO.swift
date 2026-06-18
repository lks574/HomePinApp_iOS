import Foundation

/// 전체 데이터 백업 번들의 직렬화 표현(`data.json`).
///
/// 9개 `@Model` 에 대응하는 Codable DTO 묶음이다. 설계 원칙:
/// - **관계는 객체 중첩 금지, 전부 UUID 참조** — 순환 참조·중복 직렬화를 피하고
///   import 시 2-pass(엔티티 upsert → 참조 재연결)로 복원한다.
/// - `RecipeStep` 은 이미 Codable 값 타입이라 `RecipeDTO` 안에 값배열로 인라인한다.
///
/// 결정: `docs/wiki/Decision/2026-06-17-데이터-백업-번들포맷.md`
struct BackupBundle: Codable {
  /// 스키마 버전. import 시 가드에 쓴다(상위 버전 번들은 거부).
  var schemaVersion: Int
  /// 백업 생성 시각(ISO8601, 정보용).
  var exportedAt: Date

  var spaces: [SpaceDTO]
  var areas: [AreaDTO]
  var spots: [SpotDTO]
  var categories: [ItemCategoryDTO]
  var tags: [TagDTO]
  var items: [ItemDTO]
  var recipes: [RecipeDTO]
  var recipeIngredients: [RecipeIngredientDTO]
  var shoppingItems: [ShoppingItemDTO]

  /// 현재 앱이 쓰는 백업 스키마 버전. 모델 구조가 바뀌면 올린다.
  static let currentSchemaVersion = 1
}

// MARK: - 엔티티 DTO

struct SpaceDTO: Codable {
  var id: UUID
  var name: String
  var icon: String?
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date
}

struct AreaDTO: Codable {
  var id: UUID
  var name: String
  var icon: String?
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date
  /// 상위 공간(`Space`) 참조.
  var spaceID: UUID?
}

struct SpotDTO: Codable {
  var id: UUID
  var name: String
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date
  /// 상위 구역(`Area`) 참조.
  var areaID: UUID?
}

struct ItemCategoryDTO: Codable {
  var id: UUID
  var name: String
  var icon: String?
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date
}

struct TagDTO: Codable {
  var id: UUID
  var name: String
  var createdAt: Date
  var updatedAt: Date
}

struct ItemDTO: Codable {
  var id: UUID
  var name: String
  var normalizedName: String
  var quantity: Int
  var memo: String?
  var expiresAt: Date?
  var createdAt: Date
  var updatedAt: Date
  /// 위치/분류 참조(nullify 보존되므로 옵셔널).
  var areaID: UUID?
  var spotID: UUID?
  var categoryID: UUID?
  /// 태그(N:N) 참조 목록.
  var tagIDs: [UUID]
}

struct RecipeDTO: Codable {
  var id: UUID
  var title: String
  var summary: String?
  var servings: Int?
  var totalMinutes: Int?
  var cuisine: String?
  var dishType: String?
  var sourceURL: String?
  /// 조리 단계 — 이미 Codable 값 타입이라 인라인.
  var steps: [RecipeStep]
  var createdAt: Date
  var updatedAt: Date
  /// 태그(N:N) 참조 목록.
  var tagIDs: [UUID]
}

struct RecipeIngredientDTO: Codable {
  var id: UUID
  var name: String
  var quantity: Double?
  var unit: String?
  var note: String?
  var sortOrder: Int
  var isOptional: Bool
  /// 소속 레시피 참조.
  var recipeID: UUID?
  /// 매칭된 재고(`Item`) 참조.
  var itemID: UUID?
}

struct ShoppingItemDTO: Codable {
  var id: UUID
  var name: String
  var normalizedName: String
  var quantity: Int?
  var isChecked: Bool
  /// 재고 가산 여부. import 시 값 그대로 보존(재가산 방지).
  var stockCredited: Bool
  var createdAt: Date
  /// 부족분 출처 재료(`RecipeIngredient`) 참조.
  var sourceIngredientID: UUID?
}
