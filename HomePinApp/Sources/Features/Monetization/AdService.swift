import Foundation
import Observation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UserMessagingPlatform
#endif

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// 앱 광고(AdMob) 수익화 오케스트레이션.
///
/// P1 범위: SDK 초기화 + 동의(UMP)·ATT 골격까지만. **광고는 표시하지 않는다.** 전면(P2)·
/// 보상형(P3) 표시는 스텁 시그니처만 두고 본문은 이후 단계에서 채운다.
///
/// 플랫폼: iOS 만 광고. macOS 는 AdMob 미지원이라 no-op 으로 컴파일된다(SDK 타입은
/// `#if canImport(GoogleMobileAds)` 안에만 둬 macOS 에서 보이지 않는다). 화면이 의존하는
/// 공개 인터페이스는 SDK 타입을 노출하지 않아 양 플랫폼에서 동일하게 쓰인다.
///
/// 광고 SDK 는 메인스레드 UI SDK 라 `@MainActor` 로 격리한다. 단, UMP 의 일부 콜백은
/// nonisolated 로 호출될 수 있어 `@MainActor` 타입(self) 을 콜백 클로저에서 직접 캡처하지
/// 않는다 — `nonisolated` 헬퍼 + 연속(continuation)으로 받아 메인 액터로 hop 한다.
@MainActor
@Observable
final class AdService {
  /// SDK 초기화·동의·ATT 시작 절차를 한 번만 수행했는지.
  private(set) var didCompleteStartup = false

  /// 전면 광고 트리거 지점. 표시 정책(빈도·쿨다운)은 P2 에서 이 enum 기준으로 정한다.
  enum InterstitialTrigger {
    case afterSave
    case appResume
  }

  init() {}

  // MARK: - Startup orchestration (P1)

  /// 앱 시작(스플래시) 단계에서 호출하는 광고 준비 절차.
  ///
  /// 순서: ① UMP 동의 정보 갱신 + 필요 시 동의 폼 표시 → ② ATT 권한 요청 →
  /// ③ SDK 초기화. 동의·ATT 를 거부해도 비개인화 광고로 진행하며, 어떤 단계가 실패해도
  /// 앱 흐름을 막지 않는다(throw 하지 않음). 광고 표시는 P1 범위 밖이라 여기서 하지 않는다.
  func startup() async {
    guard !didCompleteStartup else { return }
    didCompleteStartup = true

    await gatherConsentIfNeeded()
    await requestTrackingAuthorizationIfNeeded()
    await startMobileAdsSDK()
  }

  // MARK: - Ad presentation (P2 / P3 스텁)

  /// 전면 광고를 정책상 적격할 때 표시한다. **P1 에서는 표시하지 않는다**(no-op).
  /// 빈도·쿨다운·로드 캐싱 정책과 `GADInterstitialAd` 표시 본문은 P2 에서 채운다.
  func showInterstitialIfEligible(trigger: InterstitialTrigger) {
    _ = trigger
    // P1: 광고 미표시. P2 에서 구현.
  }

  /// 보상형 광고를 표시하고 보상 적립 여부를 돌려준다. **P1 에서는 표시하지 않는다**(no-op).
  /// `GADRewardedAd` 로드·표시·보상 콜백은 P3 에서 채운다.
  /// - Returns: 보상을 적립해야 하면 `true`. P1 에서는 항상 `false`.
  func presentRewarded() async -> Bool {
    // P1: 광고 미표시. P3 에서 구현.
    false
  }
}

// MARK: - iOS 실구현 / macOS no-op

extension AdService {
  /// UMP 동의 정보를 갱신하고, 필요하면 동의 폼을 표시한다. 실패해도 비개인화로 계속 진행.
  private func gatherConsentIfNeeded() async {
    #if canImport(GoogleMobileAds)
    let parameters = RequestParameters()
    // 콜백이 nonisolated 로 올 수 있어 self 를 캡처하지 않고 continuation 으로만 받는다.
    await Self.requestConsentInfoUpdate(with: parameters)
    do {
      try await ConsentForm.loadAndPresentIfRequired(from: nil)
    } catch {
      // 폼 로드·표시 실패는 무시하고 진행한다(동의 미수집 = 비개인화 광고).
    }
    #endif
  }

  /// ATT 권한을 요청한다. 거부·미결정이어도 진행(비개인화 광고). iOS 외에는 no-op.
  private func requestTrackingAuthorizationIfNeeded() async {
    #if canImport(AppTrackingTransparency) && os(iOS)
    _ = await ATTrackingManager.requestTrackingAuthorization()
    #endif
  }

  /// Google Mobile Ads SDK 를 초기화한다. iOS 외에는 no-op.
  private func startMobileAdsSDK() async {
    #if canImport(GoogleMobileAds)
    await MobileAds.shared.start()
    #endif
  }
}

#if canImport(GoogleMobileAds)
extension AdService {
  /// UMP 동의 정보 갱신을 async 로 감싼다. `requestConsentInfoUpdate` 는 완료 핸들러
  /// 기반이고 그 클로저가 nonisolated 로 호출될 수 있다. `@MainActor` 타입(`AdService`)을
  /// 클로저에서 직접 캡처하면 시스템 콜백 격리 트랩에 걸리므로, self 를 캡처하지 않는
  /// `nonisolated static` 헬퍼에서 continuation 으로만 결과를 받는다(에러는 무시하고 진행).
  nonisolated static func requestConsentInfoUpdate(
    with parameters: RequestParameters
  ) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
        continuation.resume()
      }
    }
  }
}
#endif
