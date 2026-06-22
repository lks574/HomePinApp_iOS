import SwiftData
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

/// 설정 — 표시(테마) · 알림 · 데이터(현황·전체 정리) · 정보.
struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.openURL) private var openURL
  @Environment(VersionGateService.self) private var versionGate
  @Environment(ExpiryNotificationService.self) private var expiryNotifications
  @AppStorage(AppThemePreference.storageKey) private var themeRaw = AppThemePreference.system.rawValue
  @AppStorage(AppLanguagePreference.storageKey) private var languageRaw = AppLanguagePreference.system.rawValue
  @AppStorage(CloudSyncPreference.storageKey) private var cloudSyncEnabled = false
  @AppStorage(CloudSyncPreference.fallbackReasonKey) private var cloudSyncFallbackReason = ""
  @AppStorage(HomeShareService.acceptedAtKey) private var acceptedHomeShareAt = 0.0
  @AppStorage(HomeShareService.lastImportedAtKey) private var lastImportedHomeShareAt = 0.0
  @AppStorage(ExpiryNotificationPreference.storageKey) private var notificationsEnabled = false

  @Query private var items: [Item]
  @Query private var areas: [Area]
  @Query private var recipes: [Recipe]

  @State private var showingClearConfirm = false
  @State private var showingCloudSyncRestartAlert = false
  @State private var showingCloudSyncUnavailableAlert = false
  @State private var showingHomeShareErrorAlert = false
  @State private var showingHomeShareImportResultAlert = false
  @State private var isChangingCloudSync = false
  @State private var isPreparingHomeShare = false
  @State private var isImportingSharedHome = false
  @State private var homeShareErrorMessage = ""
  @State private var homeShareImportResultMessage = ""
  @State private var homeSharePresentation: HomeSharePresentation?
  @State private var cloudSyncStatus = CloudSyncStatusModel()

  #if os(iOS)
  @Environment(AdService.self) private var adService
  /// 보상형(응원) 광고 표시 중 중복 탭 방지. 표시 후 감사 안내 노출 트리거로도 쓴다.
  @State private var isPresentingSupportAd = false
  @State private var showingSupportThanks = false
  #endif

  var body: some View {
    NavigationStack {
      List {
        displaySection
        notificationsSection
        dataSection
        infoSection
      }
      .navigationTitle("Settings")
      .task {
        await expiryNotifications.refreshAuthorizationStatus()
      }
      .confirmationDialog(
        "Clear all data?",
        isPresented: $showingClearConfirm,
        titleVisibility: .visible
      ) {
        Button("Delete All", role: .destructive) { clearAllData() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("All items, places, storage spots, recipes, categories, and tags will be deleted. This cannot be undone.")
      }
      .alert("Restart HomePin to apply iCloud Sync", isPresented: $showingCloudSyncRestartAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("The storage mode changes the next time HomePin starts.")
      }
      .alert("iCloud Sync Unavailable", isPresented: $showingCloudSyncUnavailableAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(cloudSyncStatus.state.title)
      }
      .alert("Family Sharing Unavailable", isPresented: $showingHomeShareErrorAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(homeShareErrorMessage)
      }
      .alert("Shared Home Imported", isPresented: $showingHomeShareImportResultAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(homeShareImportResultMessage)
      }
      #if os(iOS)
      .sheet(item: $homeSharePresentation) { presentation in
        HomeShareSheet(presentation: presentation)
      }
      #endif
    }
  }

  // MARK: - 표시

  private var displaySection: some View {
    Section("Display") {
      Picker("Theme", selection: $themeRaw) {
        ForEach(AppThemePreference.allCases) { theme in
          Text(theme.title).tag(theme.rawValue)
        }
      }
      Picker("Language", selection: $languageRaw) {
        ForEach(AppLanguagePreference.allCases) { language in
          Text(language.title).tag(language.rawValue)
        }
      }
    }
  }

  // MARK: - 알림

  /// 유통기한 임박 로컬 알림 설정. 토글을 켜면 그 자리에서 권한을 요청하고(on-demand),
  /// 시스템에서 거부됐으면 토글은 사용자 의도로 유지하되 별도 안내 행("허용 안 됨 — 설정
  /// 열기")으로 분기한다. 끄면 보류 알림을 모두 취소한다.
  private var notificationsSection: some View {
    Section("Notifications") {
      VStack(alignment: .leading, spacing: 8) {
        Toggle("Expiry Reminders", isOn: notificationsBinding)
        Text("Get a local reminder the day before and on the expiry date (9 AM) for items with an expiration date. All scheduling happens on this device.")
          .font(.footnote)
          .foregroundStyle(.secondary)
        notificationsAuthorizationRow
      }
    }
  }

  /// 토글이 켜져 있는데 시스템 권한이 허용 상태가 아닐 때만 안내 행을 보여준다. 거부면
  /// "허용 안 됨 — 설정 열기", 미결정이면 다시 켜 보라는 안내. 허용 상태면 행을 숨긴다.
  @ViewBuilder
  private var notificationsAuthorizationRow: some View {
    if notificationsEnabled {
      switch expiryNotifications.authorizationStatus {
      case .denied:
        VStack(alignment: .leading, spacing: 6) {
          Label("Notifications are not allowed", systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.orange)
          Button {
            openSystemNotificationSettings()
          } label: {
            Label("Open Settings", systemImage: "gear")
          }
        }
      case .notDetermined:
        Label("Turn the toggle off and on again to allow notifications.", systemImage: "info.circle")
          .font(.footnote)
          .foregroundStyle(.secondary)
      default:
        EmptyView()
      }
    }
  }

  private var notificationsBinding: Binding<Bool> {
    Binding {
      notificationsEnabled
    } set: { newValue in
      guard notificationsEnabled != newValue else { return }
      notificationsEnabled = newValue
      if newValue {
        enableExpiryNotifications()
      } else {
        expiryNotifications.cancelAll()
      }
    }
  }

  /// 토글 ON 시 권한을 요청하고(거부해도 토글 유지·차단 없음), 허용되면 현재 재고로 전체
  /// 스케줄을 재계산한다.
  private func enableExpiryNotifications() {
    Task {
      await expiryNotifications.requestAuthorization()
      let allItems = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
      await expiryNotifications.reschedule(for: allItems, isEnabled: notificationsEnabled)
    }
  }

  /// 시스템 알림 설정 화면을 연다. iOS 는 앱 설정 deep link, macOS 는 알림 환경설정 패널.
  private func openSystemNotificationSettings() {
    #if canImport(UIKit)
    if let url = URL(string: UIApplication.openSettingsURLString) {
      openURL(url)
    }
    #elseif os(macOS)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
      openURL(url)
    }
    #endif
  }

  // MARK: - 데이터

  private var dataSection: some View {
    Section("Data") {
      LabeledContent("Items") { Text("count.items.\(items.count)") }
      LabeledContent("Places") { Text("count.places.\(areas.count)") }
      LabeledContent("Recipes") { Text("count.recipes.\(recipes.count)") }
      cloudSyncRow
      NavigationLink {
        DataTransferView()
      } label: {
        Text("Backup & Import")
      }
      Button(role: .destructive) {
        showingClearConfirm = true
      } label: {
        Text("Clear All Data")
      }
    }
  }

  private var cloudSyncRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle("iCloud Sync", isOn: cloudSyncBinding)
        .disabled(isChangingCloudSync)
      LabeledContent("iCloud Account") {
        Text(cloudSyncStatus.state.title)
      }
      Button {
        cloudSyncStatus.refresh()
      } label: {
        Label("Check iCloud Account", systemImage: "icloud")
      }
      familySharingRow
      Text("Sync uses CloudKit private database for this iCloud account. Family sharing sends an invite with the current home data snapshot, and accepted shares can be imported into local data.")
        .font(.footnote)
        .foregroundStyle(.secondary)
      if !cloudSyncFallbackReason.isEmpty {
        Label(cloudSyncFallbackReason, systemImage: "exclamationmark.triangle")
          .font(.footnote)
          .foregroundStyle(.orange)
      }
    }
  }

  private var familySharingRow: some View {
    #if os(iOS)
    VStack(alignment: .leading, spacing: 8) {
      Button {
        prepareHomeShare()
      } label: {
        Label("Share Home Data", systemImage: "person.2")
      }
      .disabled(!cloudSyncEnabled || isPreparingHomeShare)

      Button {
        importSharedHome()
      } label: {
        Label("Import Shared Home Data", systemImage: "square.and.arrow.down")
      }
      .disabled(acceptedHomeShareAt <= 0 || isImportingSharedHome)

      if acceptedHomeShareAt > 0 {
        Text("Accepted shared home: \(Date(timeIntervalSince1970: acceptedHomeShareAt).formatted(date: .abbreviated, time: .shortened))")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      if lastImportedHomeShareAt > 0 {
        Text("Last shared import: \(Date(timeIntervalSince1970: lastImportedHomeShareAt).formatted(date: .abbreviated, time: .shortened))")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    #else
    Label("Share Home Data is available on iOS", systemImage: "person.2.slash")
      .foregroundStyle(.secondary)
    #endif
  }

  private var cloudSyncBinding: Binding<Bool> {
    Binding {
      cloudSyncEnabled
    } set: { newValue in
      guard cloudSyncEnabled != newValue else { return }
      if newValue {
        enableCloudSyncIfAvailable()
      } else {
        cloudSyncEnabled = false
        cloudSyncFallbackReason = ""
        showingCloudSyncRestartAlert = true
      }
    }
  }

  private func enableCloudSyncIfAvailable() {
    guard !isChangingCloudSync else { return }
    isChangingCloudSync = true
    Task {
      let isAvailable = await cloudSyncStatus.checkAvailability()
      isChangingCloudSync = false
      guard isAvailable else {
        cloudSyncEnabled = false
        showingCloudSyncUnavailableAlert = true
        return
      }
      cloudSyncFallbackReason = ""
      cloudSyncEnabled = true
      showingCloudSyncRestartAlert = true
    }
  }

  private func prepareHomeShare() {
    guard cloudSyncEnabled else {
      homeShareErrorMessage = "Turn on iCloud Sync before sharing home data."
      showingHomeShareErrorAlert = true
      return
    }
    guard !isPreparingHomeShare else { return }
    isPreparingHomeShare = true
    Task {
      do {
        homeSharePresentation = try await HomeShareService.prepareShare(from: modelContext)
      } catch {
        homeShareErrorMessage = error.localizedDescription
        showingHomeShareErrorAlert = true
      }
      isPreparingHomeShare = false
    }
  }

  private func importSharedHome() {
    guard !isImportingSharedHome else { return }
    isImportingSharedHome = true
    Task {
      do {
        let result = try await HomeShareService.importAcceptedShare(into: modelContext)
        homeShareImportResultMessage = result.message
        showingHomeShareImportResultAlert = true
      } catch {
        homeShareErrorMessage = error.localizedDescription
        showingHomeShareErrorAlert = true
      }
      isImportingSharedHome = false
    }
  }

  // MARK: - 정보

  private var infoSection: some View {
    Section("About") {
      LabeledContent("Version") { Text(verbatim: appVersion) }
      latestVersionRow
      updateStatusRow
      LabeledContent("Storage") { Text("This device (SwiftData)") }
      Text("HomePin — a local app to pin your home's items to places, and add and find them by voice.\nAll data is stored only on this device and is never sent anywhere.")
        .font(.footnote)
        .foregroundStyle(.secondary)
      #if os(iOS)
      supportRow
      #endif
    }
  }

  #if os(iOS)
  /// 개발자 응원하기(보상형 광고 opt-in). 사용자가 직접 누른 경우에만 광고를 표시하고,
  /// 시청을 끝까지 마쳐 보상 콜백을 받으면 누적 응원 횟수가 올라간다. 어떤 기능도 잠그지
  /// 않는 상징적 응원이다. 광고가 준비되지 않았으면 버튼을 비활성화한다(흐름 차단 없음).
  private var supportRow: some View {
    let supportCount = adService.developerSupportCount
    return VStack(alignment: .leading, spacing: 6) {
      Button {
        presentSupportAd()
      } label: {
        Label("Support the developer", systemImage: "heart")
      }
      .disabled(!adService.isRewardedReady || isPresentingSupportAd)

      if supportCount > 0 {
        Text("thanks.support.\(supportCount)")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        Text("Watch a short ad to cheer on the developer. It doesn't unlock anything — it's just a thank-you.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .alert("Thanks for your support!", isPresented: $showingSupportThanks) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Your support means a lot. Thank you for cheering on the developer.")
    }
  }

  /// opt-in 보상형 광고 표시. 보상 콜백을 받으면 감사 안내를 띄운다.
  private func presentSupportAd() {
    guard !isPresentingSupportAd else { return }
    isPresentingSupportAd = true
    Task {
      let earned = await adService.presentRewarded()
      isPresentingSupportAd = false
      if earned {
        showingSupportThanks = true
      }
    }
  }
  #endif

  // MARK: - 액션 / 파생

  /// 모든 사용자 데이터를 삭제하고, 앱이 동작하도록 기본 공간(Space)만 다시 만든다.
  private func clearAllData() {
    do {
      try modelContext.delete(model: ShoppingItem.self)
      try modelContext.delete(model: Item.self)
      try modelContext.delete(model: RecipeIngredient.self)
      try modelContext.delete(model: Recipe.self)
      try modelContext.delete(model: Spot.self)
      try modelContext.delete(model: Area.self)
      try modelContext.delete(model: ItemCategory.self)
      try modelContext.delete(model: Tag.self)
      try modelContext.delete(model: Space.self)
      try modelContext.save()
    } catch {
      assertionFailure("전체 데이터 정리 실패: \(error)")
    }
    // 장소 추가(PlaceEditor 가 첫 Space 사용)가 유효하도록 기본 공간을 복구한다.
    // 시드와 동일하게 시스템 언어 기준 기본 공간명을 쓴다(생성 시점 1회 고정 데이터).
    modelContext.insert(Space(name: SeedText.current.space))
    try? modelContext.save()
  }

  /// 앱 버전 옆 업데이트 상태. RemoteConfig 버전 게이트(`VersionGateService`)가 정한 상태에
  /// 따라 "업데이트 가능"(최신 버전 + 스토어 버튼) 또는 "최신 버전"을 보여준다. 점검 전
  /// (`unknown`)이거나 게이트 미적용 시에는 아무것도 표시하지 않는다.
  @ViewBuilder
  private var updateStatusRow: some View {
    switch versionGate.status {
    case .optional, .forced:
      VStack(alignment: .leading, spacing: 6) {
        Label("Update available", systemImage: "arrow.up.circle")
          .foregroundStyle(AppColor.accent)
        Button {
          if let url = versionGate.updateURL { openURL(url) }
        } label: {
          Label("Update in App Store", systemImage: "arrow.up.right.square")
        }
      }
    case .upToDate:
      Label("Up to date", systemImage: "checkmark.circle")
        .foregroundStyle(.secondary)
    case .unknown:
      EmptyView()
    }
  }

  /// RemoteConfig 가 내려준 최신 버전 행. 현재 앱 버전("Version") 바로 아래에 표시한다.
  /// 값을 받기 전(미구성·fetch 전·값 없음)에는 표시하지 않는다.
  @ViewBuilder
  private var latestVersionRow: some View {
    if let latest = versionGate.latestKnownVersion {
      LabeledContent("Latest Version") { Text(verbatim: latest) }
    }
  }

  private var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    if let build = info?["CFBundleVersion"] as? String, !build.isEmpty {
      return "\(version) (\(build))"
    }
    return version
  }
}
