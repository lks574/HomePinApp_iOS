import Foundation
import SwiftData

/// 카테고리 — 물건 분류(주방용품·의류·공구 등). 물건과 1:N.
/// 카테고리 삭제 시 물건은 nullify 로 보존(미분류로 남음).
/// 이름은 `Category`(Darwin 의 시스템 타입)와 충돌을 피하려 `ItemCategory` 로 둔다.
@Model
final class ItemCategory {
  @Attribute(.unique) var id: UUID
  var name: String
  var icon: String?
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date

  @Relationship(deleteRule: .nullify, inverse: \Item.category)
  var items: [Item]

  init(
    id: UUID = UUID(),
    name: String,
    icon: String? = nil,
    sortOrder: Int = 0,
    createdAt: Date = .now,
    updatedAt: Date = .now,
  ) {
    self.id = id
    self.name = name
    self.icon = icon
    self.sortOrder = sortOrder
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.items = []
  }
}
