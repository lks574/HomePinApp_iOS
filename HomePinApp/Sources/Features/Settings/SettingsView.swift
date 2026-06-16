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
    }
  }

  // MARK: - 액션 / 파생

  /// 모든 사용자 데이터를 삭제하고, 앱이 동작하도록 기본 공간(Space)만 다시 만든다.
  private func clearAllData() {
    do {
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
