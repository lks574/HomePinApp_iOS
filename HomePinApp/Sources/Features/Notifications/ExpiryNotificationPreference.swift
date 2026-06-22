import Foundation

/// 유통기한 로컬 알림 환경설정. `@AppStorage` 로 저장하고 Settings 토글에서 켠다
/// (테마·언어·iCloud Sync 선례와 동일한 비영속 UI 상태). 기본값은 OFF —
/// 사용자가 명시적으로 켤 때만 권한 요청과 스케줄링이 일어난다(시작 시 자동 요청 없음).
enum ExpiryNotificationPreference {
  /// `@AppStorage` 저장 키.
  static let storageKey = "expiryNotification.isEnabled"
}
