import Foundation
import SwiftData

/// 태그 — 물건 자유 라벨. 물건과 N:N (inverse 는 Item.tags 에 선언).
@Model
final class Tag {
  @Attribute(.unique) var id: UUID
  var name: String
  var createdAt: Date
  var updatedAt: Date

  var items: [Item]

  init(
    id: UUID = UUID(),
    name: String,
    createdAt: Date = .now,
    updatedAt: Date = .now,
  ) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.items = []
  }
}
