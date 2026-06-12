import Foundation
import SwiftData

/// 레시피 재료 한 줄. 재고(`Item`)와 매칭되면 `item` 에 연결돼 보유/부족을 판정한다.
/// 매칭 실패해도 `name` 으로 레시피는 온전(식재료=Item 통합 결정).
@Model
final class RecipeIngredient {
  @Attribute(.unique) var id: UUID
  var name: String
  var quantity: Double?
  var unit: String?
  var note: String?
  var sortOrder: Int

  var recipe: Recipe?

  /// 매칭된 재고. 명시적 링크가 없으면 이름 매칭으로 보강한다(Item 삭제 시 nullify).
  var item: Item?

  init(
    id: UUID = UUID(),
    name: String,
    quantity: Double? = nil,
    unit: String? = nil,
    note: String? = nil,
    sortOrder: Int = 0,
    recipe: Recipe? = nil,
    item: Item? = nil,
  ) {
    self.id = id
    self.name = name
    self.quantity = quantity
    self.unit = unit
    self.note = note
    self.sortOrder = sortOrder
    self.recipe = recipe
    self.item = item
  }

  /// 보유 여부 — 매칭된 재고가 있고 수량이 1 이상이면 보유.
  /// (정밀 무게 부족은 다루지 않음 — 존재 기반. Decision 노트 참고.)
  var isInStock: Bool {
    guard let item else { return false }
    return item.quantity > 0
  }
}
