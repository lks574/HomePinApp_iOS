import Foundation
import Observation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseRemoteConfig)
// FirebaseRemoteConfig 는 아직 Sendable 감사가 끝나지 않아, strict concurrency 에서 모듈
// 타입(RemoteConfig 등) 관련 경고가 뜬다. 컴파일러 권고대로 `@preconcurrency` 로 가져와
// 서드파티 SDK 의 Sendable 경고를 흡수한다(우리 코드의 격리는 nonisolated 헬퍼로 이미 안전).
@preconcurrency import FirebaseRemoteConfig
#endif

/// 앱 버전 게이트. Firebase RemoteConfig 가 내려주는 **최신 버전**과 **강제 업데이트
/// 하한 버전**을 현재 앱 버전과 비교해, 진입 시 업데이트 안내·차단 여부를 정한다.
///
/// - `forced`(강제): 현재 버전 < 강제 하한 → 닫을 수 없는 차단 화면(앱 사용 불가, 스토어만).
/// - `optional`(선택): 현재 버전 < 최신 버전 → 닫기 가능한 1회 안내 알럿.
/// - `upToDate`: 최신.
///
/// 비영속 앱 셸 상태라 얇은 `@MainActor @Observable` 서비스로 두고, `AppRootView` 가 소유해
/// `.environment` 로 주입한다(AdService 와 동일 패턴). Firebase 미구성(plist 없음)·fetch
/// 실패 시에는 게이트를 적용하지 않는다 — 어떤 경우에도 앱 흐름을 막지 않는다(차단 없음).
@MainActor
@Observable
final class VersionGateService {
  /// 버전 점검 결과. `latest` 는 사용자에게 안내할 최신 버전 문자열.
  enum Status: Equatable {
    case unknown
    case upToDate
    case optional(latest: String)
    case forced(latest: String)
  }

  private(set) var status: Status = .unknown

  /// 업데이트 버튼이 여는 스토어 URL. RemoteConfig 값이 있으면 그것을, 없으면 기본값을 쓴다.
  private(set) var updateURL: URL?

  /// RemoteConfig 가 내려준 최신 버전(`latest_app_version`). 업데이트 필요 여부와 무관하게,
  /// 최신 상태여도 값이 있으면 보관한다(설정 화면에서 "현재/최신" 표시에 쓴다). fetch 전·
  /// 미구성·값 없음이면 nil.
  private(set) var latestKnownVersion: String?

  /// RemoteConfig 키. 콘솔에서 이 키로 값을 내린다(iOS·macOS 공통, 필요 시 분리 가능).
  private enum Key {
    /// 사용 가능한 최신 앱 버전(예: "1.2.0"). 현재 < 이 값이면 선택 업데이트 안내.
    static let latestVersion = "latest_app_version"
    /// 강제 업데이트 하한 버전. 현재 < 이 값이면 차단(강제 업데이트).
    static let minRequiredVersion = "min_required_app_version"
    /// 업데이트 버튼이 여는 스토어 URL(선택). 비어 있으면 기본값 사용.
    static let storeURL = "update_store_url"
  }

  /// 앱이 아직 스토어에 없어 기본 스토어 URL 은 플레이스홀더다. 출시 후 RemoteConfig
  /// `update_store_url` 로 실제 App Store 링크를 내려 덮어쓴다.
  private static let defaultStoreURLString = "https://apps.apple.com/app/id000000000"

  init() {}

  /// RemoteConfig 를 fetch 해 버전 상태를 갱신한다. 앱 시작(스플래시) 단계에서 호출한다.
  /// Firebase 미구성·fetch 실패 시 상태를 바꾸지 않고 조용히 반환한다(게이트 미적용).
  func check() async {
    #if canImport(FirebaseRemoteConfig)
    guard FirebaseBootstrap.isConfigured else { return }
    guard let values = await Self.fetchRemoteValues() else { return }
    apply(values)
    #endif
  }

  // MARK: - 파생(UI 편의)

  var requiresForcedUpdate: Bool {
    if case .forced = status { return true }
    return false
  }

  var hasOptionalUpdate: Bool {
    if case .optional = status { return true }
    return false
  }

  /// 업데이트가 가능한 경우(선택·강제) 안내할 최신 버전 문자열.
  var latestVersion: String? {
    switch status {
    case .optional(let latest), .forced(let latest):
      return latest
    case .unknown, .upToDate:
      return nil
    }
  }

  // MARK: - 적용 / 버전 비교

  /// fetch 한 원격 값을 현재 앱 버전과 비교해 상태를 정한다.
  private func apply(_ values: RemoteValues) {
    updateURL = values.storeURLString.isEmpty
      ? URL(string: Self.defaultStoreURLString)
      : (URL(string: values.storeURLString) ?? URL(string: Self.defaultStoreURLString))

    // 최신 버전은 업데이트 필요 여부와 무관하게 보관한다(설정 화면 "현재/최신" 표시용).
    if !values.latestVersion.isEmpty {
      latestKnownVersion = values.latestVersion
    }

    let current = Self.currentVersion

    if !values.minRequiredVersion.isEmpty,
       Self.isVersion(current, lessThan: values.minRequiredVersion) {
      let latest = values.latestVersion.isEmpty ? values.minRequiredVersion : values.latestVersion
      status = .forced(latest: latest)
      AppAnalytics.log("app_update_prompt", parameters: ["type": "forced", "latest": latest])
      return
    }

    if !values.latestVersion.isEmpty,
       Self.isVersion(current, lessThan: values.latestVersion) {
      status = .optional(latest: values.latestVersion)
      AppAnalytics.log("app_update_prompt", parameters: ["type": "optional", "latest": values.latestVersion])
      return
    }

    status = .upToDate
  }

  /// 현재 앱 버전(`CFBundleShortVersionString`).
  static var currentVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
  }

  /// 의미 버전 비교: `a < b` 인지. `.numeric` 옵션으로 "1.10.0" > "1.9.0" 을 올바로 처리한다.
  static func isVersion(_ a: String, lessThan b: String) -> Bool {
    a.compare(b, options: .numeric) == .orderedAscending
  }

  // MARK: - RemoteConfig fetch (nonisolated)

  /// fetch 결과로 넘길 Sendable 값 묶음. 메인 액터로 안전하게 건너간다.
  private struct RemoteValues: Sendable {
    let latestVersion: String
    let minRequiredVersion: String
    let storeURLString: String
  }

  #if canImport(FirebaseRemoteConfig)
  /// RemoteConfig fetch+activate 를 self 캡처 없이 수행한다. 완료 핸들러는 nonisolated 로
  /// 호출될 수 있어(시스템 콜백 격리 트랩 회피), `@MainActor` 인 self 를 건드리지 않고 로컬
  /// `RemoteConfig` 핸들만 다뤄 Sendable 값(`RemoteValues`)으로 받는다. 실패하면 nil.
  nonisolated private static func fetchRemoteValues() async -> RemoteValues? {
    let remoteConfig = RemoteConfig.remoteConfig()
    let settings = RemoteConfigSettings()
    // 진입 시 최신 값을 받기 위해 최소 fetch 간격을 짧게 둔다(서버 throttle 은 SDK 가 관리).
    settings.minimumFetchInterval = 0
    remoteConfig.configSettings = settings

    return await withCheckedContinuation { (continuation: CheckedContinuation<RemoteValues?, Never>) in
      remoteConfig.fetchAndActivate { _, error in
        guard error == nil else {
          continuation.resume(returning: nil)
          return
        }
        let values = RemoteValues(
          latestVersion: remoteConfig[Key.latestVersion].stringValue,
          minRequiredVersion: remoteConfig[Key.minRequiredVersion].stringValue,
          storeURLString: remoteConfig[Key.storeURL].stringValue
        )
        continuation.resume(returning: values)
      }
    }
  }
  #endif
}
