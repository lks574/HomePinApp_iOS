import Foundation
import SwiftData

/// 물건 — 핀하는 대상.
/// 위치: 최소한 구역(Area)에 속하고(앱 규칙), 세부위치(Spot)는 선택.
/// 위치/카테고리 삭제 시 nullify 로 보존되어 "위치 미지정"/"미분류" 로 남는다.
/// (`area`·`spot`·`category` 가 옵셔널인 이유 = nullify 보존.)
@Model
final class Item {
  @Attribute(.unique) var id: UUID
  var name: String
  var quantity: Int
  @Attribute(.externalStorage) var photoData: Data?
  var memo: String?
  var expiresAt: Date?
  var createdAt: Date
  var updatedAt: Date

  // 위치
  var area: Area?
  var spot: Spot?

  // 분류
  var category: ItemCategory?

  @Relationship(inverse: \Tag.items)
  var tags: [Tag]

  #Index<Item>([\.name], [\.expiresAt])

  init(
    id: UUID = UUID(),
    name: String,
    quantity: Int = 1,
    photoData: Data? = nil,
    memo: String? = nil,
    expiresAt: Date? = nil,
    area: Area? = nil,
    spot: Spot? = nil,
    category: ItemCategory? = nil,
    createdAt: Date = .now,
    updatedAt: Date = .now,
  ) {
    self.id = id
    self.name = name
    self.quantity = quantity
    self.photoData = photoData
    self.memo = memo
    self.expiresAt = expiresAt
    self.area = area
    self.spot = spot
    self.category = category
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.tags = []
  }

  /// "집 > 주방 > 냉동실" 형태의 위치 경로 (영속화하지 않는 computed).
  var locationPath: String {
    let parts: [String?] = [area?.space?.name, area?.name, spot?.name]
    return parts.compactMap { $0 }.joined(separator: " > ")
  }
}
