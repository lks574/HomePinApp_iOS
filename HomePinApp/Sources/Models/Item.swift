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
  /// 매칭/검색용 정규화 키(소문자·공백 정리). `name` 변경 시 함께 갱신한다.
  var normalizedName: String
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

  /// 이 물건을 재료로 쓰는 레시피 재료 라인(레시피 역참조·임박 추천용).
  @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.item)
  var usedInIngredients: [RecipeIngredient]

  #Index<Item>([\.name], [\.normalizedName], [\.expiresAt])

  init(
    id: UUID = UUID(),
    name: String,
    normalizedName: String? = nil,
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
    self.normalizedName = normalizedName ?? Self.normalize(name)
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
    self.usedInIngredients = []
  }

  /// "집 > 주방 > 냉동실" 형태의 위치 경로 (영속화하지 않는 computed).
  var locationPath: String {
    let parts: [String?] = [area?.space?.name, area?.name, spot?.name]
    return parts.compactMap { $0 }.joined(separator: " > ")
  }

  /// 유통기한까지 남은 일수(없으면 nil).
  var daysUntilExpiry: Int? {
    expiresAt.map { Int($0.timeIntervalSince(.now) / 86_400) }
  }

  /// 유통기한 임박(0~3일, 지난 것 제외)인가.
  var isExpiringSoon: Bool {
    guard let days = daysUntilExpiry else { return false }
    return days >= 0 && days <= 3
  }

  /// 이름 정규화: 소문자 + 앞뒤/연속 공백 정리. (동의어 사전은 후속.)
  static func normalize(_ raw: String) -> String {
    raw.lowercased()
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }
}
