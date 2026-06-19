import Foundation
import SwiftData
import SwiftUI

/// 물건 추가/편집 에디터의 화면 로컬 모델.
/// 저장 전 draft 와 다단계 쓰기 불변식(create/edit 분기·normalizedName 동기화·
/// spot→area 일관성)을 소유한다. SwiftData 직결로 충분하지 않은,
/// CLAUDE.md 가 허용한 "얇은 @Observable 모델" 케이스.
@Observable
final class ItemEditorModel {
  enum Mode {
    case create(initialName: String = "", quantity: Int = 1, area: Area? = nil, spot: Spot? = nil)
    case edit(Item)
  }

  let mode: Mode

  var name: String
  var quantity: Int
  var selectedArea: Area?
  var selectedSpot: Spot?
  var selectedCategory: ItemCategory?
  var selectedTags: [Tag]
  var hasExpiration: Bool
  var expiresAt: Date
  var memo: String

  init(mode: Mode) {
    self.mode = mode
    switch mode {
    case let .create(initialName, quantity, area, spot):
      name = initialName
      self.quantity = max(1, quantity)
      selectedArea = spot?.area ?? area
      selectedSpot = spot
      selectedCategory = nil
      selectedTags = []
      hasExpiration = false
      expiresAt = .now
      memo = ""
    case let .edit(item):
      name = item.name
      quantity = item.quantity
      selectedArea = item.area
      selectedSpot = item.spot
      selectedCategory = item.category
      selectedTags = (item.tags ?? []).sorted { $0.name < $1.name }
      hasExpiration = item.expiresAt != nil
      expiresAt = item.expiresAt ?? .now
      memo = item.memo ?? ""
    }
  }

  var title: LocalizedStringKey {
    switch mode {
    case .create: "Add Item"
    case .edit: "Edit Item"
    }
  }

  var saveTitle: LocalizedStringKey {
    switch mode {
    case .create: "Add"
    case .edit: "Save"
    }
  }

  /// 이름·수량만 충족하면 저장 가능. 구역 미선택(`selectedArea == nil`)은 합법이며
  /// "위치 미지정"(미정리함)으로 저장된다 — `Item.area` 옵셔널은 이미 합법이고,
  /// "생성 시 area 강제" 앱 규칙만 완화한 것이다(스키마/모델 변경 없음).
  var canSave: Bool {
    !trimmedName.isEmpty && quantity > 0
  }

  var isEditing: Bool {
    if case .edit = mode { return true }
    return false
  }

  var canDeleteAtMinimumQuantity: Bool {
    isEditing && quantity <= 1
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedMemo: String? {
    let value = memo.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  /// draft 를 SwiftData 에 반영한다. 세부위치를 고르면 장소를 그 세부위치의 장소로
  /// 맞춰 위치 불변식을 유지한다.
  @discardableResult
  func save(into modelContext: ModelContext) -> Item? {
    guard canSave else { return nil }
    let area = selectedSpot?.area ?? selectedArea

    switch mode {
    case .create:
      let item = Item(
        name: trimmedName,
        quantity: quantity,
        memo: trimmedMemo,
        expiresAt: hasExpiration ? expiresAt : nil,
        area: area,
        spot: selectedSpot,
        category: selectedCategory
      )
      item.tags = selectedTags
      modelContext.insert(item)
      return item
    case let .edit(item):
      item.name = trimmedName
      item.normalizedName = Item.normalize(trimmedName)
      item.quantity = quantity
      item.area = area
      item.spot = selectedSpot
      item.category = selectedCategory
      item.tags = selectedTags
      item.expiresAt = hasExpiration ? expiresAt : nil
      item.memo = trimmedMemo
      item.updatedAt = .now
      return item
    }
  }

  /// 편집 중인 물건을 삭제한다(create 모드면 무시).
  func delete(from modelContext: ModelContext) {
    guard case let .edit(item) = mode else { return }
    modelContext.delete(item)
  }
}
