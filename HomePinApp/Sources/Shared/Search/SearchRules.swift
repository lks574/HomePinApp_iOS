import Foundation

/// 중앙 검색 자연어 규칙(조사 접미사·불용어·의미 단어)을 번들 리소스(`SearchRules.json`)에서
/// 1회 로드해 캐시한다. 규칙을 코드 상수가 아니라 데이터로 외부화해 사전 편집이
/// 코드 변경 없이 가능하게 한다.
///
/// - `koreanSuffixes` 는 **순서 있는 배열**이다(긴 접미사부터 떼어내야 짧은 접미사가
///   먼저 잘리는 오작동을 막는다). JSON 의 배열 순서를 그대로 유지한다.
/// - `stopwords`·`semanticWords` 는 멤버십 판정용 집합이다.
/// - 리소스는 번들에 강제 포함된다. 누락 시 빈 폴백으로 조용히 동작하지 않고
///   `preconditionFailure` 로 즉시 드러낸다(규칙 누락이 검색 품질을 망가뜨리므로).
struct SearchRules: Decodable {
  let koreanSuffixes: [String]
  let stopwords: Set<String>
  let semanticWords: Set<String>

  /// 번들에서 1회 로드한 공유 규칙.
  static let shared: SearchRules = load()

  private static func load() -> SearchRules {
    guard let url = Bundle.main.url(forResource: "SearchRules", withExtension: "json") else {
      preconditionFailure("SearchRules.json 이 번들에 없습니다. Resources 포함 여부를 확인하세요.")
    }
    do {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode(SearchRules.self, from: data)
    } catch {
      preconditionFailure("SearchRules.json 디코드 실패: \(error)")
    }
  }
}
