import Foundation
import Observation
import SwiftData

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
  /// 추후 온보딩 여부·데이터 준비·마이그레이션 결과 등도 여기서 판단해 다음 단계를 정한다.
  ///
  /// **앱 진입(`.home`)을 네트워크 의존 작업으로 막지 않는다(차단 없음 원칙).** 광고
  /// 준비(① UMP 동의 → ② ATT → ③ SDK 초기화, `AdService.startup()`)와 버전 게이트
  /// 점검(RemoteConfig, `VersionGateService.check()`)은 네트워크에 의존하고 새 설치 직후
  /// 지연·정지할 수 있으므로, 이들을 **백그라운드로 시작만** 하고 await 로 진입을 가두지
  /// 않는다(과거에 이 둘을 하드 게이트로 await 해 스플래시가 멈추는 문제가 있었다). 최소
  /// 스플래시 시간 동안 이들이 진행되며, 결과는 `AppRootView` 가 **반응형으로 관찰**한다
  /// (강제 업데이트 차단 화면·선택 업데이트 알럿은 도착 시 표시).
  ///
  /// 유통기한 알림은 시작 시 권한을 **자동 요청하지 않는다**(`requestAuthorization` 호출 X).
  /// 토글이 켜져 있고 이미 권한이 허용된 경우에만 보류 알림을 전체 재계산하고, 그 외에는
  /// 보류 알림만 정리한다(`reschedule` 가 내부에서 분기). 로컬 작업이라 빠르므로 진입 전에
  /// 합류한다.
  func start(
    adService: AdService,
    versionGate: VersionGateService,
    expiryNotifications: ExpiryNotificationService,
    modelContext: ModelContext,
    notificationsEnabled: Bool
  ) async {
    // 네트워크 의존 시작 작업은 백그라운드로 시작만 한다(진입을 막지 않음). @MainActor 격리는
    // 이들 서비스·이 Task 모두 메인 액터라 그대로 유지된다.
    Task { await adService.startup() }
    Task { await versionGate.check() }

    // 최소 스플래시 노출(위 작업이 이 동안 진행된다).
    try? await Task.sleep(for: .seconds(1))

    // 빠른 로컬 작업(보류 알림 재계산)만 합류한 뒤 진입한다.
    let items = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
    await expiryNotifications.reschedule(for: items, isEnabled: notificationsEnabled)

    phase = .home
  }
}
