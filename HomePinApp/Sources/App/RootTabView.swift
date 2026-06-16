import SwiftUI

/// 스플래시 이후의 메인 셸. 네이티브 `TabView` 4탭(홈/장소/레시피/설정) + 중앙 AI
/// floating 버튼. AI 버튼은 탭 목적지가 아니라 [추가 | 검색] 시트를 띄우는 액션이라
/// 탭에 넣지 않고 바 위에 오버레이로 띄운다.
///
/// 네이티브 `TabView` 를 쓰는 이유: 스크롤 콘텐츠 하단 인셋(짤림 방지)·홈 인디케이터·
/// 키보드 회피·탭별 상태(스크롤/네비 스택) 보존을 전부 시스템이 처리한다. 커스텀 바를
/// 화면 바깥에 두면 이 인셋 전파가 끊겨 콘텐츠가 탭바에 가려졌다.
struct RootTabView: View {
  @State private var router = AppRouter()
  @State private var showingCapture = false

  var body: some View {
    TabView(selection: $router.selectedTab) {
      HomeView()
        .tag(AppTab.home)
        .tabItem { Label("Home", systemImage: "house") }
      PlacesListView()
        .tag(AppTab.places)
        .tabItem { Label("Places", systemImage: "square.grid.2x2") }
      RecipesView()
        .tag(AppTab.recipes)
        .tabItem { Label("Recipes", systemImage: "book.closed") }
      SettingsView()
        .tag(AppTab.settings)
        .tabItem { Label("Settings", systemImage: "gearshape") }
    }
    .tint(AppColor.accent)
    .environment(router)
    .overlay(alignment: .bottom) { captureButton }
    .sheet(isPresented: $showingCapture) {
      // 시트는 별도 환경 계층이라 부모의 `.environment(router)` 를 자동 상속하지 않는다.
      // 시트에서 레시피 검색 결과 → 레시피 탭 push 하려면 router 를 명시적으로 재주입한다.
      CaptureSheet()
        .environment(router)
    }
  }

  /// 4탭 사이 중앙 빈 슬롯 위에 떠 있는 AI 추가/검색 진입 버튼.
  private var captureButton: some View {
    Button { showingCapture = true } label: {
      Image(systemName: "sparkles")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 54, height: 54)
        .background(AppColor.accent, in: Circle())
        .shadow(color: AppColor.accent.opacity(0.42), radius: 8, y: 6)
    }
    .buttonStyle(.plain)
    .padding(.bottom, 30)
    .accessibilityLabel("AI add or search")
  }
}
