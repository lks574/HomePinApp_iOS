import Foundation

/// 시드 데이터의 표시 텍스트 세트. 시스템 언어(en/ko)로 한 번 골라 `SeedData.populate` 가
/// 그래프를 만들 때 쓴다. 시드는 생성 시점 1회 고정 데이터라 런타임 언어 추종 대상이 아니다
/// (Decision: i18n 다국어화 방침). 따라서 .xcstrings 가 아니라 여기 코드에 en/ko 를 둔다.
///
/// 그래프 구조(항목 수·관계·임박일·매칭)는 언어와 무관하게 동일하고, 사람이 읽는 이름·문장만
/// 분기한다. 단, 레시피 분류(cuisine/dishType)는 저장값(raw)을 한국어로 유지하는 앱 전역 규칙
/// (RecipeClassification)에 맞춰 en/ko 모두 한국어 raw 키를 그대로 넣는다(표시 라벨만 현지화).
struct SeedText {
  /// 현재 시스템 언어로 시드 텍스트 세트를 고른다(한국어면 ko, 그 외 en).
  static var current: SeedText {
    Locale.current.language.languageCode == .korean ? .korean : .english
  }

  // 공간
  let space: String

  // 카테고리
  let categoryFood: String
  let categoryLiving: String
  let categoryDocs: String

  // 태그
  let tagDaily: String
  let tagEmergency: String

  // 장소(Area)
  let areaKitchen: String
  let areaFridge: String
  let areaLiving: String
  let areaBedroom: String
  let areaDressRoom: String
  let areaBathroom: String
  let areaEntrance: String
  let areaStorage: String

  // 수납공간(Spot)
  let spotFreezer: String
  let spotFresh: String
  let spotDoorSide: String
  let spotUpperCabinet: String
  let spotDrawer1: String
  let spotNightstand: String

  // 물건(Item)
  let itemMilk: String
  let itemTofu: String
  let itemEgg: String
  let itemSoySauce: String
  let itemButter: String
  let itemKimchi: String
  let itemJam: String
  let itemSugar: String
  let itemBread: String
  let itemSesameOil: String
  let itemSalt: String
  let itemGreenOnion: String
  let itemGarlic: String
  let itemOliveOil: String
  let itemContainer: String
  let itemPowerStrip: String
  let itemRemote: String
  let itemCharger: String
  let itemPassport: String
  let itemBankbook: String
  let itemEmergencyCash: String
  let itemGlasses: String
  let itemWinterCoat: String

  // 레시피용 추가 재료 이름(보유 물건이 없는 재료)
  let ingRedPepperPowder: String
  let ingCookingOil: String
  let ingSoybeanPaste: String
  let ingZucchini: String
  let ingChicken: String
  let ingOnion: String
  let ingPorkMince: String
  let ingDoubanjiang: String
  let ingSpaghetti: String
  let ingTomatoSauce: String
  let ingRiceCake: String
  let ingGochujang: String
  let ingFishCake: String

  // 레시피
  let recipeBraisedTofu: SeedRecipeText
  let recipeSteamedEgg: SeedRecipeText
  let recipeFrenchToast: SeedRecipeText
  let recipeKimchiFriedRice: SeedRecipeText
  let recipeDoenjangStew: SeedRecipeText
  let recipeButterSoyEggRice: SeedRecipeText
  let recipeOyakodon: SeedRecipeText
  let recipeMapoTofu: SeedRecipeText
  let recipeTomatoPasta: SeedRecipeText
  let recipeTteokbokki: SeedRecipeText
}

/// 레시피 한 건의 표시 텍스트(제목·요약·단계). 분류·시간·재료 링크 구조는 SeedData 가 정한다.
struct SeedRecipeText {
  let title: String
  let summary: String
  let steps: [String]
}
