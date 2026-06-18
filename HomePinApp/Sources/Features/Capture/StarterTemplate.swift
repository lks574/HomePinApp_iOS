import Foundation

/// 스타터 템플릿 — 구역 종류별 자주 두는 품목 묶음을 칩 staging 으로 합류시키는 입력 어댑터.
/// 시드 Area 8종(주방·냉장고·욕실·거실·안방·드레스룸·현관·창고) + 공통을 기준으로 한다.
///
/// 정적 데이터다. `@Model` 이 아니고 SwiftData 에 저장하지 않는다 — 선택 결과는 칩(`ItemBulkAddModel`)
/// 으로만 적재되고, 실제 insert 는 사용자가 "추가" 를 누를 때만 일어난다(자동 저장 없음).
/// en/ko 분기는 시드(`SeedText`)와 같은 방식으로 코드 안에 둔다(런타임 언어 1회 고정, .xcstrings 아님).
/// 릴리스 노출 기능이라 `#if DEBUG` 게이트는 적용하지 않는다.
struct StarterTemplate: Identifiable {
  /// 구역 종류 식별자. Area 이름 매칭에 쓰는 안정 키(언어 무관).
  let kind: Kind
  /// 사람이 읽는 구역 이름(시스템 언어로 분기). 매칭과 표시 모두에 쓴다.
  let displayName: String
  /// 이 구역에 자주 두는 품목들(이름 + 수량 기본값). 카테고리/Spot 힌트는 싣지 않는다.
  let items: [TemplateItem]

  var id: Kind { kind }

  enum Kind: String, CaseIterable {
    case kitchen
    case fridge
    case bathroom
    case living
    case bedroom
    case dressRoom
    case entrance
    case storage
    case common
  }

  /// 템플릿 품목 한 개. 이름과 수량 기본값(대부분 1)만 — 위치/분류는 칩 적재 시 결정한다.
  struct TemplateItem {
    let name: String
    var quantity: Int = 1
  }

  /// 현재 시스템 언어로 고른 전체 템플릿 묶음(한국어면 ko, 그 외 en).
  static var all: [StarterTemplate] {
    Locale.current.language.languageCode == .korean ? korean : english
  }

  /// 구역 종류로 템플릿을 찾는다(없으면 nil).
  static func template(for kind: Kind) -> StarterTemplate? {
    all.first { $0.kind == kind }
  }

  // MARK: - Area 이름 매칭

  /// 새 Area 이름과 가장 잘 맞는 템플릿을 고른다. 정규화 후 displayName 완전 일치 우선,
  /// 없으면 부분 포함(양방향), 그래도 없으면 nil(호출부가 전체 목록 picker 로 폴백).
  static func match(areaName: String) -> StarterTemplate? {
    let key = Item.normalize(areaName)
    guard !key.isEmpty else { return nil }
    let templates = all
    if let exact = templates.first(where: { Item.normalize($0.displayName) == key }) {
      return exact
    }
    return templates.first { template in
      let name = Item.normalize(template.displayName)
      return name.contains(key) || key.contains(name)
    }
  }
}
