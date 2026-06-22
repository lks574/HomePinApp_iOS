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

    // 기존 재고와 같은 이름(normalizedName)이면 새 Item 을 만들지 않고 **수량을 가산**한다
    // (자동 병합 — UI 없는 Siri 의 자연스러운 동작). 같은 키가 여럿이면 최근 수정 대표
    // 하나에만 가산하고(결정적), 위치(area/spot)는 기존 Item 을 그대로 유지한다.
    // `ItemBulkAddModel.bulkInsert` 의 합치기 규칙과 동일하다(거기선 사용자 토글, 여기선 자동).
    let existingItems = (try? context.fetch(FetchDescriptor<Item>())) ?? []
    var representatives = Self.representativesByNormalizedName(existingItems)

    var resultItems: [Item] = []
    for draft in drafts {
      let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
      let key = Item.normalize(name)
      let amount = max(1, draft.quantity)
      if let existing = representatives[key] {
        existing.quantity += amount
        existing.updatedAt = .now
        resultItems.append(existing)
        continue
      }
      // 신규 insert — 위치 불변식: spot 의 area 우선(spot 없으면 파서 area, 둘 다 없으면 nil).
      let item = Item(
        name: name,
        normalizedName: key,
        quantity: amount,
        area: draft.spot?.area ?? draft.area,
        spot: draft.spot
      )
      context.insert(item)
      // 같은 문장 안 동일 이름 중복도 이 새 Item 에 가산되게 대표로 등록한다.
      representatives[key] = item
      resultItems.append(item)
    }

    do {
      try context.save()
    } catch {
      throw AddItemIntentError.saveFailed
    }

    return .result(dialog: AddItemIntent.confirmation(for: resultItems))
  }

  /// 기존 Item 들을 normalizedName 키로 묶어 키마다 최근 수정(`updatedAt` 최신) 대표를 고른다.
  /// 같은 이름이 여럿일 때 가산 대상이 결정적이고 중복 가산이 없게 한다(빈 키 제외).
  /// `ItemBulkAddModel` 의 동명 헬퍼와 같은 규칙(자동 병합 단일 소스가 아니라 미러).
  private static func representativesByNormalizedName(_ items: [Item]) -> [String: Item] {
    var result: [String: Item] = [:]
    for item in items {
      let key = item.normalizedName
      guard !key.isEmpty else { continue }
      if let current = result[key], current.updatedAt >= item.updatedAt { continue }
      result[key] = item
    }
    return result
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
