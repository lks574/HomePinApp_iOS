import Foundation
import SwiftData

/// 태그 — 자유 라벨. 물건(`Item`)·레시피(`Recipe`)와 N:N 으로 공유한다.
/// (inverse 는 각각 `Item.tags`·`Recipe.tags` 에 선언.)
@Model
final class Tag {
  @Attribute(.unique) var id: UUID
  var name: String
  var createdAt: Date
  var updatedAt: Date

  var items: [Item]
  var recipes: [Recipe]

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
    self.recipes = []
  }
}
