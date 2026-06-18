import Foundation

/// `@Model` ↔ DTO 변환과 JSON 인코딩/디코딩 코덱.
///
/// - export 방향(`makeDTO`)만 여기서 다룬다. import 방향(DTO → 모델 upsert)은
///   참조 재연결이 필요해 `BackupUpsertEngine`(2-pass)에서 처리한다.
/// - 날짜는 ISO8601, 키는 그대로. `data.json` 직렬화에 공유한다.
enum BackupCodec {
  static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }

  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  // MARK: - 모델 → DTO (export)

  static func makeDTO(_ space: Space) -> SpaceDTO {
    SpaceDTO(
      id: space.id,
      name: space.name,
      icon: space.icon,
      sortOrder: space.sortOrder,
      createdAt: space.createdAt,
      updatedAt: space.updatedAt,
    )
  }

  static func makeDTO(_ area: Area) -> AreaDTO {
    AreaDTO(
      id: area.id,
      name: area.name,
      icon: area.icon,
      sortOrder: area.sortOrder,
      createdAt: area.createdAt,
      updatedAt: area.updatedAt,
      spaceID: area.space?.id,
    )
  }

  static func makeDTO(_ spot: Spot) -> SpotDTO {
    SpotDTO(
      id: spot.id,
      name: spot.name,
      sortOrder: spot.sortOrder,
      createdAt: spot.createdAt,
      updatedAt: spot.updatedAt,
      areaID: spot.area?.id,
    )
  }

  static func makeDTO(_ category: ItemCategory) -> ItemCategoryDTO {
    ItemCategoryDTO(
      id: category.id,
      name: category.name,
      icon: category.icon,
      sortOrder: category.sortOrder,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
    )
  }

  static func makeDTO(_ tag: Tag) -> TagDTO {
    TagDTO(
      id: tag.id,
      name: tag.name,
      createdAt: tag.createdAt,
      updatedAt: tag.updatedAt,
    )
  }

  static func makeDTO(_ item: Item) -> ItemDTO {
    ItemDTO(
      id: item.id,
      name: item.name,
      normalizedName: item.normalizedName,
      quantity: item.quantity,
      memo: item.memo,
      expiresAt: item.expiresAt,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      areaID: item.area?.id,
      spotID: item.spot?.id,
      categoryID: item.category?.id,
      tagIDs: (item.tags ?? []).map(\.id),
    )
  }

  static func makeDTO(_ recipe: Recipe) -> RecipeDTO {
    RecipeDTO(
      id: recipe.id,
      title: recipe.title,
      summary: recipe.summary,
      servings: recipe.servings,
      totalMinutes: recipe.totalMinutes,
      cuisine: recipe.cuisine,
      dishType: recipe.dishType,
      sourceURL: recipe.sourceURL,
      steps: recipe.steps,
      createdAt: recipe.createdAt,
      updatedAt: recipe.updatedAt,
      tagIDs: (recipe.tags ?? []).map(\.id),
    )
  }

  static func makeDTO(_ ingredient: RecipeIngredient) -> RecipeIngredientDTO {
    RecipeIngredientDTO(
      id: ingredient.id,
      name: ingredient.name,
      quantity: ingredient.quantity,
      unit: ingredient.unit,
      note: ingredient.note,
      sortOrder: ingredient.sortOrder,
      isOptional: ingredient.isOptional,
      recipeID: ingredient.recipe?.id,
      itemID: ingredient.item?.id,
    )
  }

  static func makeDTO(_ shoppingItem: ShoppingItem) -> ShoppingItemDTO {
    ShoppingItemDTO(
      id: shoppingItem.id,
      name: shoppingItem.name,
      normalizedName: shoppingItem.normalizedName,
      quantity: shoppingItem.quantity,
      isChecked: shoppingItem.isChecked,
      stockCredited: shoppingItem.stockCredited,
      createdAt: shoppingItem.createdAt,
      sourceIngredientID: shoppingItem.sourceIngredient?.id,
    )
  }
}

/// 백업 디렉터리 패키지의 내부 레이아웃 상수.
/// `.homepinbackup` 패키지 = `data.json`.
enum BackupBundleLayout {
  /// 패키지 확장자(exported UTType `com.sro.homepinappios.backup`).
  static let fileExtension = "homepinbackup"
  /// 메타 + 엔티티 JSON 파일명.
  static let dataFileName = "data.json"
}
