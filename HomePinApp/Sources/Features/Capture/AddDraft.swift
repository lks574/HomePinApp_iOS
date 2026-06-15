import Foundation
import SwiftData

/// 확인 드래프트 화면의 항목당 편집 상태. 파서가 뽑은 문자열을 사용자가 확인/수정하는
/// **비영속 UI 상태**(저장 전 draft)다 — CLAUDE.md 가 허용한 "얇은 @Observable 모델"
/// 케이스 ①. 신규 vs 기존 매칭은 `*Match` 의 케이스로 구분해 화면이 시각화한다.
///
/// 위치 매칭 불변식: 세부위치(`spotMatch`)가 정해지면 구역(`areaMatch`)은 그 세부위치의
/// 구역으로 종속된다(`Item` 위치 규칙: spot.area == area). 화면 편집 시 이 일관성을
/// `AddDraft` 안에서 유지한다.
@Observable
final class AddDraft: Identifiable {
  let id = UUID()

  var name: String
  var quantity: Int
  var areaMatch: NameMatch<Area>
  var spotMatch: NameMatch<Spot>?
  var categoryMatch: NameMatch<ItemCategory>?
  var tagMatches: [NameMatch<Tag>]

  init(
    name: String,
    quantity: Int,
    areaMatch: NameMatch<Area>,
    spotMatch: NameMatch<Spot>?,
    categoryMatch: NameMatch<ItemCategory>?,
    tagMatches: [NameMatch<Tag>],
  ) {
    self.name = name
    self.quantity = quantity
    self.areaMatch = areaMatch
    self.spotMatch = spotMatch
    self.categoryMatch = categoryMatch
    self.tagMatches = tagMatches
  }

  var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// 저장 가능 조건: 이름 비어있지 않고, 구역이 지정됨(앱 규칙: 최소 Area 소속).
  /// 구역은 신규 생성이든 기존 매칭이든 이름이 있으면 충족된다.
  var canSave: Bool {
    !trimmedName.isEmpty && areaMatch.hasValue && quantity > 0
  }
}

/// 파서가 뽑은 이름이 기존 도메인 엔티티와 매칭됐는지 표현한다. 화면이 "신규 생성"
/// 과 "기존 연결" 을 시각 구분하는 데 쓰고, 저장 단계에서 신규면 insert·기존이면 연결한다.
enum NameMatch<Model: AnyObject>: Identifiable {
  /// 기존 엔티티에 매칭됨(연결).
  case existing(Model)
  /// 매칭되는 기존 엔티티가 없어 신규 생성 예정(정규화 전 원본 이름).
  case new(String)

  /// `ForEach` 식별용 안정 ID. 신규 케이스도 이름 기반으로 고유해, 한 드래프트에 신규
  /// 태그가 여럿이어도 ID 가 `nil` 로 충돌하지 않는다.
  var id: String {
    switch self {
    case let .existing(model): "existing-\(ObjectIdentifier(model).hashValue)"
    case let .new(name): "new-\(name)"
    }
  }

  var isNew: Bool {
    if case .new = self { return true }
    return false
  }

  /// 매칭/생성할 이름이 실제로 있는가(신규는 공백이 아닐 때만 유효).
  var hasValue: Bool {
    switch self {
    case .existing: true
    case let .new(name): !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }
}
