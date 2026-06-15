import SwiftData
import SwiftUI

/// 설정 — 표시(테마) · 데이터(현황·전체 정리) · 정보.
struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @AppStorage(AppThemePreference.storageKey) private var themeRaw = AppThemePreference.system.rawValue

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
      .navigationTitle("설정")
      .confirmationDialog(
        "전체 데이터를 정리할까요?",
        isPresented: $showingClearConfirm,
        titleVisibility: .visible
      ) {
        Button("전체 삭제", role: .destructive) { clearAllData() }
        Button("취소", role: .cancel) {}
      } message: {
        Text("물건·장소·수납공간·레시피·분류·태그가 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
      }
    }
  }

  // MARK: - 표시

  private var displaySection: some View {
    Section("표시") {
      Picker("테마", selection: $themeRaw) {
        ForEach(AppThemePreference.allCases) { theme in
          Text(theme.title).tag(theme.rawValue)
        }
      }
    }
  }

  // MARK: - 데이터

  private var dataSection: some View {
    Section("데이터") {
      LabeledContent("물건", value: "\(items.count)개")
      LabeledContent("장소", value: "\(areas.count)곳")
      LabeledContent("레시피", value: "\(recipes.count)개")
      Button(role: .destructive) {
        showingClearConfirm = true
      } label: {
        Text("전체 데이터 정리")
      }
    }
  }

  // MARK: - 정보

  private var infoSection: some View {
    Section("정보") {
      LabeledContent("버전", value: appVersion)
      LabeledContent("저장", value: "이 기기 (SwiftData)")
      Text("HomePin — 집 안 물건을 위치에 핀하고, 말로 넣고 찾는 로컬 앱.\n모든 데이터는 이 기기에만 저장되며 외부로 전송되지 않습니다.")
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
    modelContext.insert(Space(name: "우리집"))
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
