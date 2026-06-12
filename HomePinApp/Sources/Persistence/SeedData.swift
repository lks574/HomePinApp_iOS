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
    func d(_ days: Int) -> Date { Date.now.addingTimeInterval(Double(days) * 86_400) }

    let home = Space(name: "우리집")
    context.insert(home)

    // 카테고리
    let food = ItemCategory(name: "식품", icon: "fork.knife")
    let living = ItemCategory(name: "생활용품", icon: "house")
    let docs = ItemCategory(name: "서류", icon: "doc.text")
    [food, living, docs].forEach { context.insert($0) }

    // 태그
    let tagDaily = Tag(name: "자주쓰는")
    let tagEmergency = Tag(name: "비상")
    [tagDaily, tagEmergency].forEach { context.insert($0) }

    // 장소(Area)
    func area(_ name: String, _ icon: String, _ order: Int) -> Area {
      let a = Area(name: name, icon: icon, sortOrder: order, space: home)
      context.insert(a)
      return a
    }
    let kitchen = area("주방", "fork.knife", 0)
    let fridge = area("냉장고", "refrigerator", 1)
    let living2 = area("거실", "sofa", 2)
    let bedroom = area("안방", "bed.double", 3)
    let dress = area("드레스룸", "tshirt", 4)
    _ = area("욕실", "drop", 5)
    _ = area("현관", "door.left.hand.open", 6)
    _ = area("창고", "shippingbox", 7)

    // 수납공간(Spot)
    func spot(_ name: String, _ area: Area, _ order: Int) -> Spot {
      let s = Spot(name: name, sortOrder: order, area: area)
      context.insert(s)
      return s
    }
    let freezer = spot("냉동실", fridge, 0)
    let fresh = spot("신선칸", fridge, 1)
    let doorSide = spot("문쪽", fridge, 2)
    let upper = spot("상부장", kitchen, 0)
    let drawer1 = spot("서랍 1번째", bedroom, 0)
    let nightstand = spot("협탁", bedroom, 1)

    // 물건(Item)
    @discardableResult
    func item(_ name: String, _ area: Area, _ spot: Spot? = nil,
              _ cat: ItemCategory? = nil, expireDays: Int? = nil) -> Item {
      let it = Item(name: name, expiresAt: expireDays.map(d), area: area, spot: spot, category: cat)
      context.insert(it)
      return it
    }
    // 냉장고 (레시피 매칭용 임박 재료)
    let milk = item("우유", fridge, fresh, food, expireDays: 1)
    let tofu = item("두부", fridge, fresh, food, expireDays: 2)
    let egg = item("계란", fridge, fresh, food, expireDays: 3)
    let soy = item("간장", fridge, doorSide, food)
    let butter = item("버터", fridge, doorSide, food)
    let kimchi = item("김치", fridge, fresh, food)
    _ = item("잼", fridge, doorSide, food)
    // 주방
    let sugar = item("설탕", kitchen, upper, food)
    let bread = item("식빵", kitchen, upper, food)
    let sesame = item("참기름", kitchen, upper, food)
    let salt = item("소금", kitchen, upper, food)
    let greenOnion = item("대파", kitchen, nil, food)
    let garlic = item("마늘", kitchen, nil, food)
    let oil = item("올리브유", kitchen, nil, food)
    item("밀폐용기", kitchen, nil, living)
    // 거실
    item("멀티탭", living2, nil, living).tags = [tagDaily]
    item("리모컨", living2, nil, living)
    item("충전기", living2, nil, living)
    // 안방
    item("여권", bedroom, drawer1, docs).tags = [tagEmergency]
    item("통장", bedroom, drawer1, docs)
    item("비상금", bedroom, drawer1, nil).tags = [tagEmergency]
    item("안경", bedroom, nightstand, living)
    // 드레스룸
    item("겨울코트", dress, nil, nil)

    // 레시피
    @discardableResult
    func recipe(_ title: String, cuisine: String?, minutes: Int,
                _ ings: [(String, Item?)]) -> Recipe {
      let r = Recipe(title: title, servings: 2, totalMinutes: minutes, cuisine: cuisine)
      context.insert(r)
      for (idx, (n, linked)) in ings.enumerated() {
        let ri = RecipeIngredient(name: n, sortOrder: idx, recipe: r, item: linked)
        context.insert(ri)
      }
      return r
    }
    recipe("두부조림", cuisine: "한식", minutes: 20, [
      ("두부", tofu), ("간장", soy), ("대파", greenOnion),
      ("마늘", garlic), ("설탕", sugar), ("고춧가루", nil), // 고춧가루 미보유 → 5/6
    ])
    recipe("계란찜", cuisine: "한식", minutes: 10, [
      ("계란", egg), ("대파", greenOnion), ("소금", salt), ("참기름", sesame),
    ])
    recipe("프렌치토스트", cuisine: "양식", minutes: 15, [
      ("우유", milk), ("계란", egg), ("식빵", bread), ("버터", butter), ("설탕", nil),
    ])
    recipe("김치볶음밥", cuisine: "한식", minutes: 15, [
      ("김치", kimchi), ("계란", egg), ("대파", greenOnion), ("식용유", oil),
    ])
  }
}
