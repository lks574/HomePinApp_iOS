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
    _ = spot("냉동실", fridge, 0)
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
    func recipe(_ title: String, cuisine: String?, dishType: String?, minutes: Int,
                servings: Int = 2, summary: String? = nil,
                steps: [RecipeStep] = [],
                _ ings: [(String, Item?)]) -> Recipe {
      let r = Recipe(
        title: title,
        summary: summary,
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
    recipe("두부조림", cuisine: "한식", dishType: "조림", minutes: 20,
      summary: "간장 양념에 졸인 든든한 밑반찬.",
      steps: [
        RecipeStep(text: "두부를 1cm 두께로 썰어 키친타월로 물기를 뺀다."),
        RecipeStep(text: "팬에 기름을 두르고 두부를 노릇하게 부친다.", minutes: 6),
        RecipeStep(text: "간장·설탕·다진 마늘·물을 섞어 양념장을 만든다."),
        RecipeStep(text: "두부에 양념장을 붓고 대파를 올려 졸인다.", minutes: 8),
      ], [
        ("두부", tofu), ("간장", soy), ("대파", greenOnion),
        ("마늘", garlic), ("설탕", sugar), ("고춧가루", nil), // 고춧가루 미보유 → 5/6
      ])
    recipe("계란찜", cuisine: "한식", dishType: "반찬", minutes: 10,
      summary: "뚝배기에 보들보들하게 쪄낸 계란.",
      steps: [
        RecipeStep(text: "계란을 풀고 물·소금을 넣어 잘 섞는다."),
        RecipeStep(text: "뚝배기에 부어 약불로 저으며 익힌다.", minutes: 7),
        RecipeStep(text: "대파와 참기름을 올려 마무리한다."),
      ], [
        ("계란", egg), ("대파", greenOnion), ("소금", salt), ("참기름", sesame),
      ])
    recipe("프렌치토스트", cuisine: "양식", dishType: "구이", minutes: 15,
      summary: "우유와 계란물에 적셔 구운 달콤한 아침 식사.",
      steps: [
        RecipeStep(text: "우유·계란·설탕을 섞어 계란물을 만든다."),
        RecipeStep(text: "식빵을 계란물에 충분히 적신다."),
        RecipeStep(text: "버터를 두른 팬에 양면을 노릇하게 굽는다.", minutes: 8),
      ], [
        ("우유", milk), ("계란", egg), ("식빵", bread), ("버터", butter), ("설탕", nil),
      ])
    recipe("김치볶음밥", cuisine: "한식", dishType: "밥·면", minutes: 15,
      summary: "잘 익은 김치로 볶아낸 한 그릇 식사.",
      steps: [
        RecipeStep(text: "김치를 잘게 썰어 기름에 볶는다.", minutes: 4),
        RecipeStep(text: "밥을 넣고 함께 볶아 간을 맞춘다.", minutes: 5),
        RecipeStep(text: "대파를 넣고 계란프라이를 올린다."),
      ], [
        ("김치", kimchi), ("계란", egg), ("대파", greenOnion), ("식용유", oil),
      ])
    // 된장찌개 — 두부(임박)·대파·마늘 보유, 된장·애호박 미보유 → 임박 사용 + 2개 부족
    recipe("된장찌개", cuisine: "한식", dishType: "국·찌개", minutes: 25,
      summary: "구수한 된장으로 끓인 기본 찌개.",
      steps: [
        RecipeStep(text: "냄비에 물을 붓고 된장을 풀어 끓인다.", minutes: 5),
        RecipeStep(text: "애호박과 두부를 먹기 좋게 썰어 넣는다."),
        RecipeStep(text: "다진 마늘을 넣고 중불에서 끓인다.", minutes: 10),
        RecipeStep(text: "대파를 넣고 한소끔 더 끓여 마무리한다.", minutes: 3),
      ], [
        ("두부", tofu), ("대파", greenOnion), ("마늘", garlic),
        ("된장", nil), ("애호박", nil),
      ])
    // 버터간장계란밥 — 계란(임박)·간장·버터·참기름 전부 보유 → 완전히 만들 수 있음 + 임박 사용
    recipe("버터간장계란밥", cuisine: "한식", dishType: "밥·면", minutes: 8, servings: 1,
      summary: "재료만 있으면 5분이면 완성되는 든든한 한 끼.",
      steps: [
        RecipeStep(text: "팬에 버터를 녹이고 계란프라이를 만든다.", minutes: 3),
        RecipeStep(text: "따뜻한 밥에 버터·간장·참기름을 넣고 비빈다."),
        RecipeStep(text: "계란프라이를 올려 함께 비벼 먹는다."),
      ], [
        ("계란", egg), ("간장", soy), ("버터", butter), ("참기름", sesame),
      ])
    // 오야코동 — 계란(임박)·간장·설탕·대파 보유, 닭고기·양파 미보유 → 임박 사용 + 2개 부족
    recipe("오야코동", cuisine: "일식", dishType: "밥·면", minutes: 20,
      summary: "닭고기와 계란을 간장 국물에 졸여 올린 일본식 덮밥.",
      steps: [
        RecipeStep(text: "간장·설탕·물을 섞어 양념 국물을 만든다."),
        RecipeStep(text: "양파와 닭고기를 넣고 국물에 졸인다.", minutes: 8),
        RecipeStep(text: "풀어둔 계란을 둘러 부어 반숙으로 익힌다.", minutes: 3),
        RecipeStep(text: "밥 위에 올리고 대파를 뿌린다."),
      ], [
        ("계란", egg), ("간장", soy), ("설탕", sugar), ("대파", greenOnion),
        ("닭고기", nil), ("양파", nil),
      ])
    // 마파두부 — 두부(임박)·대파·마늘·간장 보유, 다진 돼지고기·두반장 미보유 → 임박 사용 + 2개 부족
    recipe("마파두부", cuisine: "중식", dishType: "볶음", minutes: 20,
      summary: "두반장으로 매콤하게 볶아낸 사천식 두부 요리.",
      steps: [
        RecipeStep(text: "두부를 깍둑썰기 하고 다진 마늘을 준비한다."),
        RecipeStep(text: "팬에 다진 돼지고기를 볶다가 두반장을 넣는다.", minutes: 5),
        RecipeStep(text: "간장·물을 넣고 두부를 넣어 졸인다.", minutes: 8),
        RecipeStep(text: "대파를 넣고 전분물로 농도를 맞춘다.", minutes: 2),
      ], [
        ("두부", tofu), ("대파", greenOnion), ("마늘", garlic), ("간장", soy),
        ("다진 돼지고기", nil), ("두반장", nil),
      ])
    // 토마토파스타 — 올리브유·마늘·소금 보유, 스파게티면·토마토소스 미보유 → 2개 부족
    recipe("토마토파스타", cuisine: "양식", dishType: "밥·면", minutes: 25,
      summary: "토마토소스에 버무린 기본 스파게티.",
      steps: [
        RecipeStep(text: "끓는 소금물에 스파게티면을 삶는다.", minutes: 9),
        RecipeStep(text: "올리브유에 다진 마늘을 볶아 향을 낸다.", minutes: 2),
        RecipeStep(text: "토마토소스를 넣고 끓인다.", minutes: 5),
        RecipeStep(text: "삶은 면을 넣고 버무려 소금으로 간한다."),
      ], [
        ("올리브유", oil), ("마늘", garlic), ("소금", salt),
        ("스파게티면", nil), ("토마토소스", nil),
      ])
    // 떡볶이 — 대파·설탕·간장 보유, 떡·고추장·어묵 미보유 → 3개 부족(만들기 어려움)
    recipe("떡볶이", cuisine: "분식", dishType: "볶음", minutes: 20,
      summary: "고추장 양념에 떡과 어묵을 졸인 매콤한 분식.",
      steps: [
        RecipeStep(text: "물에 고추장·설탕·간장을 풀어 양념을 만든다."),
        RecipeStep(text: "떡과 어묵을 넣고 끓인다.", minutes: 8),
        RecipeStep(text: "대파를 넣고 양념이 졸아들 때까지 끓인다.", minutes: 5),
      ], [
        ("대파", greenOnion), ("설탕", sugar), ("간장", soy),
        ("떡", nil), ("고추장", nil), ("어묵", nil),
      ])
  }
}
