import Foundation
import SwiftData

/// 장보기 항목 — 사야 할 물건 한 줄. 재고(`Item`)와 독립된 가벼운 체크리스트 엔티티다.
/// 수동 추가/체크/삭제와 레시피 부족분 추가를 다루며, 완료 체크 시 재고에 반영한다.
///
/// `sourceIngredient` 는 레시피 부족분에서 생성된 항목을 원본 재료와 연결하는 훅이다.
/// 재료 삭제 시 nullify 로 끊겨 장보기 항목은 온전히 남는다.
@Model
final class ShoppingItem {
  @Attribute(.unique) var id: UUID
  var name: String
  /// 매칭/검색용 정규화 키(`Item.normalize` 규약 재사용). `name` 변경 시 함께 갱신한다.
  var normalizedName: String
  /// 살 수량(없으면 나중에 정한다는 의미). `Item` 과 달리 옵셔널이다.
  var quantity: Int?
  /// 구매 완료 체크 상태.
  var isChecked: Bool
  var createdAt: Date

  /// 부족분 연동 훅 — 이 항목이 어떤 레시피 재료에서 비롯됐는지.
  @Relationship(deleteRule: .nullify)
  var sourceIngredient: RecipeIngredient?

  init(
    id: UUID = UUID(),
    name: String,
    normalizedName: String? = nil,
    quantity: Int? = nil,
    isChecked: Bool = false,
    createdAt: Date = .now,
    sourceIngredient: RecipeIngredient? = nil,
  ) {
    self.id = id
    self.name = name
    self.normalizedName = normalizedName ?? Item.normalize(name)
    self.quantity = quantity
    self.isChecked = isChecked
    self.createdAt = createdAt
    self.sourceIngredient = sourceIngredient
  }
}
