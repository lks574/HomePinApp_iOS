import SwiftUI

/// 앱 셸. 루트 단계(`AppModel.Phase`)에 따라 최초 화면을 전환한다.
/// 단계 분기 로직은 `AppModel.start()` 가 담당한다(셸은 표시만).
struct AppRootView: View {
  @State private var appModel = AppModel()
  @State private var adService = AdService()
  @State private var versionGate = VersionGateService()
  @State private var expiryNotifications = ExpiryNotificationService()
  /// 선택 업데이트 안내 알럿을 이번 실행에서 한 번만 띄우기 위한 플래그/표시 상태.
  @State private var didPromptOptionalUpdate = false
  @State private var showingOptionalUpdate = false
  @Environment(\.openURL) private var openURL
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(AppThemePreference.storageKey) private var themeRaw = AppThemePreference.system.rawValue
  @AppStorage(AppLanguagePreference.storageKey) private var languageRaw = AppLanguagePreference.system.rawValue
  @AppStorage(ExpiryNotificationPreference.storageKey) private var notificationsEnabled = false

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

      // 강제 업데이트: 앱 전체를 덮는 닫을 수 없는 차단 화면(스토어 이동만 가능).
      if versionGate.requiresForcedUpdate {
        ForcedUpdateView(latestVersion: versionGate.latestVersion, updateURL: versionGate.updateURL)
          .transition(.opacity)
          .zIndex(1)
      }
    }
    .animation(.default, value: appModel.phase)
    .animation(.default, value: versionGate.requiresForcedUpdate)
    .preferredColorScheme(theme.colorScheme)
    .applyLanguage(language)
    .environment(adService)
    .environment(versionGate)
    .environment(expiryNotifications)
    .task {
      await appModel.start(
        adService: adService,
        versionGate: versionGate,
        expiryNotifications: expiryNotifications,
        modelContext: modelContext,
        notificationsEnabled: notificationsEnabled
      )
    }
    // 시스템 설정에서 권한이 바뀐 채 돌아온 경우를 반영하려고 활성화 시 권한 상태를 갱신한다.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await expiryNotifications.refreshAuthorizationStatus() }
    }
    // 선택 업데이트: 닫기 가능한 1회성 안내 알럿. 강제일 때는 차단 화면이 우선이라 띄우지 않는다.
    .onChange(of: versionGate.hasOptionalUpdate) { _, hasUpdate in
      guard hasUpdate, !didPromptOptionalUpdate else { return }
      didPromptOptionalUpdate = true
      showingOptionalUpdate = true
    }
    .alert("Update Available", isPresented: $showingOptionalUpdate) {
      Button("Update") {
        if let url = versionGate.updateURL { openURL(url) }
      }
      Button("Later", role: .cancel) {}
    } message: {
      if let latest = versionGate.latestVersion {
        Text("A new version (\(latest)) of HomePin is available.")
      } else {
        Text("A new version of HomePin is available.")
      }
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
