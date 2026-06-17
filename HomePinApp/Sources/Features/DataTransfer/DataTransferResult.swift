import Foundation

/// 가져오기(백업·CSV) 결과 요약. 엔티티별 upsert 건수와 행/엔티티 단위 스킵을 모은다.
/// 사용자 데이터 텍스트가 섞이므로 화면 표시는 `Text(verbatim:)` 로 한다.
struct ImportSummary {
  /// upsert 대상 엔티티 종류.
  enum EntityKind: String {
    case space
    case area
    case spot
    case category
    case tag
    case item
    case recipe
    case recipeIngredient
    case shoppingItem
  }

  /// 엔티티별 처리(생성·갱신) 건수.
  private(set) var counts: [EntityKind: Int] = [:]
  /// 스킵된 행/엔티티의 사유(사람이 읽는 메시지).
  private(set) var skipped: [String] = []

  var totalProcessed: Int {
    counts.values.reduce(0, +)
  }

  var skippedCount: Int {
    skipped.count
  }

  mutating func count(_ kind: EntityKind, by amount: Int = 1) {
    counts[kind, default: 0] += amount
  }

  mutating func skip(_ reason: String) {
    skipped.append(reason)
  }

  /// 사람이 읽는 한 줄 요약(엔티티 합계 + 스킵 수).
  var headline: String {
    if skipped.isEmpty {
      return String(localized: "Imported \(totalProcessed) records.")
    }
    return String(localized: "Imported \(totalProcessed) records, skipped \(skippedCount).")
  }
}

/// 데이터 전송 중 진행/결과 상태(비영속 UI 상태).
enum DataTransferStatus: Equatable {
  case idle
  case working(String)
  case success(String)
  case failure(String)
}
