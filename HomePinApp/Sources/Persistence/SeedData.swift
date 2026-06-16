import Foundation
import SwiftData

/// 개발/프리뷰용 시드 데이터. 시안 샘플을 기반으로 위치·물건·레시피 그래프를 채운다.
/// 실데이터가 아니므로 DEBUG 또는 in-memory 프리뷰에서만 쓴다.
enum SeedData {
  /// 스토어가 비어 있으면(공간 0개) 시드를 주입한다. (DEBUG 전용 호출 권장)
  static func populateIfEmpty(_ context: ModelContext) {
    let count = (try? context.fetchCount(FetchDescriptor<Space>())) ?? 0
    guard count == 0 else { return }
    populate(context)
  }

  /// in-memory 프리뷰 컨테이너(시드 포함).
  @MainActor
  static func previewContainer() -> ModelContainer {
    let schema = Schema(AppModelContainer.models)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: schema, configurations: config)
    populate(container.mainContext)
    return container
  }

  static func populate(_ context: ModelContext) {
    let t = SeedText.current
    func d(_ days: Int) -> Date { Date.now.addingTimeInterval(Double(days) * 86_400) }

    let home = Space(name: t.space)
    context.insert(home)

    // 카테고리
    let food = ItemCategory(name: t.categoryFood, icon: "fork.knife")
    let living = ItemCategory(name: t.categoryLiving, icon: "house")
    let docs = ItemCategory(name: t.categoryDocs, icon: "doc.text")
    [food, living, docs].forEach { context.insert($0) }

    // 태그
    let tagDaily = Tag(name: t.tagDaily)
    let tagEmergency = Tag(name: t.tagEmergency)
    [tagDaily, tagEmergency].forEach { context.insert($0) }

    // 장소(Area)
    func area(_ name: String, _ icon: String, _ order: Int) -> Area {
      let a = Area(name: name, icon: icon, sortOrder: order, space: home)
      context.insert(a)
      return a
    }
    let kitchen = area(t.areaKitchen, "fork.knife", 0)
    let fridge = area(t.areaFridge, "refrigerator", 1)
    let living2 = area(t.areaLiving, "sofa", 2)
    let bedroom = area(t.areaBedroom, "bed.double", 3)
    let dress = area(t.areaDressRoom, "tshirt", 4)
    _ = area(t.areaBathroom, "drop", 5)
    _ = area(t.areaEntrance, "door.left.hand.open", 6)
    _ = area(t.areaStorage, "shippingbox", 7)

    // 수납공간(Spot)
    func spot(_ name: String, _ area: Area, _ order: Int) -> Spot {
      let s = Spot(name: name, sortOrder: order, area: area)
      context.insert(s)
      return s
    }
    _ = spot(t.spotFreezer, fridge, 0)
    let fresh = spot(t.spotFresh, fridge, 1)
    let doorSide = spot(t.spotDoorSide, fridge, 2)
    let upper = spot(t.spotUpperCabinet, kitchen, 0)
    let drawer1 = spot(t.spotDrawer1, bedroom, 0)
    let nightstand = spot(t.spotNightstand, bedroom, 1)

    // 물건(Item)
    @discardableResult
    func item(_ name: String, _ area: Area, _ spot: Spot? = nil,
              _ cat: ItemCategory? = nil, expireDays: Int? = nil) -> Item {
      let it = Item(name: name, expiresAt: expireDays.map(d), area: area, spot: spot, category: cat)
      context.insert(it)
      return it
    }
    // 냉장고 (레시피 매칭용 임박 재료)
    let milk = item(t.itemMilk, fridge, fresh, food, expireDays: 1)
    let tofu = item(t.itemTofu, fridge, fresh, food, expireDays: 2)
    let egg = item(t.itemEgg, fridge, fresh, food, expireDays: 3)
    let soy = item(t.itemSoySauce, fridge, doorSide, food)
    let butter = item(t.itemButter, fridge, doorSide, food)
    let kimchi = item(t.itemKimchi, fridge, fresh, food)
    _ = item(t.itemJam, fridge, doorSide, food)
    // 주방
    let sugar = item(t.itemSugar, kitchen, upper, food)
    let bread = item(t.itemBread, kitchen, upper, food)
    let sesame = item(t.itemSesameOil, kitchen, upper, food)
    let salt = item(t.itemSalt, kitchen, upper, food)
    let greenOnion = item(t.itemGreenOnion, kitchen, nil, food)
    let garlic = item(t.itemGarlic, kitchen, nil, food)
    let oil = item(t.itemOliveOil, kitchen, nil, food)
    item(t.itemContainer, kitchen, nil, living)
    // 거실
    item(t.itemPowerStrip, living2, nil, living).tags = [tagDaily]
    item(t.itemRemote, living2, nil, living)
    item(t.itemCharger, living2, nil, living)
    // 안방
    item(t.itemPassport, bedroom, drawer1, docs).tags = [tagEmergency]
    item(t.itemBankbook, bedroom, drawer1, docs)
    item(t.itemEmergencyCash, bedroom, drawer1, nil).tags = [tagEmergency]
    item(t.itemGlasses, bedroom, nightstand, living)
    // 드레스룸
    item(t.itemWinterCoat, dress, nil, nil)

    // 레시피. cuisine/dishType 은 저장값(raw)을 한국어로 유지하는 앱 규칙대로 항상 raw 키.
    @discardableResult
    func recipe(_ text: SeedRecipeText, cuisine: String?, dishType: String?, minutes: Int,
                servings: Int = 2, stepMinutes: [Int: Int] = [:],
                _ ings: [(String, Item?)]) -> Recipe {
      let steps = text.steps.enumerated().map { idx, line in
        RecipeStep(text: line, minutes: stepMinutes[idx])
      }
      let r = Recipe(
        title: text.title,
        summary: text.summary,
        servings: servings,
        totalMinutes: minutes,
        cuisine: cuisine,
        dishType: dishType,
        steps: steps,
      )
      context.insert(r)
      for (idx, (n, linked)) in ings.enumerated() {
        let ri = RecipeIngredient(name: n, sortOrder: idx, recipe: r, item: linked)
        context.insert(ri)
      }
      return r
    }
    recipe(t.recipeBraisedTofu, cuisine: "한식", dishType: "조림", minutes: 20,
      stepMinutes: [1: 6, 3: 8], [
        (t.itemTofu, tofu), (t.itemSoySauce, soy), (t.itemGreenOnion, greenOnion),
        (t.itemGarlic, garlic), (t.itemSugar, sugar), (t.ingRedPepperPowder, nil), // 고춧가루 미보유 → 5/6
      ])
    recipe(t.recipeSteamedEgg, cuisine: "한식", dishType: "반찬", minutes: 10,
      stepMinutes: [1: 7], [
        (t.itemEgg, egg), (t.itemGreenOnion, greenOnion), (t.itemSalt, salt), (t.itemSesameOil, sesame),
      ])
    recipe(t.recipeFrenchToast, cuisine: "양식", dishType: "구이", minutes: 15,
      stepMinutes: [2: 8], [
        (t.itemMilk, milk), (t.itemEgg, egg), (t.itemBread, bread), (t.itemButter, butter), (t.itemSugar, nil),
      ])
    recipe(t.recipeKimchiFriedRice, cuisine: "한식", dishType: "밥·면", minutes: 15,
      stepMinutes: [0: 4, 1: 5], [
        (t.itemKimchi, kimchi), (t.itemEgg, egg), (t.itemGreenOnion, greenOnion), (t.ingCookingOil, oil),
      ])
    // 된장찌개 — 두부(임박)·대파·마늘 보유, 된장·애호박 미보유 → 임박 사용 + 2개 부족
    recipe(t.recipeDoenjangStew, cuisine: "한식", dishType: "국·찌개", minutes: 25,
      stepMinutes: [0: 5, 2: 10, 3: 3], [
        (t.itemTofu, tofu), (t.itemGreenOnion, greenOnion), (t.itemGarlic, garlic),
        (t.ingSoybeanPaste, nil), (t.ingZucchini, nil),
      ])
    // 버터간장계란밥 — 계란(임박)·간장·버터·참기름 전부 보유 → 완전히 만들 수 있음 + 임박 사용
    recipe(t.recipeButterSoyEggRice, cuisine: "한식", dishType: "밥·면", minutes: 8, servings: 1,
      stepMinutes: [0: 3], [
        (t.itemEgg, egg), (t.itemSoySauce, soy), (t.itemButter, butter), (t.itemSesameOil, sesame),
      ])
    // 오야코동 — 계란(임박)·간장·설탕·대파 보유, 닭고기·양파 미보유 → 임박 사용 + 2개 부족
    recipe(t.recipeOyakodon, cuisine: "일식", dishType: "밥·면", minutes: 20,
      stepMinutes: [1: 8, 2: 3], [
        (t.itemEgg, egg), (t.itemSoySauce, soy), (t.itemSugar, sugar), (t.itemGreenOnion, greenOnion),
        (t.ingChicken, nil), (t.ingOnion, nil),
      ])
    // 마파두부 — 두부(임박)·대파·마늘·간장 보유, 다진 돼지고기·두반장 미보유 → 임박 사용 + 2개 부족
    recipe(t.recipeMapoTofu, cuisine: "중식", dishType: "볶음", minutes: 20,
      stepMinutes: [1: 5, 2: 8, 3: 2], [
        (t.itemTofu, tofu), (t.itemGreenOnion, greenOnion), (t.itemGarlic, garlic), (t.itemSoySauce, soy),
        (t.ingPorkMince, nil), (t.ingDoubanjiang, nil),
      ])
    // 토마토파스타 — 올리브유·마늘·소금 보유, 스파게티면·토마토소스 미보유 → 2개 부족
    recipe(t.recipeTomatoPasta, cuisine: "양식", dishType: "밥·면", minutes: 25,
      stepMinutes: [0: 9, 1: 2, 2: 5], [
        (t.itemOliveOil, oil), (t.itemGarlic, garlic), (t.itemSalt, salt),
        (t.ingSpaghetti, nil), (t.ingTomatoSauce, nil),
      ])
    // 떡볶이 — 대파·설탕·간장 보유, 떡·고추장·어묵 미보유 → 3개 부족(만들기 어려움)
    recipe(t.recipeTteokbokki, cuisine: "분식", dishType: "볶음", minutes: 20,
      stepMinutes: [1: 8, 2: 5], [
        (t.itemGreenOnion, greenOnion), (t.itemSugar, sugar), (t.itemSoySauce, soy),
        (t.ingRiceCake, nil), (t.ingGochujang, nil), (t.ingFishCake, nil),
      ])
  }
}
