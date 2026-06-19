import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// 앱 분석·크래시 로깅 얇은 래퍼.
///
/// Firebase Analytics 는 화면 전환·세션·`app_open` 등 기본 이벤트를 자동 수집하므로,
/// 여기서는 "간단한 분석"에 필요한 **소수의 의미 있는 커스텀 이벤트**만 추가로 남긴다.
/// SDK 미구성(plist 없음)·미지원 환경에서는 모두 no-op 이다.
///
/// 호출부가 Firebase 타입을 보지 않도록 SDK 타입은 이 파일 내부(`#if canImport`)에만 둔다.
enum AppAnalytics {
  /// 커스텀 분석 이벤트를 남긴다. 파라미터는 Firebase 규칙(문자열/숫자 값)을 따른다.
  static func log(_ event: String, parameters: [String: Any]? = nil) {
    #if canImport(FirebaseAnalytics)
    guard FirebaseBootstrap.isConfigured else { return }
    Analytics.logEvent(event, parameters: parameters)
    #endif
  }

  /// 치명적이지 않은 오류를 Crashlytics 에 기록한다(크래시와 함께 대시보드에서 본다).
  static func record(error: Error) {
    #if canImport(FirebaseCrashlytics)
    guard FirebaseBootstrap.isConfigured else { return }
    Crashlytics.crashlytics().record(error: error)
    #endif
  }

  /// 디버깅 맥락을 위한 로그 메시지. 직후 크래시가 나면 Crashlytics 리포트에 함께 포함된다.
  static func log(message: String) {
    #if canImport(FirebaseCrashlytics)
    guard FirebaseBootstrap.isConfigured else { return }
    Crashlytics.crashlytics().log(message)
    #endif
  }
}
