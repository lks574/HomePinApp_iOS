import Foundation

/// 검색 결과 정렬 등급. 값이 작을수록 더 정확한 매칭(정확 > 접두 > 부분 > 초성 > 근사).
/// 정렬은 tier 우선, 동tier 면 상태 가중치(작을수록 위), 그 다음 이름순.
enum MatchTier: Int, Comparable {
  case exact = 0
  case prefix = 1
  case contains = 2
  case choseong = 3
  case fuzzy = 4

  static func < (lhs: MatchTier, rhs: MatchTier) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// 한 결과 항목의 정렬 점수. 등급(tier) 우선, 동등급이면 상태 가중치(작을수록 위),
/// 마지막은 호출부의 정렬(이름·제목순)이 안정 정렬로 동점을 가른다.
struct SearchRank: Comparable {
  let tier: MatchTier
  /// 상태 가중치. 작을수록 위로 정렬된다(임박은 가산해 위로, 위치 없음은 후순으로).
  let statusWeight: Int

  static func < (lhs: SearchRank, rhs: SearchRank) -> Bool {
    if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
    return lhs.statusWeight < rhs.statusWeight
  }
}

/// 검색 랭킹 계산 유틸. 필드별 매칭 등급과 상태 기반 가중치를 제공한다.
/// 매칭 키는 전부 `Item.normalize` 정규화 후 비교한다(검색 경로의 단일 매칭키 규칙 유지).
enum SearchRanking {
  /// 정규화한 필드값이 정규화한 질의에 대해 어느 등급으로 매칭되는지. 매칭 없으면 nil.
  /// `field`·`query` 는 호출부에서 이미 정규화(`Item.normalize`)한 값을 넘긴다.
  static func matchTier(field: String, query: String) -> MatchTier? {
    guard !field.isEmpty, !query.isEmpty else { return nil }
    if field == query { return .exact }
    if field.hasPrefix(query) { return .prefix }
    if field.contains(query) { return .contains }
    return nil
  }

  /// 여러 필드 중 가장 좋은(값이 작은) 매칭 등급. 하나도 없으면 nil.
  static func bestTier(fields: [String], query: String) -> MatchTier? {
    fields.compactMap { matchTier(field: $0, query: query) }.min()
  }
}
