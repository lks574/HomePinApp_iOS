import Foundation

// 스타터 템플릿 en/ko 세트. 구역 구성(종류·품목 수)은 동일하고 사람이 읽는 이름만 분기한다.
// displayName 은 시드 Area 이름(SeedText)과 같은 표기를 써서 새 Area 이름 매칭이 자연스럽게 맞도록 한다.

extension StarterTemplate {
  static let korean: [StarterTemplate] = [
    StarterTemplate(kind: .kitchen, displayName: "주방", items: [
      TemplateItem(name: "소금"),
      TemplateItem(name: "설탕"),
      TemplateItem(name: "식용유"),
      TemplateItem(name: "간장"),
      TemplateItem(name: "키친타월"),
      TemplateItem(name: "랩"),
      TemplateItem(name: "지퍼백"),
    ]),
    StarterTemplate(kind: .fridge, displayName: "냉장고", items: [
      TemplateItem(name: "우유"),
      TemplateItem(name: "계란"),
      TemplateItem(name: "두부"),
      TemplateItem(name: "버터"),
      TemplateItem(name: "김치"),
      TemplateItem(name: "대파"),
      TemplateItem(name: "마늘"),
    ]),
    StarterTemplate(kind: .bathroom, displayName: "욕실", items: [
      TemplateItem(name: "샴푸"),
      TemplateItem(name: "린스"),
      TemplateItem(name: "바디워시"),
      TemplateItem(name: "치약"),
      TemplateItem(name: "칫솔"),
      TemplateItem(name: "수건"),
      TemplateItem(name: "휴지"),
    ]),
    StarterTemplate(kind: .living, displayName: "거실", items: [
      TemplateItem(name: "리모컨"),
      TemplateItem(name: "멀티탭"),
      TemplateItem(name: "건전지"),
      TemplateItem(name: "충전기"),
      TemplateItem(name: "물티슈"),
    ]),
    StarterTemplate(kind: .bedroom, displayName: "안방", items: [
      TemplateItem(name: "안경"),
      TemplateItem(name: "손톱깎이"),
      TemplateItem(name: "충전기"),
      TemplateItem(name: "비상약"),
      TemplateItem(name: "여분 이불"),
    ]),
    StarterTemplate(kind: .dressRoom, displayName: "드레스룸", items: [
      TemplateItem(name: "겨울코트"),
      TemplateItem(name: "넥타이"),
      TemplateItem(name: "벨트"),
      TemplateItem(name: "옷걸이"),
      TemplateItem(name: "방습제"),
    ]),
    StarterTemplate(kind: .entrance, displayName: "현관", items: [
      TemplateItem(name: "우산"),
      TemplateItem(name: "여벌 마스크"),
      TemplateItem(name: "구두약"),
      TemplateItem(name: "택배칼"),
      TemplateItem(name: "여분 열쇠"),
    ]),
    StarterTemplate(kind: .storage, displayName: "창고", items: [
      TemplateItem(name: "휴지", quantity: 1),
      TemplateItem(name: "물티슈", quantity: 1),
      TemplateItem(name: "생수", quantity: 1),
      TemplateItem(name: "공구함"),
      TemplateItem(name: "테이프"),
      TemplateItem(name: "전구"),
    ]),
    StarterTemplate(kind: .common, displayName: "공통", items: [
      TemplateItem(name: "건전지"),
      TemplateItem(name: "여분 충전기"),
      TemplateItem(name: "반창고"),
      TemplateItem(name: "비상약"),
      TemplateItem(name: "손전등"),
    ]),
  ]

  static let english: [StarterTemplate] = [
    StarterTemplate(kind: .kitchen, displayName: "Kitchen", items: [
      TemplateItem(name: "Salt"),
      TemplateItem(name: "Sugar"),
      TemplateItem(name: "Cooking oil"),
      TemplateItem(name: "Soy sauce"),
      TemplateItem(name: "Paper towels"),
      TemplateItem(name: "Plastic wrap"),
      TemplateItem(name: "Zipper bags"),
    ]),
    StarterTemplate(kind: .fridge, displayName: "Fridge", items: [
      TemplateItem(name: "Milk"),
      TemplateItem(name: "Eggs"),
      TemplateItem(name: "Tofu"),
      TemplateItem(name: "Butter"),
      TemplateItem(name: "Kimchi"),
      TemplateItem(name: "Green onion"),
      TemplateItem(name: "Garlic"),
    ]),
    StarterTemplate(kind: .bathroom, displayName: "Bathroom", items: [
      TemplateItem(name: "Shampoo"),
      TemplateItem(name: "Conditioner"),
      TemplateItem(name: "Body wash"),
      TemplateItem(name: "Toothpaste"),
      TemplateItem(name: "Toothbrush"),
      TemplateItem(name: "Towels"),
      TemplateItem(name: "Toilet paper"),
    ]),
    StarterTemplate(kind: .living, displayName: "Living Room", items: [
      TemplateItem(name: "Remote"),
      TemplateItem(name: "Power strip"),
      TemplateItem(name: "Batteries"),
      TemplateItem(name: "Charger"),
      TemplateItem(name: "Wet wipes"),
    ]),
    StarterTemplate(kind: .bedroom, displayName: "Bedroom", items: [
      TemplateItem(name: "Glasses"),
      TemplateItem(name: "Nail clippers"),
      TemplateItem(name: "Charger"),
      TemplateItem(name: "First-aid meds"),
      TemplateItem(name: "Spare blanket"),
    ]),
    StarterTemplate(kind: .dressRoom, displayName: "Dressing Room", items: [
      TemplateItem(name: "Winter coat"),
      TemplateItem(name: "Necktie"),
      TemplateItem(name: "Belt"),
      TemplateItem(name: "Hangers"),
      TemplateItem(name: "Dehumidifier"),
    ]),
    StarterTemplate(kind: .entrance, displayName: "Entrance", items: [
      TemplateItem(name: "Umbrella"),
      TemplateItem(name: "Spare masks"),
      TemplateItem(name: "Shoe polish"),
      TemplateItem(name: "Box cutter"),
      TemplateItem(name: "Spare keys"),
    ]),
    StarterTemplate(kind: .storage, displayName: "Storage", items: [
      TemplateItem(name: "Toilet paper", quantity: 1),
      TemplateItem(name: "Wet wipes", quantity: 1),
      TemplateItem(name: "Bottled water", quantity: 1),
      TemplateItem(name: "Toolbox"),
      TemplateItem(name: "Tape"),
      TemplateItem(name: "Light bulbs"),
    ]),
    StarterTemplate(kind: .common, displayName: "Common", items: [
      TemplateItem(name: "Batteries"),
      TemplateItem(name: "Spare charger"),
      TemplateItem(name: "Band-aids"),
      TemplateItem(name: "First-aid meds"),
      TemplateItem(name: "Flashlight"),
    ]),
  ]
}
