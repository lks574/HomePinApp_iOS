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
    case create(initialName: String = "", area: Area? = nil, spot: Spot? = nil)
    case edit(Item)
  }

  let mode: Mode

  var name: String
  var quantity: Int
  var selectedArea: Area?
  var selectedSpot: Spot?
  var hasExpiration: Bool
  var expiresAt: Date
  var memo: String

  init(mode: Mode) {
    self.mode = mode
    switch mode {
    case let .create(initialName, area, spot):
      name = initialName
      quantity = 1
      selectedArea = spot?.area ?? area
      selectedSpot = spot
      hasExpiration = false
      expiresAt = .now
      memo = ""
    case let .edit(item):
      name = item.name
      quantity = item.quantity
      selectedArea = item.area
      selectedSpot = item.spot
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

  var canSave: Bool {
    !trimmedName.isEmpty && selectedArea != nil && quantity > 0
  }

  var isEditing: Bool {
    if case .edit = mode { return true }
    return false
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
  func save(into modelContext: ModelContext) {
    guard canSave else { return }
    let area = selectedSpot?.area ?? selectedArea

    switch mode {
    case .create:
      modelContext.insert(
        Item(
          name: trimmedName,
          quantity: quantity,
          memo: trimmedMemo,
          expiresAt: hasExpiration ? expiresAt : nil,
          area: area,
          spot: selectedSpot
        )
      )
    case let .edit(item):
      item.name = trimmedName
      item.normalizedName = Item.normalize(trimmedName)
      item.quantity = quantity
      item.area = area
      item.spot = selectedSpot
      item.expiresAt = hasExpiration ? expiresAt : nil
      item.memo = trimmedMemo
      item.updatedAt = .now
    }
  }

  /// 편집 중인 물건을 삭제한다(create 모드면 무시).
  func delete(from modelContext: ModelContext) {
    guard case let .edit(item) = mode else { return }
    modelContext.delete(item)
  }
}
