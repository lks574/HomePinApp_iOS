import Foundation
import SwiftData

/// 샘플 SwiftData 모델. 매크로 적극 사용 정책 예시(`@Model`, `@Attribute`).
/// 실제 도메인 모델이 생기면 이 파일은 교체한다.
@Model
final class Item {
  @Attribute(.unique) var id: UUID
  var title: String
  var createdAt: Date

  init(id: UUID = UUID(), title: String, createdAt: Date = .now) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
  }
}
