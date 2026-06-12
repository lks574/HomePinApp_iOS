import Foundation
import Observation

/// 앱 루트 단계 상태. 스플래시가 **분기지점**이 되어 다음 단계를 정한다.
///
/// 비영속 앱 셸 상태이므로 얇은 `@Observable` 모델로 둔다(상태 관리 규칙: 직결이
/// 기본이되 앱 단계 분기 같은 비영속 상태는 모델로).
@MainActor
@Observable
final class AppModel {
  /// 앱이 보여줄 최초/현재 단계. 추후 분기 추가 예: `.onboarding`, `.locked` 등.
  enum Phase: Equatable {
    case splash
    case home
  }

  private(set) var phase: Phase = .splash

  /// 스플래시 동안 실행되는 시작 로직(분기지점).
  /// 지금은 잠깐 대기 후 `.home` 으로 간다. 추후 온보딩 여부·데이터 준비·마이그레이션
  /// 결과 등을 여기서 판단해 다음 단계를 정한다.
  func start() async {
    try? await Task.sleep(for: .seconds(1))
    phase = .home
  }
}
