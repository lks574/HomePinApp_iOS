import SwiftUI

// SwiftUI 의 `Text`/`Picker` 가 자동 현지화하도록 `title` 은 LocalizedStringKey 다.

/// 앱 테마 환경설정. `@AppStorage` 로 저장하고 루트(`AppRootView`)에서
/// `preferredColorScheme` 으로 적용한다.
///
/// 주의: 디자인 토큰(`AppColor`)이 아직 라이트 고정값이라, `.dark` 선택은 시스템이
/// 그리는 UI(설정 List 등)에만 온전히 반영된다. 커스텀 토큰 화면의 다크 팔레트는 후속.
enum AppThemePreference: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  /// `@AppStorage` 저장 키.
  static let storageKey = "appThemePreference"

  var title: LocalizedStringKey {
    switch self {
    case .system: "Use System Setting"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  /// SwiftUI `preferredColorScheme` 값(시스템은 nil = OS 설정 따름).
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}
