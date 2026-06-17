import Foundation

/// 편집 거리(Levenshtein) 계산. 외부 의존성 없이 음절 단위 `Character` 배열에 대해
/// 2행 DP 로 구현한다(한 음절을 한 단위로 보므로 한글 오타 한 글자 = 거리 1).
enum Levenshtein {
  /// 두 문자열의 편집 거리. 삽입·삭제·치환 각 1.
  static func distance(_ lhs: String, _ rhs: String) -> Int {
    let a = Array(lhs)
    let b = Array(rhs)
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }

    var previous = Array(0...b.count)
    var current = [Int](repeating: 0, count: b.count + 1)

    for i in 1...a.count {
      current[0] = i
      for j in 1...b.count {
        let cost = a[i - 1] == b[j - 1] ? 0 : 1
        current[j] = min(
          previous[j] + 1, // 삭제
          current[j - 1] + 1, // 삽입
          previous[j - 1] + cost // 치환
        )
      }
      swap(&previous, &current)
    }
    return previous[b.count]
  }

  /// 토큰 길이에 따른 허용 편집 거리 임계. 짧은 토큰(≤3)은 1, 그 이상은 2.
  static func threshold(forLength length: Int) -> Int {
    length <= 3 ? 1 : 2
  }
}
