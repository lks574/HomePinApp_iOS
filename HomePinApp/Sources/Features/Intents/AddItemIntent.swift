import AppIntents
import Foundation
import SwiftData

/// Siri / App Intents 물건 추가 — 앱을 열지 않고 SwiftData 에 직접 insert 한다.
///
/// 자유 텍스트 한 줄을 받아 규칙 기반 `ItemQuickAddParser` 로 이름·수량·기존 Area/Spot
/// 위치를 추출하고(파서 무변경), 단건 캡처와 같은 쓰기 불변식으로 `Item` 하나를 insert 한 뒤
/// `ProvidesDialog` 로 사후 확인 문구를 돌려준다. UI·네비게이션·딥링크 없음.
///
/// - 위치가 애매하면 파서가 비워 두므로 area=nil("미정리함")로 안전 저장한다(합법).
/// - 쓰기 불변식: `Item(name:)` init 이 `normalizedName` 을 자동 채우고, 위치는
///   `spot?.area ?? area` 로 일관시킨다(단건/다건 캡처와 동일).
/// - 컨테이너 공유: 앱과 **프로세스당 단일 컨테이너**(`AppModelContainer.shared()`)를
///   재사용한다. 인텐트가 자체 컨테이너를 새로 만들면 같은 store 에 ModelContainer 가 둘
///   생겨 fetch 가 트랩(크래시)한다 — 앱 실행 중 Siri 호출 시 죽던 원인이다.
/// - 격리: `ModelContext` 는 `Sendable` 이 아니므로 `perform()` 자체를 `@MainActor` 로 두어
///   `shared().mainContext` 접근을 메인 액터 컨텍스트로 정합시킨다(격리 hop 트랩 회피).
///
/// 결정: `docs/wiki/Decision/2026-06-22-App-Intents-물건추가-도입.md`
struct AddItemIntent: AppIntent {
  static let title: LocalizedStringResource = "Add Item"
  static let description = IntentDescription("Add an item to your home inventory.")

  /// 무엇을 추가할지 자유 텍스트 한 줄(예: "우유 2팩 냉장고"). 비면 follow-up 으로 묻는다.
  @Parameter(
    title: "Item",
    requestValueDialog: "What would you like to add?"
  )
  var phrase: String

  static var parameterSummary: some ParameterSummary {
    Summary("Add \(\.$phrase)")
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw AddItemIntentError.emptyInput
    }

    // 앱과 같은 프로세스당 단일 공유 컨테이너를 쓴다. 인텐트가 별도 컨테이너를 만들면
    // 같은 store 에 컨테이너가 둘 생겨 fetch 가 트랩(크래시)한다.
    let context = AppModelContainer.shared().mainContext

    let areas = (try? context.fetch(FetchDescriptor<Area>())) ?? []
    let spots = (try? context.fetch(FetchDescriptor<Spot>())) ?? []

    // 쉼표·줄바꿈으로 여러 물건을 한 번에 받는다(분절 없으면 1건). 공백은 분절자가 아니라
    // "유기농 우유" 같은 다어절 이름은 보존된다. 단건/다건이 같은 규칙(이름·수량·위치)을 쓴다.
    let drafts = ItemQuickAddParser.parse(multiline: trimmed, areas: areas, spots: spots)
      .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    guard !drafts.isEmpty else {
      throw AddItemIntentError.parseFailed
    }

    var addedItems: [Item] = []
    for draft in drafts {
      let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
      // 위치 불변식: spot 의 area 를 우선한다(spot 없으면 파서가 고른 area, 둘 다 없으면 nil).
      let resolvedArea = draft.spot?.area ?? draft.area
      // `Item(name:)` init 이 normalizedName 을 자동으로 채운다(수동 normalize 불필요).
      let item = Item(
        name: name,
        quantity: max(1, draft.quantity),
        area: resolvedArea,
        spot: draft.spot
      )
      context.insert(item)
      addedItems.append(item)
    }

    do {
      try context.save()
    } catch {
      throw AddItemIntentError.saveFailed
    }

    return .result(dialog: AddItemIntent.confirmation(for: addedItems))
  }

  /// 사후 확인 문구. 1건은 "우유 2개 추가됨 (냉장고)." 처럼 수량·위치를, 여러 건은
  /// "3개 추가됨: 우유, 계란, 빵." 처럼 개수와 이름 목록을 보여준다.
  private static func confirmation(for items: [Item]) -> IntentDialog {
    if items.count == 1, let item = items.first {
      let location = item.locationPath.isEmpty
        ? String(localized: "Unsorted")
        : item.locationPath
      return IntentDialog("Added \(item.name) x\(item.quantity) (\(location)).")
    }
    let names = items.map(\.name).joined(separator: ", ")
    return IntentDialog("Added \(items.count) items: \(names).")
  }
}

/// 인텐트 graceful 에러 — 각 실패를 사용자용 문구로 안내한다(앱 흐름과 무관).
enum AddItemIntentError: Error, CustomLocalizedStringResourceConvertible {
  case emptyInput
  case parseFailed
  case saveFailed

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .emptyInput:
      "Tell me what to add, like \"milk 2\"."
    case .parseFailed:
      "I couldn't read an item name. Try again."
    case .saveFailed:
      "Couldn't save the item. Try again."
    }
  }
}
