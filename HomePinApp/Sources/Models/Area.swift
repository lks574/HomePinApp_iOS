import Foundation
import SwiftData

/// 구역 — 공간 안의 방/영역(주방·안방·주방펜트리·옷장 등).
/// 하위에 세부위치(Spot)를 두고, 물건(Item)을 직접 가질 수도 있다.
@Model
final class Area {
  @Attribute(.unique) var id: UUID
  var name: String
  var icon: String?
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date

  var space: Space?

  @Relationship(deleteRule: .cascade, inverse: \Spot.area)
  var spots: [Spot]

  /// 이 구역에 직접 속한 물건(세부위치 미지정). 구역 삭제 시 nullify 로 보존된다.
  @Relationship(deleteRule: .nullify, inverse: \Item.area)
  var items: [Item]

  init(
    id: UUID = UUID(),
    name: String,
    icon: String? = nil,
    sortOrder: Int = 0,
    space: Space? = nil,
    createdAt: Date = .now,
    updatedAt: Date = .now,
  ) {
    self.id = id
    self.name = name
    self.icon = icon
    self.sortOrder = sortOrder
    self.space = space
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.spots = []
    self.items = []
  }
}
