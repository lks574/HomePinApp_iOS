import Foundation
import Observation

/// 탭 선택 + 탭 간 네비게이션을 담는 얇은 앱 셸 라우터.
/// 비영속 UI 상태라 `@Observable` 모델로 둔다(예: 홈의 장소 바로가기 →
/// 장소 탭으로 전환 + 해당 장소 상세 push). `RootTabView` 가 소유하고
/// `.environment` 로 하위 화면에 주입한다.
@MainActor
@Observable
final class AppRouter {
  /// 현재 선택된 탭.
  var selectedTab: AppTab = .home

  /// 장소 탭의 네비게이션 경로(Area 상세 push 스택). 탭을 떠났다 와도 유지되도록
  /// 탭 뷰 바깥(라우터)에 둔다.
  var placesPath: [Area] = []

  /// 레시피 탭의 네비게이션 경로(Recipe 상세 push 스택). 시트(AI 검색)에서 레시피
  /// 결과를 누르면 레시피 탭으로 전환하며 상세를 push 하므로 탭 뷰 바깥에 둔다.
  var recipesPath: [Recipe] = []

  /// 다른 탭에서 특정 장소 상세로 이동한다(장소 탭 전환 + 상세 push).
  func openPlace(_ area: Area) {
    placesPath = [area]
    selectedTab = .places
  }

  /// 다른 화면(예: AI 검색 시트)에서 특정 레시피 상세로 이동한다(레시피 탭 전환 + 상세 push).
  func openRecipe(_ recipe: Recipe) {
    recipesPath = [recipe]
    selectedTab = .recipes
  }
}
