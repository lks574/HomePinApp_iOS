import Foundation
import SwiftData

/// 백업 번들(DTO)을 SwiftData 로 복원하는 2-pass upsert 엔진.
///
/// id(UUID) 기준 병합/덮어쓰기(upsert). 충돌 시 번들 내용으로 필드를 덮어쓴다.
///
/// - **pass-1**: 모든 엔티티를 id 로 조회 → 있으면 스칼라 필드 갱신, 없으면 insert.
/// - **pass-2**: UUID 참조(소속/위치/분류/태그/재료-레시피 등)로 관계를 재연결.
///
/// 엔진이 강제하는 규칙:
/// - `name` 설정 시 `normalizedName` 동반 갱신(`Item.normalize` 동일 함수). Item·ShoppingItem.
/// - 불변식 `spot != nil → item.area == spot.area`.
/// - `ShoppingItem.stockCredited` 값 그대로 보존(재가산 방지).
///
/// 엔티티 단위 실패는 스킵하고 결과 요약(`ImportSummary`)에 누적한다.
///
/// 결정: `docs/wiki/Decision/2026-06-17-데이터-백업-번들포맷.md`
@MainActor
struct BackupUpsertEngine {
  let modelContext: ModelContext

  // MARK: - id 인덱스 (pass-1 결과 캐시)

  private final class Index {
    var spaces: [UUID: Space] = [:]
    var areas: [UUID: Area] = [:]
    var spots: [UUID: Spot] = [:]
    var categories: [UUID: ItemCategory] = [:]
    var tags: [UUID: Tag] = [:]
    var items: [UUID: Item] = [:]
    var recipes: [UUID: Recipe] = [:]
    var ingredients: [UUID: RecipeIngredient] = [:]
    var shoppingItems: [UUID: ShoppingItem] = [:]
  }

  /// 번들을 upsert 하고 결과 요약을 돌려준다. throw 는 치명적 컨텍스트 오류만.
  func apply(_ bundle: BackupBundle) throws -> ImportSummary {
    var summary = ImportSummary()
    let index = try loadIndex()

    upsertPass1(bundle, into: index, summary: &summary)
    reconnectPass2(bundle, index: index, summary: &summary)

    try modelContext.save()
    return summary
  }

  // MARK: - 기존 엔티티 인덱스 적재

  private func loadIndex() throws -> Index {
    let index = Index()
    for space in try modelContext.fetch(FetchDescriptor<Space>()) { index.spaces[space.id] = space }
    for area in try modelContext.fetch(FetchDescriptor<Area>()) { index.areas[area.id] = area }
    for spot in try modelContext.fetch(FetchDescriptor<Spot>()) { index.spots[spot.id] = spot }
    for category in try modelContext.fetch(FetchDescriptor<ItemCategory>()) {
      index.categories[category.id] = category
    }
    for tag in try modelContext.fetch(FetchDescriptor<Tag>()) { index.tags[tag.id] = tag }
    for item in try modelContext.fetch(FetchDescriptor<Item>()) { index.items[item.id] = item }
    for recipe in try modelContext.fetch(FetchDescriptor<Recipe>()) { index.recipes[recipe.id] = recipe }
    for ingredient in try modelContext.fetch(FetchDescriptor<RecipeIngredient>()) {
      index.ingredients[ingredient.id] = ingredient
    }
    for shoppingItem in try modelContext.fetch(FetchDescriptor<ShoppingItem>()) {
      index.shoppingItems[shoppingItem.id] = shoppingItem
    }
    return index
  }

  // MARK: - pass-1: 스칼라 필드 upsert

  private func upsertPass1(_ bundle: BackupBundle, into index: Index, summary: inout ImportSummary) {
    for dto in bundle.spaces {
      let space = resolve(dto.id, in: &index.spaces) { Space(id: dto.id, name: dto.name) }
      space.name = dto.name
      space.icon = dto.icon
      space.sortOrder = dto.sortOrder
      space.createdAt = dto.createdAt
      space.updatedAt = dto.updatedAt
      summary.count(.space)
    }

    for dto in bundle.areas {
      let area = resolve(dto.id, in: &index.areas) { Area(id: dto.id, name: dto.name) }
      area.name = dto.name
      area.icon = dto.icon
      area.sortOrder = dto.sortOrder
      area.createdAt = dto.createdAt
      area.updatedAt = dto.updatedAt
      summary.count(.area)
    }

    for dto in bundle.spots {
      let spot = resolve(dto.id, in: &index.spots) { Spot(id: dto.id, name: dto.name) }
      spot.name = dto.name
      spot.sortOrder = dto.sortOrder
      spot.createdAt = dto.createdAt
      spot.updatedAt = dto.updatedAt
      summary.count(.spot)
    }

    for dto in bundle.categories {
      let category = resolve(dto.id, in: &index.categories) { ItemCategory(id: dto.id, name: dto.name) }
      category.name = dto.name
      category.icon = dto.icon
      category.sortOrder = dto.sortOrder
      category.createdAt = dto.createdAt
      category.updatedAt = dto.updatedAt
      summary.count(.category)
    }

    for dto in bundle.tags {
      let tag = resolve(dto.id, in: &index.tags) { Tag(id: dto.id, name: dto.name) }
      tag.name = dto.name
      tag.createdAt = dto.createdAt
      tag.updatedAt = dto.updatedAt
      summary.count(.tag)
    }

    for dto in bundle.items {
      let item = resolve(dto.id, in: &index.items) { Item(id: dto.id, name: dto.name) }
      item.name = dto.name
      // 규칙: name 설정 시 normalizedName 동반 갱신(번들 값이 비어도 정규화로 보정).
      item.normalizedName = dto.normalizedName.isEmpty ? Item.normalize(dto.name) : dto.normalizedName
      item.quantity = dto.quantity
      item.memo = dto.memo
      item.expiresAt = dto.expiresAt
      item.createdAt = dto.createdAt
      item.updatedAt = dto.updatedAt
      summary.count(.item)
    }

    for dto in bundle.recipes {
      let recipe = resolve(dto.id, in: &index.recipes) { Recipe(id: dto.id, title: dto.title) }
      recipe.title = dto.title
      recipe.summary = dto.summary
      recipe.servings = dto.servings
      recipe.totalMinutes = dto.totalMinutes
      recipe.cuisine = dto.cuisine
      recipe.dishType = dto.dishType
      recipe.sourceURL = dto.sourceURL
      recipe.steps = dto.steps
      recipe.createdAt = dto.createdAt
      recipe.updatedAt = dto.updatedAt
      summary.count(.recipe)
    }

    for dto in bundle.recipeIngredients {
      let ingredient = resolve(dto.id, in: &index.ingredients) { RecipeIngredient(id: dto.id, name: dto.name) }
      ingredient.name = dto.name
      ingredient.quantity = dto.quantity
      ingredient.unit = dto.unit
      ingredient.note = dto.note
      ingredient.sortOrder = dto.sortOrder
      ingredient.isOptional = dto.isOptional
      summary.count(.recipeIngredient)
    }

    for dto in bundle.shoppingItems {
      let shoppingItem = resolve(dto.id, in: &index.shoppingItems) { ShoppingItem(id: dto.id, name: dto.name) }
      shoppingItem.name = dto.name
      shoppingItem.normalizedName = dto.normalizedName.isEmpty
        ? Item.normalize(dto.name)
        : dto.normalizedName
      shoppingItem.quantity = dto.quantity
      shoppingItem.isChecked = dto.isChecked
      // 규칙: stockCredited 값 그대로 보존(재가산 방지).
      shoppingItem.stockCredited = dto.stockCredited
      shoppingItem.createdAt = dto.createdAt
      summary.count(.shoppingItem)
    }
  }

  // MARK: - pass-2: UUID 참조 → 관계 재연결

  private func reconnectPass2(_ bundle: BackupBundle, index: Index, summary: inout ImportSummary) {
    for dto in bundle.areas {
      index.areas[dto.id]?.space = dto.spaceID.flatMap { index.spaces[$0] }
    }

    for dto in bundle.spots {
      index.spots[dto.id]?.area = dto.areaID.flatMap { index.areas[$0] }
    }

    for dto in bundle.items {
      guard let item = index.items[dto.id] else { continue }
      let spot = dto.spotID.flatMap { index.spots[$0] }
      var area = dto.areaID.flatMap { index.areas[$0] }
      // 불변식: spot != nil → item.area == spot.area.
      if let spot { area = spot.area ?? area }
      item.area = area
      item.spot = spot
      item.category = dto.categoryID.flatMap { index.categories[$0] }
      item.tags = dto.tagIDs.compactMap { index.tags[$0] }
    }

    for dto in bundle.recipes {
      index.recipes[dto.id]?.tags = dto.tagIDs.compactMap { index.tags[$0] }
    }

    for dto in bundle.recipeIngredients {
      guard let ingredient = index.ingredients[dto.id] else { continue }
      ingredient.recipe = dto.recipeID.flatMap { index.recipes[$0] }
      ingredient.item = dto.itemID.flatMap { index.items[$0] }
    }

    for dto in bundle.shoppingItems {
      index.shoppingItems[dto.id]?.sourceIngredient = dto.sourceIngredientID.flatMap { index.ingredients[$0] }
    }
  }

  // MARK: - 헬퍼

  /// id 로 기존 모델을 찾으면 그대로, 없으면 `make()` 로 생성·insert·인덱스 등록 후 돌려준다.
  /// (pass-2 가 인덱스로 참조를 재연결하므로 신규 모델도 반드시 인덱스에 등록한다.)
  private func resolve<T: PersistentModel>(
    _ id: UUID,
    in index: inout [UUID: T],
    make: () -> T,
  ) -> T {
    if let existing = index[id] { return existing }
    let model = make()
    modelContext.insert(model)
    index[id] = model
    return model
  }
}
