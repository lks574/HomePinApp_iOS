import SwiftUI

/// 스플래시 이후의 메인 셸. 5-슬롯 탭바로 화면을 전환하고, 중앙 마이크는 NL 추가
/// 시트를 띄운다. 각 탭은 자체 `NavigationStack` 을 가진다.
struct RootTabView: View {
  @State private var selection: AppTab = .home
  @State private var showingCapture = false

  var body: some View {
    Group {
      switch selection {
      case .home: HomeView()
      case .places: PlacesListView()
      case .recipes: RecipesView()
      case .settings: SettingsView()
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      AppTabBar(selection: $selection) { showingCapture = true }
    }
    .sheet(isPresented: $showingCapture) {
      CaptureSheet()
    }
  }
}
