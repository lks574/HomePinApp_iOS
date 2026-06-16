import SwiftUI

// SwiftUI 의 `Text`/`Picker` 가 자동 현지화하도록 `title` 은 LocalizedStringKey 다.

/// 앱 언어 환경설정. `@AppStorage` 로 저장하고 루트(`AppRootView`)에서
/// `.environment(\.locale, ...)` 로 적용한다(테마의 `preferredColorScheme` 과 동일 위치).
///
/// 기본은 `.system` — 시스템 언어 추종(환경 locale 강제 안 함). `.english`/`.korean`
/// 선택 시 해당 locale 을 환경에 주입해 `Text`/`LocalizedStringKey` 의 String Catalog
/// 조회 언어를 앱 재시작 없이 즉시 전환한다.
enum AppLanguagePreference: String, CaseIterable, Identifiable {
  case system
  case english
  case korean

  var id: String { rawValue }

  /// `@AppStorage` 저장 키.
  static let storageKey = "appLanguagePreference"

  var title: LocalizedStringKey {
    switch self {
    case .system: "Use System Language"
    case .english: "English"
    case .korean: "Korean"
    }
  }

  /// 환경에 주입할 `Locale`. 시스템 추종이면 nil(환경 locale 을 강제하지 않음).
  var locale: Locale? {
    switch self {
    case .system: nil
    case .english: Locale(identifier: "en")
    case .korean: Locale(identifier: "ko")
    }
  }
}
