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
  /// 광고(AdMob) 동의·ATT·SDK 초기화를 먼저 수행한 뒤 `.home` 으로 간다. 추후 온보딩
  /// 여부·데이터 준비·마이그레이션 결과 등도 여기서 판단해 다음 단계를 정한다.
  ///
  /// 광고 준비는 순서대로 ① UMP 동의 → ② ATT → ③ SDK 초기화이며(`AdService.startup()`),
  /// 동의·ATT 거부와 무관하게 앱은 계속 진행한다(차단하지 않음). 최소 스플래시 노출과
  /// 광고 준비를 병렬로 돌려 둘 다 끝나면 전환한다.
  func start(adService: AdService) async {
    async let minimumSplash: Void = Task.sleep(for: .seconds(1))
    async let adStartup: Void = adService.startup()
    _ = try? await minimumSplash
    await adStartup
    phase = .home
  }
}
