import FoundationModels
import os

/// 자연어(텍스트·음성 공용) → 구조화 추가 드래프트 추출 엔진. 온디바이스
/// Foundation Models(`LanguageModelSession`)로 문장을 `ParsedItemList` 로 뽑아낸다.
///
/// **추출만** 한다 — `Item`·SwiftData·도메인 매칭은 일절 모른다. 출력은 전부 문자열이고,
/// 기존 위치/분류/태그 매칭(없으면생성/있으면매핑)은 도메인 측(`AddDraftResolver`)이
/// 저장 직전에 `Item.normalize(_:)` 로 처리한다. 이렇게 추출(엔진)과 매칭(도메인)을
/// 분리해 모델 표류를 도메인 경계에서 흡수한다(ADR 2026-06-15 NL 추가 파서).
///
/// 동시성: `@MainActor` 가 아니다. 호출 측(`NLParseViewModel`)이 단일 파싱 Task 안에서만
/// `parse(...)` 를 호출하고 그 Task 를 cancel 한다 — STT 엔진과 같은 "단일 소비 Task"
/// 생명주기 규칙. `LanguageModelSession` 인스턴스는 `parse(...)` 호출마다 새로 만들어
/// 메서드 스코프를 벗어나지 않으므로 공유 가변 상태가 없다(`Sendable` 강제 불필요).
struct NLItemParser {
  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "NLItemParser")

  /// 모델 가용성. `.available` 이 아니면 호출 측은 즉시 단건 스텁으로 폴백한다.
  static var availability: SystemLanguageModel.Availability {
    SystemLanguageModel.default.availability
  }

  /// 자연어 문장에서 추가할 물건 목록을 추출한다. 기존 위치/분류/태그 후보(`grounding`)를
  /// 프롬프트에 주입해 자유 텍스트 표류를 줄인다. 실패·취소·빈 결과는 throw 하고,
  /// 호출 측이 단건 스텁으로 폴백한다.
  func parse(_ text: String, grounding: NLParseGrounding) async throws -> [ParsedItem] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    let session = LanguageModelSession(instructions: Self.instructions(grounding))
    let prompt = "다음 문장에서 추가할 물건을 모두 뽑아줘:\n\(trimmed)"

    let response = try await session.respond(to: prompt, generating: ParsedItemList.self)
    return response.content.items
  }

  /// 기존 데이터 후보를 주입한 시스템 지시문. 후보가 비면 그 줄을 생략한다.
  private static func instructions(_ grounding: NLParseGrounding) -> String {
    var lines = [
      "너는 가정용 재고 관리 앱의 입력 도우미다. 사용자가 말하거나 적은 문장에서",
      "추가하려는 물건을 구조화해 뽑는다. 한 문장에 여러 물건이 있으면 모두 분리한다",
      "(예: \"우유랑 계란 샀어\" → 물건 2개). 수량이 없으면 1로 둔다.",
      "위치·세부위치·분류·태그는 문장에 단서가 없으면 빈 문자열 또는 빈 배열로 둔다.",
      "분류와 태그는 문장에 그 단어가 명시적으로 나타날 때만 채운다. 물건의 용도·성격을",
      "추론해 분류나 태그를 지어내지 마라. (한국어 예: '테이프'만 있으면 '비상'·'수리'",
      "같은 태그를 붙이지 않는다. 영어 예: 'tape' alone → no category, no tags.)",
      "이 규칙은 문장의 언어와 무관하게 똑같이 적용한다.",
    ]
    if grounding.hasAny {
      lines.append("아래 기존 후보는 문장에 일치하는 단서가 있을 때만 매칭에 쓰고, 그 경우 후보")
      lines.append("이름을 그대로 쓴다. 단서가 없으면 후보가 있어도 그 필드를 비워 둔다.")
    }
    if !grounding.areas.isEmpty {
      lines.append("기존 구역(장소) 후보: \(grounding.areas.joined(separator: ", "))")
    }
    if !grounding.spots.isEmpty {
      lines.append("기존 세부위치 후보: \(grounding.spots.joined(separator: ", "))")
    }
    if !grounding.spaces.isEmpty {
      lines.append("기존 공간 후보: \(grounding.spaces.joined(separator: ", "))")
    }
    if !grounding.categories.isEmpty {
      lines.append("기존 분류 후보: \(grounding.categories.joined(separator: ", "))")
    }
    if !grounding.tags.isEmpty {
      lines.append("기존 태그 후보: \(grounding.tags.joined(separator: ", "))")
    }
    return lines.joined(separator: "\n")
  }
}

/// 프롬프트에 주입할 기존 데이터 후보(이름 문자열). 도메인 측이 SwiftData 에서 모아
/// 엔진에 넘긴다 — 엔진은 SwiftData 를 모른다.
struct NLParseGrounding: Sendable {
  var spaces: [String]
  var areas: [String]
  var spots: [String]
  var categories: [String]
  var tags: [String]

  static let empty = NLParseGrounding(spaces: [], areas: [], spots: [], categories: [], tags: [])

  /// 주입할 기존 후보가 하나라도 있는가(후보 단서 가드 문구를 넣을지 판단용).
  var hasAny: Bool {
    !spaces.isEmpty || !areas.isEmpty || !spots.isEmpty || !categories.isEmpty || !tags.isEmpty
  }
}

/// 추출 결과 묶음. 다건 배열 지원.
@Generable
struct ParsedItemList {
  @Guide(description: "문장에서 추출한 추가할 물건 목록")
  var items: [ParsedItem]
}

/// 추출한 단일 물건. 전부 문자열/정수 — 도메인 매칭은 저장 직전에 한다.
@Generable
struct ParsedItem {
  @Guide(description: "물건 이름")
  var name: String
  @Guide(description: "수량. 문장에 없으면 1")
  var quantity: Int
  @Guide(description: "공간: 집/사무실 등. 단서 없으면 빈 문자열")
  var space: String
  @Guide(description: "구역(장소): 주방/안방 등. 단서 없으면 빈 문자열")
  var area: String
  @Guide(description: "세부위치: 냉동실/서랍 등. 단서 없으면 빈 문자열")
  var spot: String
  @Guide(description: "분류: 식품/주방용품 등. 문장에 명시될 때만 채우고 추론 금지, 없으면 빈 문자열")
  var category: String
  @Guide(description: "태그 0개 이상. 문장에 명시될 때만 채우고 추론 금지, 없으면 빈 배열")
  var tags: [String]
}
