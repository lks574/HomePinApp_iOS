import Foundation

/// 영수증 OCR 줄들에서 "품목명 후보" 만 보수적으로 골라낸다.
///
/// 과추론 금지 — 상호/주소 정교 분류는 하지 않는다(애매하면 통과시켜 사용자가 칩에서 지운다).
/// 명백한 비품목(숫자·합계·날짜·사업자번호·전화·카드승인)만 떨궈내고, 줄 끝 가격을 떼어낸 뒤
/// 남는 텍스트를 품목명 후보로 본다. 결과는 `ItemQuickAddParser.parse(multiline:)` 가 추가로
/// 수량/위치를 뽑게 호출부에서 칩으로 합류시킨다.
enum ReceiptLineFilter {
  /// OCR 줄들 → 품목명 후보 줄들. 추출 0건이면 빈 배열(호출부가 안내 폴백).
  static func itemLines(from rawLines: [String]) -> [String] {
    rawLines.compactMap { line in
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }
      guard !isNonItemLine(trimmed) else { return nil }
      let name = stripTrailingPrice(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
      guard hasNameSignal(name) else { return nil }
      return name
    }
  }

  // MARK: - 비품목 줄 판정

  /// 명백한 비품목 줄인지(합계/날짜/사업자번호/전화/카드승인/순수 숫자·기호).
  private static func isNonItemLine(_ line: String) -> Bool {
    let lower = line.lowercased()
    if containsSummaryKeyword(lower) { return true }
    if matches(line, anyOf: datePatterns) { return true }
    if matches(line, anyOf: idPatterns) { return true }
    if isMostlyNumericOrSymbol(line) { return true }
    return false
  }

  /// 합계/소계/부가세/총액/total/subtotal 등 금액 요약 키워드를 포함하는가.
  private static func containsSummaryKeyword(_ lower: String) -> Bool {
    summaryKeywords.contains { lower.contains($0) }
  }

  private static let summaryKeywords: [String] = [
    "합계", "소계", "부가세", "총액", "받을금액", "받은금액", "결제금액", "거스름", "잔액",
    "면세", "과세", "공급가", "할인", "포인트", "적립", "현금", "신용",
    "total", "subtotal", "tax", "vat", "change", "balance", "cash", "card", "amount",
  ]

  /// 줄의 영문/한글 글자가 거의 없고 숫자·통화기호·구분자뿐인가(가격·구분선 줄).
  private static func isMostlyNumericOrSymbol(_ line: String) -> Bool {
    let letters = line.unicodeScalars.filter { isNameLetter($0) }
    return letters.isEmpty
  }

  // MARK: - 줄 끝 가격 제거

  /// 줄 끝에 붙은 가격(`12,000원`·`₩12,000`·맨 끝 숫자 묶음)을 떼어낸다.
  private static func stripTrailingPrice(_ line: String) -> String {
    var result = line
    for pattern in trailingPricePatterns {
      result = replacingMatch(in: result, pattern: pattern, with: "")
    }
    return result
  }

  /// 가격 제거 후에도 글자 신호(한글/영문)가 남아 있는지. 숫자만 남으면 품목 아님.
  private static func hasNameSignal(_ name: String) -> Bool {
    guard name.count >= 2 else { return false }
    return name.unicodeScalars.contains { isNameLetter($0) }
  }

  /// 품목명에 쓰일 수 있는 글자(한글 음절/자모 또는 라틴 문자).
  private static func isNameLetter(_ scalar: Unicode.Scalar) -> Bool {
    let v = scalar.value
    let isHangul = (0xAC00...0xD7A3).contains(v) || (0x3130...0x318F).contains(v)
    let isLatin = (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v)
    return isHangul || isLatin
  }

  // MARK: - 정규식 헬퍼

  /// 날짜/시간 패턴(2024-01-02, 2024.01.02, 01/02, 12:34 등).
  private static let datePatterns: [String] = [
    #"\d{4}[-./]\d{1,2}[-./]\d{1,2}"#,
    #"\d{1,2}:\d{2}"#,
  ]

  /// 사업자번호/전화/카드승인 패턴.
  private static let idPatterns: [String] = [
    #"\d{3}-\d{2}-\d{5}"#,   // 사업자등록번호
    #"\d{2,4}-\d{3,4}-\d{4}"#, // 전화
    #"승인[\s:]*\d"#,
    #"\d{4,}\s*\*+"#,        // 마스킹 카드번호
  ]

  /// 줄 끝 가격 패턴.
  private static let trailingPricePatterns: [String] = [
    #"[₩\$]\s*[\d,]+(\.\d+)?\s*$"#,
    #"[\d,]+\s*원\s*$"#,
    #"[\d,]+(\.\d+)?\s*$"#,
  ]

  private static func matches(_ text: String, anyOf patterns: [String]) -> Bool {
    patterns.contains { pattern in
      text.range(of: pattern, options: .regularExpression) != nil
    }
  }

  private static func replacingMatch(in text: String, pattern: String, with replacement: String) -> String {
    guard let range = text.range(of: pattern, options: .regularExpression) else { return text }
    return text.replacingCharacters(in: range, with: replacement)
  }
}
