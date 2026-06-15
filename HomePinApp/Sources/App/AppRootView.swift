import SwiftUI

/// 앱 셸. 루트 단계(`AppModel.Phase`)에 따라 최초 화면을 전환한다.
/// 단계 분기 로직은 `AppModel.start()` 가 담당한다(셸은 표시만).
struct AppRootView: View {
  @State private var appModel = AppModel()
  @AppStorage(AppThemePreference.storageKey) private var themeRaw = AppThemePreference.system.rawValue

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
    .task {
      await appModel.start()
    }
  }

  private var theme: AppThemePreference {
    AppThemePreference(rawValue: themeRaw) ?? .system
  }
}
