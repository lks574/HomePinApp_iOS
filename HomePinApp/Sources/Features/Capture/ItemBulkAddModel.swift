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
    /// 기존 재고 Item 과 normalizedName 이 충돌할 때, 새 Item 을 만들지 않고 그 기존
    /// Item 수량에 합칠지의 사용자 의도. 기본 false(= 기존대로 새 insert + 경고만).
    /// 기존 재고와 충돌하는 칩에서만 의미가 있다(staging 자기중복은 합치기 대상 아님).
    var mergeIntoExisting = false
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

  /// "기존 재고에 합치기" 의도를 토글한다. 기존 재고와 충돌하는 칩에서만 호출부가 노출하므로
  /// 여기서 충돌 여부를 재검사하지 않는다(UI 가 게이트). 비충돌 칩에 켜져도 `bulkInsert` 의
  /// 룩업이 대표 Item 을 못 찾으면 자연히 새 insert 로 떨어진다(안전 폴백).
  func toggleMerge(_ id: Chip.ID) {
    guard let index = chips.firstIndex(where: { $0.id == id }) else { return }
    chips[index].mergeIntoExisting.toggle()
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

  /// 칩이 **기존 재고 Item** 과만 충돌하는지(staging 자기중복은 제외). 합치기 토글은
  /// 기존 재고에 가산하는 의도라, staging 칩끼리 겹침에는 의미가 없어 이 경로로만 노출한다.
  func conflictsWithExistingStock(_ chip: Chip, existingNormalizedNames: Set<String>) -> Bool {
    let key = Item.normalize(chip.name)
    guard !key.isEmpty else { return false }
    return existingNormalizedNames.contains(key)
  }

  // MARK: - 다건 쓰기

  /// 칩들을 재고로 반영한다. 칩이 합치기 의도(`mergeIntoExisting`)이고 같은 normalizedName
  /// 기존 Item 이 있으면 새 Item 을 만들지 않고 그 기존 Item 의 수량에 가산한다. 그 외에는
  /// 기존대로 새 `Item` 을 insert 한다. 각 insert 에 normalizedName 동기화와 위치 불변식
  /// (`spot?.area ?? area`, bulk 는 spot 미수집이라 area 만)을 적용한다. 빈 이름 칩은 건너뛴다.
  /// 충돌하지 않거나 합치기 미선택이면 전부 새 insert 라 회귀가 없다.
  ///
  /// - 룩업 책임은 모델에 둔다. `existingItems` 를 normalizedName 으로 그루핑하고,
  ///   같은 키가 여럿이면 **최근 수정(`updatedAt` 최신)** 대표 하나에만 가산한다(결정적).
  /// - area/spot 은 가산 대상 기존 Item 의 위치를 유지한다(칩 area 로 덮지 않음). 가산 시
  ///   `quantity += max(1, chip.quantity)` 와 `updatedAt = .now` 만 갱신한다.
  /// - 반환: 새로 만든 Item 목록과 합쳐 가산한 기존 Item 목록(호출부 결과 요약용).
  @discardableResult
  func bulkInsert(
    into modelContext: ModelContext,
    existingItems: [Item]
  ) -> (inserted: [Item], merged: [Item]) {
    let representatives = Self.representativesByNormalizedName(existingItems)
    var inserted: [Item] = []
    var merged: [Item] = []
    for chip in chips {
      let trimmed = chip.name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }
      let key = Item.normalize(trimmed)
      let amount = max(1, chip.quantity)
      if chip.mergeIntoExisting, let existing = representatives[key] {
        // 기존 재고에 가산 — 위치(area/spot)는 기존 Item 그대로 유지한다.
        // 같은 normalizedName 칩이 여러 개 모두 합치기로 켜지면 이 대표 Item 에 순차
        // 누적 가산된다(스냅샷 대표는 고정 → 수량 합산은 정확, 데이터 손상 아님). 결정
        // 문서의 "staging 자기중복은 합치기 대상 아님" 은 자기중복 칩에 토글을 노출하지
        // 않는다는 UI 게이트를 뜻하며, 사용자가 의도적으로 켠 동일키 가산까지 막지는 않는다.
        existing.quantity += amount
        existing.updatedAt = .now
        merged.append(existing)
        continue
      }
      let item = Item(
        name: trimmed,
        normalizedName: key,
        quantity: amount,
        area: chip.parsedArea ?? sessionArea,
        spot: nil
      )
      modelContext.insert(item)
      inserted.append(item)
    }
    return (inserted, merged)
  }

  /// 기존 Item 들을 normalizedName 키로 묶어, 키마다 **최근 수정(`updatedAt` 최신)** 대표를
  /// 고른다. 같은 키가 여럿일 때 가산 대상이 결정적이고 중복 가산이 없게 한다(빈 키 제외).
  private static func representativesByNormalizedName(_ items: [Item]) -> [String: Item] {
    var result: [String: Item] = [:]
    for item in items {
      let key = item.normalizedName
      guard !key.isEmpty else { continue }
      if let current = result[key], current.updatedAt >= item.updatedAt { continue }
      result[key] = item
    }
    return result
  }
}
