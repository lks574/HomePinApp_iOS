import SwiftData
import SwiftUI

/// 설정 — 표시(테마) · 데이터(현황·전체 정리) · 정보.
struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @AppStorage(AppThemePreference.storageKey) private var themeRaw = AppThemePreference.system.rawValue
  @AppStorage(AppLanguagePreference.storageKey) private var languageRaw = AppLanguagePreference.system.rawValue

  @Query private var items: [Item]
  @Query private var areas: [Area]
  @Query private var recipes: [Recipe]

  @State private var showingClearConfirm = false

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
        dataSection
        infoSection
      }
      .navigationTitle("Settings")
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

  // MARK: - 데이터

  private var dataSection: some View {
    Section("Data") {
      LabeledContent("Items") { Text("count.items.\(items.count)") }
      LabeledContent("Places") { Text("count.places.\(areas.count)") }
      LabeledContent("Recipes") { Text("count.recipes.\(recipes.count)") }
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

  // MARK: - 정보

  private var infoSection: some View {
    Section("About") {
      LabeledContent("Version") { Text(verbatim: appVersion) }
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

  private var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    if let build = info?["CFBundleVersion"] as? String, !build.isEmpty {
      return "\(version) (\(build))"
    }
    return version
  }
}
