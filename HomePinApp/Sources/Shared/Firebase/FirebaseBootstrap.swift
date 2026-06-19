import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Firebase 초기화 부트스트랩.
///
/// `GoogleService-Info.plist` 가 번들에 있을 때만 `FirebaseApp.configure()` 한다. 코드만
/// 먼저 들어간 단계라 plist 가 없을 수 있고, plist 없이 `configure()` 를 부르면 크래시한다.
/// 따라서 plist 존재를 먼저 확인하고, 없으면 조용히 skip 한다 — Analytics·Crashlytics·
/// RemoteConfig 가 모두 no-op 이 되지만 앱 흐름은 막지 않는다(차단 없음).
///
/// 앱 시작 시점에 단 한 번, 가능한 한 이르게 호출한다(`HomePinAppApp.init()`).
enum FirebaseBootstrap {
  /// plist 가 있으면 Firebase 를 구성한다. 이미 구성됐거나 plist 가 없으면 아무것도 하지 않는다.
  @MainActor
  static func configureIfAvailable() {
    #if canImport(FirebaseCore)
    guard FirebaseApp.app() == nil else { return }
    guard hasConfigurationPlist else { return }
    FirebaseApp.configure()
    #endif
  }

  /// Firebase 가 실제로 구성됐는지(plist 존재 + configure 완료). 다른 서비스가 호출 전
  /// 가드로 쓴다(미구성 시 RemoteConfig/Analytics 접근 자체를 피해 크래시를 막는다).
  static var isConfigured: Bool {
    #if canImport(FirebaseCore)
    FirebaseApp.app() != nil
    #else
    false
    #endif
  }

  /// 번들에 `GoogleService-Info.plist` 가 포함되어 있는지. 형식 안내용
  /// `GoogleService-Info.sample.plist` 는 이름이 달라 매칭되지 않는다(실 plist 만 인정).
  private static var hasConfigurationPlist: Bool {
    Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
  }
}
