import Foundation

/// 최근 검색어 목록을 JSON 문자열로 `@AppStorage` 에 영속화하기 위한 코덱.
/// 새 `@Model` 을 만들지 않고(비영속 UI 보조 데이터) UserDefaults 에 저장한다.
/// 최신 우선·중복 제거·최대 개수 제한 규칙을 한곳에 둔다.
enum RecentSearches {
  static let storageKey = "recentSearches"
  static let maxCount = 8

  /// 저장된 JSON 문자열을 디코드한다. 비었거나 손상되면 빈 배열.
  static func decode(_ json: String) -> [String] {
    guard let data = json.data(using: .utf8),
          let list = try? JSONDecoder().decode([String].self, from: data)
    else {
      return []
    }
    return list
  }

  /// 배열을 JSON 문자열로 인코드한다(저장용).
  static func encode(_ list: [String]) -> String {
    guard let data = try? JSONEncoder().encode(list),
          let json = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return json
  }

  /// 새 검색어를 맨 앞에 추가한 목록(JSON)을 만든다. 공백 정리 후 빈 값은 무시,
  /// 정규화 키 기준 중복은 제거(기존 항목은 떼고 최신으로 올림), 최대 개수로 자른다.
  static func adding(_ query: String, to json: String) -> String {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return json }
    let key = Item.normalize(trimmed)
    var list = decode(json).filter { Item.normalize($0) != key }
    list.insert(trimmed, at: 0)
    if list.count > maxCount {
      list = Array(list.prefix(maxCount))
    }
    return encode(list)
  }
}
