import SwiftUI

/// 스플래시 이후의 메인 셸. 네이티브 `TabView` 4탭(홈/장소/레시피/설정) + 중앙 mic
/// floating 버튼. mic 는 탭 목적지가 아니라 [추가 | 검색] 시트를 띄우는 액션이라 탭에
/// 넣지 않고 바 위에 오버레이로 띄운다.
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
        .tabItem { Label("홈", systemImage: "house") }
      PlacesListView()
        .tag(AppTab.places)
        .tabItem { Label("장소", systemImage: "square.grid.2x2") }
      RecipesView()
        .tag(AppTab.recipes)
        .tabItem { Label("레시피", systemImage: "book.closed") }
      SettingsView()
        .tag(AppTab.settings)
        .tabItem { Label("설정", systemImage: "gearshape") }
    }
    .tint(AppColor.accent)
    .environment(router)
    .overlay(alignment: .bottom) { micButton }
    .sheet(isPresented: $showingCapture) {
      CaptureSheet()
    }
  }

  /// 4탭 사이 중앙 빈 슬롯 위에 떠 있는 추가/검색 진입 버튼.
  private var micButton: some View {
    Button { showingCapture = true } label: {
      Image(systemName: "mic.fill")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 54, height: 54)
        .background(AppColor.accent, in: Circle())
        .shadow(color: AppColor.accent.opacity(0.42), radius: 8, y: 6)
    }
    .buttonStyle(.plain)
    .padding(.bottom, 30)
    .accessibilityLabel("추가하거나 검색")
  }
}
