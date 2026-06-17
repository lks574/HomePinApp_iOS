import Foundation
import SwiftData

/// CSV 대량 입력 스키마 — Item / Recipe 두 가지 대상.
/// 3개 파일로 나눈다: `items.csv`, `recipes.csv`, `recipe_ingredients.csv`.
/// 재료는 `recipeTitle` 로 레시피와 연결한다(별도 id 불필요).
///
/// 결정: `docs/wiki/Decision/2026-06-17-CSV-대량입력-스키마.md`
enum CSVSchema {
  // MARK: - 파일명

  static let itemsFileName = "items.csv"
  static let recipesFileName = "recipes.csv"
  static let recipeIngredientsFileName = "recipe_ingredients.csv"

  // MARK: - 컬럼 (헤더 순서 = 템플릿 순서)

  /// items.csv 컬럼. `id` 있으면 id, 없으면 `name` 정규화로 upsert.
  /// area/spot/category/tags 는 이름으로 조회→없으면 생성.
  enum Item {
    static let id = "id"
    static let name = "name"
    static let quantity = "quantity"
    static let space = "space"
    static let area = "area"
    static let spot = "spot"
    static let category = "category"
    /// 세미콜론(`;`)으로 구분된 태그 목록.
    static let tags = "tags"
    static let memo = "memo"
    /// ISO8601 날짜(예: 2026-06-30T00:00:00Z). 비면 미설정.
    static let expiresAt = "expiresAt"

    static let header = [id, name, quantity, space, area, spot, category, tags, memo, expiresAt]
  }

  /// recipes.csv 컬럼. `id` 있으면 id, 없으면 `title` 로 upsert(레시피는 title 기준).
  enum Recipe {
    static let id = "id"
    static let title = "title"
    static let summary = "summary"
    static let servings = "servings"
    static let totalMinutes = "totalMinutes"
    static let cuisine = "cuisine"
    static let dishType = "dishType"
    static let sourceURL = "sourceURL"
    /// 세미콜론(`;`)으로 구분된 태그 목록.
    static let tags = "tags"

    static let header = [id, title, summary, servings, totalMinutes, cuisine, dishType, sourceURL, tags]
  }

  /// recipe_ingredients.csv 컬럼. `recipeTitle` 로 소속 레시피 연결.
  enum RecipeIngredient {
    static let recipeTitle = "recipeTitle"
    static let name = "name"
    static let quantity = "quantity"
    static let unit = "unit"
    static let note = "note"
    /// "true"/"1" 이면 부재료.
    static let isOptional = "isOptional"

    static let header = [recipeTitle, name, quantity, unit, note, isOptional]
  }

  // MARK: - 태그 구분

  static let tagSeparator: Character = ";"

  static func splitTags(_ raw: String) -> [String] {
    raw.split(separator: tagSeparator)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  static func joinTags(_ names: [String]) -> String {
    names.joined(separator: String(tagSeparator))
  }

  // MARK: - 템플릿 (헤더 + 예시 1행)

  static func itemsTemplate() -> String {
    CSV.serialize(
      header: Item.header,
      rows: [["", "양파", "3", "집", "주방", "냉장고", "채소", "신선식품;상비", "", ""]],
    )
  }

  static func recipesTemplate() -> String {
    CSV.serialize(
      header: Recipe.header,
      rows: [["", "김치찌개", "돼지고기 김치찌개", "2", "30", "한식", "찌개", "", "집밥"]],
    )
  }

  static func recipeIngredientsTemplate() -> String {
    CSV.serialize(
      header: RecipeIngredient.header,
      rows: [
        ["김치찌개", "김치", "200", "g", "신김치", "false"],
        ["김치찌개", "대파", "1", "대", "", "true"],
      ],
    )
  }
}
