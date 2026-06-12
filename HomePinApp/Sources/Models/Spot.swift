import Foundation
import SwiftData

/// 세부위치 — 구역 안의 구체적 수납처(냉동실·두번째 서랍·우측 하단 등).
@Model
final class Spot {
  @Attribute(.unique) var id: UUID
  var name: String
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date

  var area: Area?

  /// 이 세부위치에 속한 물건. 세부위치 삭제 시 nullify 로 보존된다(구역엔 남음).
  @Relationship(deleteRule: .nullify, inverse: \Item.spot)
  var items: [Item]

  init(
    id: UUID = UUID(),
    name: String,
    sortOrder: Int = 0,
    area: Area? = nil,
    createdAt: Date = .now,
    updatedAt: Date = .now,
  ) {
    self.id = id
    self.name = name
    self.sortOrder = sortOrder
    self.area = area
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.items = []
  }
}
