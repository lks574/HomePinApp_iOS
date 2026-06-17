import Foundation
import SwiftData

/// CSV 대량 입력 엔진 — Item / Recipe 대상.
///
/// - upsert 키: `id` 컬럼 있으면 id, 없으면 `normalizedName`(Item) / `title`(Recipe).
/// - area/spot/category/tags 는 이름으로 조회→없으면 생성(중복 생성 방지 위해 캐시).
/// - 행 단위 실패는 스킵하고 결과 요약에 사유를 남긴다.
/// - 규칙: `name` 설정 시 `normalizedName` 동반 갱신, 불변식 `spot != nil → item.area == spot.area`.
///
/// 결정: `docs/wiki/Decision/2026-06-17-CSV-대량입력-스키마.md`
@MainActor
struct CSVImporter {
  let modelContext: ModelContext

  // MARK: - 조회/생성 캐시

  private final class Lookup {
    var spacesByName: [String: Space] = [:]
    var areasByKey: [String: Area] = [:] // key = "<spaceName>\u{1}<areaName>"
    var spotsByKey: [String: Spot] = [:] // key = "<areaKey>\u{1}<spotName>"
    var categoriesByName: [String: ItemCategory] = [:]
    var tagsByName: [String: Tag] = [:]
    var itemsByNormalized: [String: Item] = [:]
    var itemsByID: [UUID: Item] = [:]
    var recipesByTitle: [String: Recipe] = [:]
    var recipesByID: [UUID: Recipe] = [:]
  }

  // MARK: - Items import

  func importItems(_ csv: String) throws -> ImportSummary {
    var summary = ImportSummary()
    let table = CSV.parseTable(csv)
    let lookup = try loadLookup()

    for (offset, row) in table.rows.enumerated() {
      let lineNumber = offset + 2 // 헤더가 1행
      let name = row[CSVSchema.Item.name]?.trimmingCharacters(in: .whitespaces) ?? ""
      guard !name.isEmpty else {
        summary.skip("Row \(lineNumber): missing name")
        continue
      }

      let item = resolveItem(row: row, name: name, lookup: lookup)
      item.name = name
      item.normalizedName = Item.normalize(name)
      if let quantity = parseInt(row[CSVSchema.Item.quantity]) { item.quantity = quantity }
      item.memo = nonEmpty(row[CSVSchema.Item.memo])
      item.expiresAt = parseDate(row[CSVSchema.Item.expiresAt])
      item.updatedAt = .now

      // 위치: space → area → spot. 불변식 적용.
      let area = resolveArea(
        spaceName: nonEmpty(row[CSVSchema.Item.space]),
        areaName: nonEmpty(row[CSVSchema.Item.area]),
        lookup: lookup,
      )
      let spot = resolveSpot(area: area, spotName: nonEmpty(row[CSVSchema.Item.spot]), lookup: lookup)
      item.area = spot?.area ?? area
      item.spot = spot
      item.category = resolveCategory(name: nonEmpty(row[CSVSchema.Item.category]), lookup: lookup)
      item.tags = CSVSchema.splitTags(row[CSVSchema.Item.tags] ?? "").map { resolveTag(name: $0, lookup: lookup) }

      summary.count(.item)
    }

    try modelContext.save()
    return summary
  }

  // MARK: - Recipes import

  func importRecipes(_ csv: String) throws -> ImportSummary {
    var summary = ImportSummary()
    let table = CSV.parseTable(csv)
    let lookup = try loadLookup()

    for (offset, row) in table.rows.enumerated() {
      let lineNumber = offset + 2
      let title = row[CSVSchema.Recipe.title]?.trimmingCharacters(in: .whitespaces) ?? ""
      guard !title.isEmpty else {
        summary.skip("Row \(lineNumber): missing title")
        continue
      }

      let recipe = resolveRecipe(row: row, title: title, lookup: lookup)
      recipe.title = title
      recipe.summary = nonEmpty(row[CSVSchema.Recipe.summary])
      recipe.servings = parseInt(row[CSVSchema.Recipe.servings])
      recipe.totalMinutes = parseInt(row[CSVSchema.Recipe.totalMinutes])
      recipe.cuisine = nonEmpty(row[CSVSchema.Recipe.cuisine])
      recipe.dishType = nonEmpty(row[CSVSchema.Recipe.dishType])
      recipe.sourceURL = nonEmpty(row[CSVSchema.Recipe.sourceURL])
      recipe.tags = CSVSchema.splitTags(row[CSVSchema.Recipe.tags] ?? "").map { resolveTag(name: $0, lookup: lookup) }
      recipe.updatedAt = .now

      summary.count(.recipe)
    }

    try modelContext.save()
    return summary
  }

  // MARK: - Recipe ingredients import

  /// 재료는 recipes import 이후에 돌린다(`recipeTitle` 로 연결). 매칭 레시피 없으면 스킵.
  func importRecipeIngredients(_ csv: String) throws -> ImportSummary {
    var summary = ImportSummary()
    let table = CSV.parseTable(csv)
    let lookup = try loadLookup()

    // 같은 레시피에 재료가 다시 들어오면 sortOrder 이어붙이기.
    var nextSortOrder: [UUID: Int] = [:]

    for (offset, row) in table.rows.enumerated() {
      let lineNumber = offset + 2
      let recipeTitle = row[CSVSchema.RecipeIngredient.recipeTitle]?.trimmingCharacters(in: .whitespaces) ?? ""
      let name = row[CSVSchema.RecipeIngredient.name]?.trimmingCharacters(in: .whitespaces) ?? ""
      guard !name.isEmpty else {
        summary.skip("Row \(lineNumber): missing ingredient name")
        continue
      }
      guard let recipe = lookup.recipesByTitle[recipeTitle] else {
        summary.skip("Row \(lineNumber): no recipe titled \"\(recipeTitle)\"")
        continue
      }

      let order = nextSortOrder[recipe.id] ?? recipe.ingredients.count
      nextSortOrder[recipe.id] = order + 1

      let ingredient = RecipeIngredient(
        name: name,
        quantity: parseDouble(row[CSVSchema.RecipeIngredient.quantity]),
        unit: nonEmpty(row[CSVSchema.RecipeIngredient.unit]),
        note: nonEmpty(row[CSVSchema.RecipeIngredient.note]),
        sortOrder: order,
        isOptional: parseBool(row[CSVSchema.RecipeIngredient.isOptional]),
        recipe: recipe,
      )
      modelContext.insert(ingredient)
      // 이름으로 재고 매칭(있으면 grounding).
      ingredient.item = lookup.itemsByNormalized[Item.normalize(name)]
      summary.count(.recipeIngredient)
    }

    try modelContext.save()
    return summary
  }

  // MARK: - 조회 캐시 적재

  private func loadLookup() throws -> Lookup {
    let lookup = Lookup()
    for space in try modelContext.fetch(FetchDescriptor<Space>()) {
      lookup.spacesByName[space.name] = space
    }
    for area in try modelContext.fetch(FetchDescriptor<Area>()) {
      lookup.areasByKey[areaKey(spaceName: area.space?.name, areaName: area.name)] = area
    }
    for spot in try modelContext.fetch(FetchDescriptor<Spot>()) {
      if let area = spot.area {
        let key = areaKey(spaceName: area.space?.name, areaName: area.name)
        lookup.spotsByKey[spotKey(areaKey: key, spotName: spot.name)] = spot
      }
    }
    for category in try modelContext.fetch(FetchDescriptor<ItemCategory>()) {
      lookup.categoriesByName[category.name] = category
    }
    for tag in try modelContext.fetch(FetchDescriptor<Tag>()) {
      lookup.tagsByName[tag.name] = tag
    }
    for item in try modelContext.fetch(FetchDescriptor<Item>()) {
      lookup.itemsByNormalized[item.normalizedName] = item
      lookup.itemsByID[item.id] = item
    }
    for recipe in try modelContext.fetch(FetchDescriptor<Recipe>()) {
      lookup.recipesByTitle[recipe.title] = recipe
      lookup.recipesByID[recipe.id] = recipe
    }
    return lookup
  }

  // MARK: - upsert 키 해석

  private func resolveItem(row: [String: String], name: String, lookup: Lookup) -> Item {
    if let idString = nonEmpty(row[CSVSchema.Item.id]), let id = UUID(uuidString: idString) {
      if let existing = lookup.itemsByID[id] { return existing }
      let item = Item(id: id, name: name)
      modelContext.insert(item)
      lookup.itemsByID[id] = item
      lookup.itemsByNormalized[Item.normalize(name)] = item
      return item
    }
    let normalized = Item.normalize(name)
    if let existing = lookup.itemsByNormalized[normalized] { return existing }
    let item = Item(name: name)
    modelContext.insert(item)
    lookup.itemsByNormalized[normalized] = item
    lookup.itemsByID[item.id] = item
    return item
  }

  private func resolveRecipe(row: [String: String], title: String, lookup: Lookup) -> Recipe {
    if let idString = nonEmpty(row[CSVSchema.Recipe.id]), let id = UUID(uuidString: idString) {
      if let existing = lookup.recipesByID[id] { return existing }
      let recipe = Recipe(id: id, title: title)
      modelContext.insert(recipe)
      lookup.recipesByID[id] = recipe
      lookup.recipesByTitle[title] = recipe
      return recipe
    }
    if let existing = lookup.recipesByTitle[title] { return existing }
    let recipe = Recipe(title: title)
    modelContext.insert(recipe)
    lookup.recipesByTitle[title] = recipe
    lookup.recipesByID[recipe.id] = recipe
    return recipe
  }

  // MARK: - 이름 조회 → 없으면 생성

  private func resolveArea(spaceName: String?, areaName: String?, lookup: Lookup) -> Area? {
    guard let areaName else { return nil }
    let space = resolveSpace(name: spaceName, lookup: lookup)
    let key = areaKey(spaceName: space?.name, areaName: areaName)
    if let existing = lookup.areasByKey[key] { return existing }
    let area = Area(name: areaName, space: space)
    modelContext.insert(area)
    lookup.areasByKey[key] = area
    return area
  }

  private func resolveSpace(name: String?, lookup: Lookup) -> Space? {
    guard let name else { return nil }
    if let existing = lookup.spacesByName[name] { return existing }
    let space = Space(name: name)
    modelContext.insert(space)
    lookup.spacesByName[name] = space
    return space
  }

  private func resolveSpot(area: Area?, spotName: String?, lookup: Lookup) -> Spot? {
    guard let spotName, let area else { return nil }
    let aKey = areaKey(spaceName: area.space?.name, areaName: area.name)
    let key = spotKey(areaKey: aKey, spotName: spotName)
    if let existing = lookup.spotsByKey[key] { return existing }
    let spot = Spot(name: spotName, area: area)
    modelContext.insert(spot)
    lookup.spotsByKey[key] = spot
    return spot
  }

  private func resolveCategory(name: String?, lookup: Lookup) -> ItemCategory? {
    guard let name else { return nil }
    if let existing = lookup.categoriesByName[name] { return existing }
    let category = ItemCategory(name: name)
    modelContext.insert(category)
    lookup.categoriesByName[name] = category
    return category
  }

  private func resolveTag(name: String, lookup: Lookup) -> Tag {
    if let existing = lookup.tagsByName[name] { return existing }
    let tag = Tag(name: name)
    modelContext.insert(tag)
    lookup.tagsByName[name] = tag
    return tag
  }

  // MARK: - 키/파싱 헬퍼

  private func areaKey(spaceName: String?, areaName: String) -> String {
    "\(spaceName ?? "")\u{1}\(areaName)"
  }

  private func spotKey(areaKey: String, spotName: String) -> String {
    "\(areaKey)\u{1}\(spotName)"
  }

  private func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else { return nil }
    return trimmed
  }

  private func parseInt(_ value: String?) -> Int? {
    nonEmpty(value).flatMap(Int.init)
  }

  private func parseDouble(_ value: String?) -> Double? {
    nonEmpty(value).flatMap(Double.init)
  }

  private func parseBool(_ value: String?) -> Bool {
    guard let raw = nonEmpty(value)?.lowercased() else { return false }
    return raw == "true" || raw == "1" || raw == "yes"
  }

  private func parseDate(_ value: String?) -> Date? {
    guard let raw = nonEmpty(value) else { return nil }
    return ISO8601DateFormatter().date(from: raw)
  }
}
