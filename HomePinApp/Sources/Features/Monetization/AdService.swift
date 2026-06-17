import Foundation
import Observation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UserMessagingPlatform
#endif

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

#if canImport(UIKit)
import UIKit
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

  /// 전면 광고 트리거 지점. 표시 정책(빈도·쿨다운)은 이 enum 기준으로 정한다.
  ///
  /// R6 정책: 앱 시작·콜드 스타트·작업 무관 탭 전환에서는 전면을 띄우지 않는다. 오직
  /// 사용자가 의미 있는 작업을 끝낸 자연스러운 경계에서만 트리거를 둔다. 현재는 장보기
  /// 세션 완료(`shoppingSessionCompleted`)만 정의한다.
  enum InterstitialTrigger {
    /// 장보기 화면에서 이번 세션 신규 완료(체크) ≥1 후 화면을 벗어나는 시점.
    case shoppingSessionCompleted
  }

  /// 전면 광고 빈도 캡: 하루 1회 + 마지막 노출 이후 최소 간격.
  private enum FrequencyCap {
    /// 마지막 전면 노출 이후 이 시간이 지나지 않았으면 skip(연속 노출 방지).
    static let minimumInterval: TimeInterval = 60 * 30 // 30분
  }

  /// 마지막 전면 노출 시각(epoch 초). 비영속 UI 상태이므로 `@AppStorage` 백킹
  /// `UserDefaults` 에 둔다(SwiftData 아님). `0` 이면 노출 이력 없음.
  private static let lastInterstitialKey = "ad.lastInterstitialShownAt"

  /// 구글 테스트 전면 광고 단위 ID(iOS). 실 ID 는 하드코딩하지 않는다.
  /// 출처: developers.google.com/admob/ios/test-ads
  private static let interstitialTestUnitID = "ca-app-pub-3940256099942544/4411468910"

  /// 구글 테스트 보상형 광고 단위 ID(iOS). 실 ID 는 하드코딩하지 않는다.
  /// 출처: developers.google.com/admob/ios/test-ads
  private static let rewardedTestUnitID = "ca-app-pub-3940256099942544/1712485313"

  /// 누적 "개발자 응원"(보상형 시청 완료) 횟수 저장 키. 어떤 기능도 잠그지 않는
  /// 상징적 카운터이므로 비영속 UI 상태로 `UserDefaults` 에 둔다(SwiftData 아님).
  static let supportCountKey = "ad.developerSupportCount"

  #if canImport(GoogleMobileAds)
  /// 미리 로드해 둔 전면 광고. 표시되면 nil 로 비우고 다음 것을 다시 로드한다.
  @ObservationIgnored private var loadedInterstitial: InterstitialAd?
  /// 전면을 로드 중인지(중복 로드 방지).
  @ObservationIgnored private var isLoadingInterstitial = false
  /// 전면 닫힘 콜백을 메인 액터로 hop 시켜 받는 delegate(self 직접 캡처 회피).
  @ObservationIgnored private var interstitialDelegate: InterstitialDelegate?

  /// 미리 로드해 둔 보상형 광고. 표시되면 nil 로 비우고 다음 것을 다시 로드한다.
  @ObservationIgnored private var loadedRewarded: RewardedAd?
  /// 보상형을 로드 중인지(중복 로드 방지).
  @ObservationIgnored private var isLoadingRewarded = false
  /// 보상형 풀스크린 닫힘 콜백을 메인 액터로 hop 시켜 받는 delegate(self 직접 캡처 회피).
  @ObservationIgnored private var rewardedDelegate: RewardedDelegate?
  #endif

  /// 보상형 광고가 표시 가능한지(미리 로드되어 있는지). 진입점 버튼 활성/비활성에 쓴다.
  /// SDK 미지원 플랫폼(macOS)에서는 항상 `false`.
  var isRewardedReady: Bool {
    #if canImport(GoogleMobileAds)
    loadedRewarded != nil
    #else
    false
    #endif
  }

  /// 누적 개발자 응원 횟수(보상형 시청 완료 누적). 감사 표시에 쓴다.
  var developerSupportCount: Int {
    UserDefaults.standard.integer(forKey: Self.supportCountKey)
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

    // SDK 가동 후 첫 전면·보상형을 미리 로드해 둔다(표시 시점에 준비되어 있게).
    preloadInterstitial()
    preloadRewarded()
  }

  // MARK: - Ad presentation

  /// 전면 광고를 정책상 적격할 때 표시한다. best-effort — 광고가 준비되지 않았거나
  /// 빈도 캡에 걸리면 **조용히 skip** 하고 호출 흐름을 절대 막지 않는다(대기·차단 없음).
  ///
  /// 적격 조건: ① 빈도 캡 통과(하루 1회 + 최소 간격) ② 전면이 로드되어 있음. 표시 후
  /// 다음 전면을 다시 preload 한다. macOS 등 SDK 미지원 플랫폼에서는 no-op.
  func showInterstitialIfEligible(trigger: InterstitialTrigger) {
    _ = trigger
    #if canImport(GoogleMobileAds) && canImport(UIKit)
    guard isFrequencyCapSatisfied else { return }
    presentLoadedInterstitial()
    #endif
  }

  // MARK: - Frequency cap

  /// 빈도 캡 통과 여부: 오늘 아직 노출 안 했고(하루 1회) + 마지막 노출 이후 최소 간격 경과.
  private var isFrequencyCapSatisfied: Bool {
    let lastShownEpoch = UserDefaults.standard.double(forKey: Self.lastInterstitialKey)
    guard lastShownEpoch > 0 else { return true } // 노출 이력 없음
    let lastShown = Date(timeIntervalSince1970: lastShownEpoch)
    let now = Date.now
    if Calendar.current.isDate(lastShown, inSameDayAs: now) { return false } // 하루 1회
    return now.timeIntervalSince(lastShown) >= FrequencyCap.minimumInterval
  }

  /// 전면 노출 시각을 기록한다(빈도 캡 기준점).
  private func recordInterstitialShown() {
    UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.lastInterstitialKey)
  }

  /// 전면 광고를 미리 로드한다. SDK 미지원 플랫폼(macOS)·이미 로드 보유/로드 중이면 no-op.
  func preloadInterstitial() {
    #if canImport(GoogleMobileAds)
    guard loadedInterstitial == nil, !isLoadingInterstitial else { return }
    isLoadingInterstitial = true
    Task { [weak self] in
      let ad = try? await InterstitialAd.load(
        with: Self.interstitialTestUnitID,
        request: Request()
      )
      self?.didFinishLoadingInterstitial(ad)
    }
    #endif
  }

  /// 보상형 광고를 미리 로드한다. SDK 미지원 플랫폼(macOS)·이미 로드 보유/로드 중이면 no-op.
  func preloadRewarded() {
    #if canImport(GoogleMobileAds)
    guard loadedRewarded == nil, !isLoadingRewarded else { return }
    isLoadingRewarded = true
    Task { [weak self] in
      let ad = try? await RewardedAd.load(
        with: Self.rewardedTestUnitID,
        request: Request()
      )
      self?.didFinishLoadingRewarded(ad)
    }
    #endif
  }

  /// 사용자가 직접 누른 경우에만 호출하는 **opt-in 전용** 보상형 광고 표시.
  /// 자동·강제 노출은 절대 없다(R8). 시청을 끝까지 마쳐 보상 콜백을 받으면 "개발자 응원"
  /// 누적 카운터를 1 올린다. 보상은 상징적이며 어떤 기능도 잠그거나 해제하지 않는다(R10).
  ///
  /// 시청 중단·취소·실패·미로드 시에는 보상을 적용하지 않는다(R9). 표시 후 다음 보상형을
  /// 다시 preload 한다. macOS 등 SDK 미지원 플랫폼에서는 no-op 이며 항상 `false`.
  /// - Returns: 보상(응원)을 적립했으면 `true`, 아니면 `false`.
  func presentRewarded() async -> Bool {
    #if canImport(GoogleMobileAds) && canImport(UIKit)
    guard let ad = loadedRewarded, let rootViewController = Self.activeRootViewController() else {
      return false
    }
    loadedRewarded = nil

    let earnedReward = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
      // 보상 여부 플래그를 메인 액터 참조 타입에 담아 두 콜백(present 핸들러·닫힘 delegate)이
      // 공유하게 한다. 둘 다 메인 액터에서 실행되므로 경쟁 없이 안전하다(mutable var 캡처 회피).
      let rewardFlag = RewardFlag()
      // 풀스크린 닫힘 시점에 최종 보상 여부로 한 번만 resume 한다.
      let delegate = RewardedDelegate { [weak self] in
        self?.rewardedDelegate = nil
        self?.preloadRewarded()
        continuation.resume(returning: rewardFlag.didEarn)
      }
      ad.fullScreenContentDelegate = delegate
      rewardedDelegate = delegate
      // present 핸들러는 메인 액터(NS_SWIFT_UI_ACTOR)에서 호출된다. self 를 직접 캡처하지 않고
      // 보상 플래그만 갱신해 닫힘 시점에 반영한다(보상 콜백 수신 시에만 적립).
      ad.present(from: rootViewController) {
        rewardFlag.didEarn = true
      }
    }

    if earnedReward {
      recordDeveloperSupport()
    }
    return earnedReward
    #else
    return false
    #endif
  }

  /// 개발자 응원 누적 횟수를 1 올린다(보상형 시청 완료 시에만 호출). 상징적 카운터.
  private func recordDeveloperSupport() {
    let next = UserDefaults.standard.integer(forKey: Self.supportCountKey) + 1
    UserDefaults.standard.set(next, forKey: Self.supportCountKey)
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

  // MARK: - Interstitial load / present (iOS)

  /// 전면 로드 완료 처리. 성공 시 보관해 두고 delegate 를 연결한다. 실패면 보관 없음
  /// (다음 적격 트리거나 표시 후 재시도에서 다시 preload).
  fileprivate func didFinishLoadingInterstitial(_ ad: InterstitialAd?) {
    isLoadingInterstitial = false
    guard let ad else {
      loadedInterstitial = nil
      return
    }
    let delegate = InterstitialDelegate { [weak self] in
      // 콜백은 nonisolated 로 올 수 있으므로 메인 액터로 hop 한 뒤 self 에 접근한다.
      self?.interstitialDidDismiss()
    }
    ad.fullScreenContentDelegate = delegate
    interstitialDelegate = delegate
    loadedInterstitial = ad
  }

  /// 로드된 전면을 활성 scene 의 root view controller 에서 표시한다. 준비 안 됐거나
  /// rootVC 를 못 찾으면 조용히 skip(흐름 차단 없음). 표시 직후 노출 시각을 기록한다.
  fileprivate func presentLoadedInterstitial() {
    guard let ad = loadedInterstitial, let rootViewController = Self.activeRootViewController() else {
      return
    }
    recordInterstitialShown()
    loadedInterstitial = nil
    ad.present(from: rootViewController)
  }

  /// 전면이 닫히면 다음 전면을 다시 preload 한다.
  private func interstitialDidDismiss() {
    interstitialDelegate = nil
    preloadInterstitial()
  }

  // MARK: - Rewarded load (iOS)

  /// 보상형 로드 완료 처리. 성공 시 보관해 둔다(표시 가능 상태). 실패면 보관 없음
  /// (다음 preload 에서 다시 시도). delegate 는 표시 시점에 연결한다.
  fileprivate func didFinishLoadingRewarded(_ ad: RewardedAd?) {
    isLoadingRewarded = false
    loadedRewarded = ad
  }

  /// 활성 foreground scene 의 keyWindow rootViewController 를 찾는다. 없으면 nil.
  private static func activeRootViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    let keyWindow = activeScene?.windows.first(where: \.isKeyWindow) ?? activeScene?.windows.first
    return keyWindow?.rootViewController
  }
}

/// 전면 광고 풀스크린 콜백 수신. `FullScreenContentDelegate` 메서드는 nonisolated 로
/// 호출될 수 있어 `@MainActor` 인 `AdService` 를 직접 캡처하면 격리 트랩에 걸린다. 이
/// `NSObject` delegate 가 콜백을 받아 `Task { @MainActor in }` 으로 hop 시킨다.
private final class InterstitialDelegate: NSObject, FullScreenContentDelegate {
  private let onDismiss: @MainActor () -> Void

  init(onDismiss: @escaping @MainActor () -> Void) {
    self.onDismiss = onDismiss
  }

  func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
    let handler = onDismiss
    Task { @MainActor in handler() }
  }

  func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
    let handler = onDismiss
    Task { @MainActor in handler() }
  }
}

/// 보상 적립 여부를 present 핸들러와 닫힘 delegate 가 공유하기 위한 메인 액터 참조 박스.
/// 두 콜백 모두 메인 액터에서 실행되므로 격리 위반 없이 안전하게 읽고 쓴다.
@MainActor
private final class RewardFlag {
  var didEarn = false
}

/// 보상형 광고 풀스크린 닫힘 콜백 수신. 전면과 동일하게 `FullScreenContentDelegate` 메서드는
/// nonisolated 로 호출될 수 있어 `@MainActor` 인 `AdService` 를 직접 캡처하지 않고, 이 delegate 가
/// 콜백을 받아 `Task { @MainActor in }` 으로 hop 시킨다. 정상 닫힘·표시 실패 모두 닫힘으로 본다
/// (continuation 을 한 번 resume 시켜 멈추지 않게 한다). 보상 적립 여부는 present 핸들러가 결정한다.
private final class RewardedDelegate: NSObject, FullScreenContentDelegate {
  private let onDismiss: @MainActor () -> Void

  init(onDismiss: @escaping @MainActor () -> Void) {
    self.onDismiss = onDismiss
  }

  func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
    let handler = onDismiss
    Task { @MainActor in handler() }
  }

  func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
    let handler = onDismiss
    Task { @MainActor in handler() }
  }
}
#endif
