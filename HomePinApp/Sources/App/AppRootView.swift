import SwiftUI

/// 앱 셸. 루트 단계(`AppModel.Phase`)에 따라 최초 화면을 전환한다.
/// 단계 분기 로직은 `AppModel.start()` 가 담당한다(셸은 표시만).
struct AppRootView: View {
  @State private var appModel = AppModel()
  @AppStorage(AppThemePreference.storageKey) private var themeRaw = AppThemePreference.system.rawValue
  @AppStorage(AppLanguagePreference.storageKey) private var languageRaw = AppLanguagePreference.system.rawValue

  var body: some View {
    ZStack {
      switch appModel.phase {
      case .splash:
        SplashView()
          .transition(.opacity)
      case .home:
        RootTabView()
          .transition(.opacity)
      }
    }
    .animation(.default, value: appModel.phase)
    .preferredColorScheme(theme.colorScheme)
    .applyLanguage(language)
    .task {
      await appModel.start()
    }
  }

  private var theme: AppThemePreference {
    AppThemePreference(rawValue: themeRaw) ?? .system
  }

  private var language: AppLanguagePreference {
    AppLanguagePreference(rawValue: languageRaw) ?? .system
  }
}

extension View {
  /// 선택 언어를 환경 locale 로 적용한다. 시스템 추종(`nil`)이면 환경을 건드리지 않아
  /// SwiftUI 기본(시스템 언어) 조회를 그대로 쓴다.
  @ViewBuilder
  fileprivate func applyLanguage(_ language: AppLanguagePreference) -> some View {
    if let locale = language.locale {
      environment(\.locale, locale)
    } else {
      self
    }
  }
}
