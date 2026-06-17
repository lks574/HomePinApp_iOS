import Foundation

/// 한글 초성 처리 유틸. 외부 의존성 없이 유니코드 산술로 직접 구현한다.
/// - 완성형 음절(가~힣, 0xAC00~0xD7A3)은 초성 인덱스로 분해해 호환 자모 초성으로 바꾼다.
/// - 비한글 문자는 그대로 둔다(영문/숫자 등은 초성 변환 대상이 아님).
enum Hangul {
  /// 19개 초성(호환 자모, 0x3131~). 음절 분해 초성 인덱스와 1:1 대응한다.
  private static let choseongTable: [Character] = [
    "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
    "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
  ]

  private static let syllableBase: UInt32 = 0xAC00
  private static let syllableEnd: UInt32 = 0xD7A3
  /// (중성 21 × 종성 28) — 음절 코드에서 초성 인덱스를 뽑는 제수.
  private static let choseongDivisor: UInt32 = 588

  /// 문자열의 초성 시퀀스. 완성형 음절은 초성 호환 자모로, 그 외 문자는 그대로 보존한다.
  /// 예: "사과 주스" -> "ㅅㄱ ㅈㅅ".
  static func initials(of text: String) -> String {
    String(text.map(initial))
  }

  /// 단일 문자의 초성. 완성형 음절이면 초성 자모, 아니면 원래 문자.
  private static func initial(of character: Character) -> Character {
    guard let scalar = character.unicodeScalars.first,
          character.unicodeScalars.count == 1,
          scalar.value >= syllableBase, scalar.value <= syllableEnd
    else {
      return character
    }
    let index = Int((scalar.value - syllableBase) / choseongDivisor)
    return choseongTable[index]
  }

  /// 질의가 전부 호환 자모 초성 자음(0x3131~0x314E)으로만 이뤄졌는지.
  /// 공백은 허용하되, 비어 있거나 자음이 하나도 없으면 false.
  /// 이때만 초성 매칭을 활성화해 일반 텍스트 질의의 회귀를 막는다.
  static func isChoseongQuery(_ query: String) -> Bool {
    let stripped = query.replacingOccurrences(of: " ", with: "")
    guard !stripped.isEmpty else { return false }
    return stripped.unicodeScalars.allSatisfy { scalar in
      scalar.value >= 0x3131 && scalar.value <= 0x314E
    }
  }
}
