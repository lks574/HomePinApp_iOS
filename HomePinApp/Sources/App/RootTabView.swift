import SwiftUI

/// 스플래시 이후의 메인 셸. 5-슬롯 탭바로 화면을 전환하고, 중앙 버튼은 [추가 | 검색]
/// 시트를 띄운다. 각 탭은 자체 `NavigationStack` 을 가진다.
struct RootTabView: View {
  @State private var router = AppRouter()
  @State private var showingCapture = false

  var body: some View {
    Group {
      switch router.selectedTab {
      case .home: HomeView()
      case .places: PlacesListView()
      case .recipes: RecipesView()
      case .settings: SettingsView()
      }
    }
    .environment(router)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      AppTabBar(selection: $router.selectedTab) { showingCapture = true }
    }
    .sheet(isPresented: $showingCapture) {
      CaptureSheet()
    }
  }
}
