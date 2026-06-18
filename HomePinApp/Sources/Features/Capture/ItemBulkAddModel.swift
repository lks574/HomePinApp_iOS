import Foundation
import SwiftData
import SwiftUI

/// 연속 입력(여러 개 추가) 모드의 화면 로컬 모델.
/// 저장 전 칩 staging(비영속 UI 상태)과 다건 쓰기 불변식(각 Item insert 시 name→
/// normalizedName 동기화 + `spot?.area ?? area` 위치 일관성)을 소유한다. 단건
/// `ItemEditorModel` 과 별개로 두어 단건 상태를 다건으로 오염시키지 않는다(상태 소유 분리).
///
/// 자동 저장하지 않는다 — 분절(쉼표·줄바꿈·음성 무음 종료)은 칩 생성까지만이고,
/// 실제 insert 는 사용자가 명시적으로 "추가" 를 누르는 `bulkInsert` 에서만 일어난다.
@MainActor
@Observable
final class ItemBulkAddModel {
  /// staging 칩 한 개. 저장 전 후보라 `@Model` 이 아닌 값 타입으로 보관한다.
  struct Chip: Identifiable {
    let id = UUID()
    var name: String
    var quantity: Int
    /// 칩 텍스트에서 파서가 인식한 구역(있으면 세션 Area 보다 우선한다).
    var parsedArea: Area?
  }

  /// 모든 칩에 기본 적용할 세션 구역(선택 안 하면 nil = 위치 미지정으로 저장).
  var sessionArea: Area?
  private(set) var chips: [Chip] = []

  // MARK: - 칩 staging

  /// 분절 텍스트를 파싱해 칩들을 누적한다(자동 저장 아님). 빈 결과는 무시한다.
  func appendChips(from raw: String, areas: [Area], spots: [Spot]) {
    let drafts = ItemQuickAddParser.parse(multiline: raw, areas: areas, spots: spots)
    for draft in drafts {
      chips.append(Chip(name: draft.name, quantity: max(1, draft.quantity), parsedArea: draft.area))
    }
  }

  /// 스타터 템플릿 품목들을 칩으로 누적한다(자동 저장 아님). 템플릿은 위치를 싣지 않으므로
  /// `parsedArea` 는 nil 로 두고 호출부가 세션 Area 로 적용하게 한다. 빈 이름은 건너뛴다.
  func appendChips(from template: StarterTemplate) {
    for item in template.items {
      let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }
      chips.append(Chip(name: trimmed, quantity: max(1, item.quantity), parsedArea: nil))
    }
  }

  func updateName(_ name: String, for id: Chip.ID) {
    guard let index = chips.firstIndex(where: { $0.id == id }) else { return }
    chips[index].name = name
  }

  func increment(_ id: Chip.ID) {
    guard let index = chips.firstIndex(where: { $0.id == id }) else { return }
    chips[index].quantity += 1
  }

  func decrement(_ id: Chip.ID) {
    guard let index = chips.firstIndex(where: { $0.id == id }) else { return }
    chips[index].quantity = max(1, chips[index].quantity - 1)
  }

  func remove(_ id: Chip.ID) {
    chips.removeAll { $0.id == id }
  }

  /// insert 가능한(이름이 빈 칸이 아닌) 칩이 하나라도 있는지. "추가" 버튼 활성화와
  /// `bulkInsert` no-op 가드가 같은 기준을 쓰도록 단일 소스로 둔다.
  var hasInsertableChips: Bool {
    chips.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  // MARK: - 중복 검사 (차단 없는 경고용)

  /// 칩이 staging 안 다른 칩 또는 기존 재고와 같은 정규화 이름과 충돌하는지.
  /// 차단하지 않고 인라인 경고 배지로만 노출한다(단건 합치기 다이얼로그를 연쇄하지 않음).
  func isDuplicate(_ chip: Chip, existingNormalizedNames: Set<String>) -> Bool {
    let key = Item.normalize(chip.name)
    guard !key.isEmpty else { return false }
    if existingNormalizedNames.contains(key) { return true }
    let stagingCount = chips.filter { Item.normalize($0.name) == key }.count
    return stagingCount > 1
  }

  // MARK: - 다건 쓰기

  /// 모든 칩을 새 `Item` 으로 insert 한다. 각 insert 에 normalizedName 동기화와
  /// `spot?.area ?? area` 위치 불변식을 적용한다(bulk 는 spot 을 수집하지 않으므로 area 만).
  /// 빈 이름 칩은 건너뛴다. 중복은 차단하지 않는다(경고만).
  @discardableResult
  func bulkInsert(into modelContext: ModelContext) -> [Item] {
    var inserted: [Item] = []
    for chip in chips {
      let trimmed = chip.name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }
      let area = chip.parsedArea ?? sessionArea
      let item = Item(
        name: trimmed,
        normalizedName: Item.normalize(trimmed),
        quantity: max(1, chip.quantity),
        area: area,
        spot: nil
      )
      modelContext.insert(item)
      inserted.append(item)
    }
    return inserted
  }
}
