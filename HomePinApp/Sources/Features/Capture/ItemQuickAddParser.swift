import Foundation

struct ItemQuickAddDraft {
  let name: String
  let quantity: Int
  let area: Area?
  let spot: Spot?
}

/// 중앙 추가 입력의 짧은 자유 텍스트를 `ItemEditor` prefill 로 바꾸는 규칙 기반 파서.
/// 자동 저장하지 않으므로 확신이 낮은 위치 후보는 적용하지 않고 이름에 남긴다.
enum ItemQuickAddParser {
  private struct Match<Value> {
    let value: Value
    let range: Range<Int>
  }

  static func parse(_ raw: String, areas: [Area], spots: [Spot]) -> ItemQuickAddDraft {
    let tokens = raw
      .components(separatedBy: .whitespacesAndNewlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    guard !tokens.isEmpty else {
      return ItemQuickAddDraft(name: "", quantity: 1, area: nil, spot: nil)
    }

    var used = Array(repeating: false, count: tokens.count)
    let quantity = consumeQuantity(from: tokens, used: &used) ?? 1
    let areaMatch = uniqueBestMatch(in: areas, tokens: tokens, used: used, name: \.name)
    let spotMatch = selectSpotMatch(
      in: spots,
      tokens: tokens,
      used: used,
      selectedArea: areaMatch?.value
    )

    var selectedArea = areaMatch?.value
    let selectedSpot = spotMatch?.value
    if let selectedSpot {
      selectedArea = selectedSpot.area ?? selectedArea
      mark(spotMatch?.range, in: &used)
      if let areaMatch, selectedSpot.area?.id == areaMatch.value.id {
        mark(areaMatch.range, in: &used)
      }
    } else if let areaMatch {
      mark(areaMatch.range, in: &used)
    }

    let name = tokens.enumerated()
      .filter { !used[$0.offset] }
      .map(\.element)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return ItemQuickAddDraft(
      name: name.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : name,
      quantity: quantity,
      area: selectedArea,
      spot: selectedSpot
    )
  }

  private static func selectSpotMatch(
    in spots: [Spot],
    tokens: [String],
    used: [Bool],
    selectedArea: Area?
  ) -> Match<Spot>? {
    let matches = allBestMatches(in: spots, tokens: tokens, used: used, name: \.name)
    guard !matches.isEmpty else { return nil }
    let filtered = selectedArea.map { area in
      matches.filter { $0.value.area?.id == area.id }
    } ?? matches
    guard filtered.count == 1 else { return nil }
    return filtered[0]
  }

  private static func uniqueBestMatch<Value>(
    in values: [Value],
    tokens: [String],
    used: [Bool],
    name: KeyPath<Value, String>
  ) -> Match<Value>? {
    let matches = allBestMatches(in: values, tokens: tokens, used: used, name: name)
    guard matches.count == 1 else { return nil }
    return matches[0]
  }

  private static func allBestMatches<Value>(
    in values: [Value],
    tokens: [String],
    used: [Bool],
    name: KeyPath<Value, String>
  ) -> [Match<Value>] {
    let matches = values.compactMap { value -> Match<Value>? in
      let nameTokens = normalizedTokens(value[keyPath: name])
      guard !nameTokens.isEmpty else { return nil }
      for start in tokens.indices {
        let end = start + nameTokens.count
        guard end <= tokens.count else { continue }
        guard !used[start..<end].contains(true) else { continue }
        let candidate = tokens[start..<end].map { Item.normalize($0) }
        if candidate == nameTokens {
          return Match(value: value, range: start..<end)
        }
      }
      return nil
    }
    let bestLength = matches.map { $0.range.count }.max() ?? 0
    return matches.filter { $0.range.count == bestLength }
  }

  private static func normalizedTokens(_ text: String) -> [String] {
    Item.normalize(text).split(separator: " ").map(String.init)
  }

  private static func consumeQuantity(from tokens: [String], used: inout [Bool]) -> Int? {
    for index in tokens.indices {
      if index + 1 < tokens.count,
         let quantity = bareQuantityValue(tokens[index]),
         isQuantityUnit(tokens[index + 1]) {
        used[index] = true
        used[index + 1] = true
        return quantity
      }
      if let quantity = quantityValue(tokens[index]) {
        used[index] = true
        return quantity
      }
    }
    return nil
  }

  private static func quantityValue(_ token: String) -> Int? {
    let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
    if let number = bareQuantityValue(normalized) {
      return number
    }
    for unit in quantityUnits.sorted(by: { $0.count > $1.count }) {
      guard normalized.hasSuffix(unit) else { continue }
      let numberPart = String(normalized.dropLast(unit.count))
      if let number = bareQuantityValue(numberPart) {
        return number
      }
    }
    return nil
  }

  private static func bareQuantityValue(_ token: String) -> Int? {
    if let value = Int(token), value > 0 {
      return value
    }
    return koreanNumbers[token]
  }

  private static func isQuantityUnit(_ token: String) -> Bool {
    quantityUnits.contains(token)
  }

  private static func mark(_ range: Range<Int>?, in used: inout [Bool]) {
    guard let range else { return }
    for index in range {
      used[index] = true
    }
  }

  private static let quantityUnits: Set<String> = [
    "개", "팩", "병", "봉", "봉지", "박스", "통", "캔", "장", "롤", "묶음", "세트", "포", "입"
  ]

  private static let koreanNumbers: [String: Int] = [
    "한": 1, "하나": 1, "한개": 1,
    "두": 2, "둘": 2, "두개": 2,
    "세": 3, "셋": 3, "세개": 3,
    "네": 4, "넷": 4, "네개": 4,
    "다섯": 5, "여섯": 6, "일곱": 7, "여덟": 8, "아홉": 9, "열": 10
  ]
}
