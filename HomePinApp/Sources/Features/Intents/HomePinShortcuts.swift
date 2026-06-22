import AppIntents

/// HomePin 의 Siri / Shortcuts 발화 구문 등록.
///
/// v1 은 정적 phrase 만 둔다(파라미터 의존 phrase 없음) — `\(.applicationName)` 만 포함하고
/// 추가 대상은 인텐트 실행 후 follow-up(`requestValueDialog`)으로 받으므로
/// `updateAppShortcutParameters()` 호출이 필요 없다.
///
/// 결정: `docs/wiki/Decision/2026-06-22-App-Intents-물건추가-도입.md`
struct HomePinShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddItemIntent(),
      phrases: [
        "Add an item to \(.applicationName)",
        "Add to \(.applicationName)",
        "New item in \(.applicationName)",
        "\(.applicationName)에 물건 추가",
        "\(.applicationName)에 추가",
        "\(.applicationName) 물건 추가",
      ],
      shortTitle: "Add Item",
      systemImageName: "plus.circle"
    )
  }
}
