import Foundation
import SwiftData

/// 공간 — 최상위 장소(집·별장·사무실 등). 하위에 구역(Area)을 둔다.
@Model
final class Space {
  @Attribute(.unique) var id: UUID
  var name: String
  var icon: String?
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date

  @Relationship(deleteRule: .cascade, inverse: \Area.space)
  var areas: [Area]

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
    self.areas = []
  }
}
