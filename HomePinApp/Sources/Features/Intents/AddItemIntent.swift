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

    let draft = ItemQuickAddParser.parse(trimmed, areas: areas, spots: spots)
    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      throw AddItemIntentError.parseFailed
    }

    // 위치 불변식: spot 의 area 를 우선한다(spot 없으면 파서가 고른 area, 둘 다 없으면 nil).
    let resolvedArea = draft.spot?.area ?? draft.area
    let quantity = max(1, draft.quantity)

    // `Item(name:)` init 이 normalizedName 을 자동으로 채운다(수동 normalize 불필요).
    let item = Item(
      name: name,
      quantity: quantity,
      area: resolvedArea,
      spot: draft.spot
    )
    context.insert(item)

    do {
      try context.save()
    } catch {
      throw AddItemIntentError.saveFailed
    }

    let location = item.locationPath.isEmpty
      ? String(localized: "Unsorted")
      : item.locationPath
    return .result(
      dialog: IntentDialog(
        AddItemIntent.confirmation(name: name, quantity: quantity, location: location)
      )
    )
  }

  /// "Added milk x2 (Fridge)." 형태의 사후 확인 문구. 수량·위치를 함께 보여준다.
  private static func confirmation(
    name: String,
    quantity: Int,
    location: String
  ) -> LocalizedStringResource {
    "Added \(name) x\(quantity) (\(location))."
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
