import Foundation
import Observation
import UserNotifications

/// 유통기한 임박 로컬 알림 오케스트레이션.
///
/// 순수 온디바이스(UserNotifications). 만료일(`Item.expiresAt`)이 있는 물건에 대해
/// **마감 1일 전(D-1)과 당일(D-0) 오전 9시**(로컬 TZ)에 로컬 알림을 예약한다. 서버·계정·
/// 외부 의존성 없음. 권한은 **사용자가 Settings 토글을 켤 때만 on-demand 요청**하고,
/// 시작 시 자동 요청하지 않는다.
///
/// 재계산은 **전체 cancel-and-reschedule**(`removeAllPendingNotificationRequests` 후
/// 재등록)로 한다 — 결정적이고 단순하며 중복·누락을 만들지 않는다. 앱 시작, 그리고
/// 물건 추가/편집/삭제 후에 진입한다.
///
/// `UNUserNotificationCenter` 콜백 격리 트랩을 피하려고 modern async API
/// (`requestAuthorization(options:) async`·`notificationSettings() async`)만 쓰고,
/// `@MainActor` self 를 캡처하는 완료 핸들러 클로저는 두지 않는다.
///
/// 플랫폼: iOS·macOS 공통. UserNotifications 는 양 플랫폼 모두 지원한다.
@MainActor
@Observable
final class ExpiryNotificationService {
  /// 현재 시스템 알림 권한 상태. Settings 가 분기 안내(거부/미결정/허용)에 쓴다.
  /// 시작·토글·앱 활성화 시 갱신한다.
  private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

  /// iOS 가 앱당 보류 가능한 로컬 알림 상한(64개). 마감 빠른 순으로 이 한도까지만 채운다.
  /// `nonisolated` 순수 요청 빌더에서 참조하므로 액터 격리에서 분리한다(상수).
  private nonisolated static let pendingLimit = 64

  /// 알림을 띄울 시각(로컬 TZ 기준 시). `expiresAt` 가 시각 없는 날짜라 앱이 정한다.
  private nonisolated static let notificationHour = 9

  /// 식별자 접두사. 우리 알림만 식별·정리하기 위한 네임스페이스.
  private nonisolated static let identifierPrefix = "expiry"

  private let center = UNUserNotificationCenter.current()

  init() {}

  /// 현재 권한 상태를 시스템에서 다시 읽어 `authorizationStatus` 에 반영한다.
  /// 사용자가 시스템 설정에서 권한을 바꾼 뒤 돌아온 경우를 반영하기 위해 활성화 시 호출한다.
  func refreshAuthorizationStatus() async {
    let settings = await center.notificationSettings()
    authorizationStatus = settings.authorizationStatus
  }

  /// 알림 권한을 요청한다(on-demand). 사용자가 Settings 토글을 켤 때만 호출한다.
  /// 요청 후 최신 상태를 다시 읽어 반영하고, 허용 여부를 반환한다. 실패·거부해도 throw 하지
  /// 않고 흐름을 막지 않는다.
  /// - Returns: 권한이 허용(`.authorized`/`.provisional`)됐으면 `true`.
  @discardableResult
  func requestAuthorization() async -> Bool {
    let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    await refreshAuthorizationStatus()
    return granted
  }

  /// 전체 cancel-and-reschedule. 보류 중인 우리 알림을 모두 지운 뒤, 토글이 켜져 있고
  /// 권한이 허용된 경우에만 미래 만료 물건을 마감 빠른 순으로 64 슬롯까지 다시 예약한다.
  ///
  /// 토글 OFF·권한 미허용이면 모두 취소만 하고 끝낸다(잔여 알림이 남지 않게).
  /// best-effort — 어떤 단계가 실패해도 앱 흐름을 막지 않는다.
  func reschedule(for items: [Item], isEnabled: Bool) async {
    center.removeAllPendingNotificationRequests()

    await refreshAuthorizationStatus()
    guard isEnabled, isAuthorized else { return }

    let requests = Self.makeRequests(for: items, now: .now)
    for request in requests {
      try? await center.add(request)
    }
  }

  /// 토글 OFF 또는 권한 회수 시 우리가 예약한 보류 알림을 전부 제거한다.
  func cancelAll() {
    center.removeAllPendingNotificationRequests()
  }

  private var isAuthorized: Bool {
    authorizationStatus == .authorized || authorizationStatus == .provisional
  }

  // MARK: - Request building (순수 함수)

  /// 만료일이 있는 물건들로 알림 요청 배열을 만든다(D-1·D-0·09:00). 과거/지난 시각 슬롯은
  /// skip 하고, 마감 빠른 순으로 정렬해 트리거 시각 기준 64개까지만 채운다.
  ///
  /// 순수 함수(시스템 접근 없음)라 입력 `now` 만으로 결정된다 — 후반 테스트 단계에서
  /// 검증 대상이 된다.
  nonisolated static func makeRequests(for items: [Item], now: Date) -> [UNNotificationRequest] {
    let calendar = Calendar.current

    let candidates = items
      .compactMap { item -> (item: Item, expiry: Date)? in
        guard let expiry = item.expiresAt else { return nil }
        return (item, expiry)
      }
      .sorted { $0.expiry < $1.expiry }

    // (트리거 시각, 요청) 쌍을 모은 뒤 시각 빠른 순으로 64개까지 채운다.
    var scheduled: [(fireDate: Date, request: UNNotificationRequest)] = []

    for candidate in candidates {
      let expiryDay = calendar.startOfDay(for: candidate.expiry)
      for offset in [DayOffset.d1, DayOffset.d0] {
        guard let day = calendar.date(byAdding: .day, value: offset.dayDelta, to: expiryDay) else { continue }
        guard let fireDate = calendar.date(
          bySettingHour: notificationHour,
          minute: 0,
          second: 0,
          of: day
        ) else { continue }
        // 이미 지난 시각은 skip(과거 알림 등록 방지).
        guard fireDate > now else { continue }

        let request = makeRequest(for: candidate.item, offset: offset, fireDate: fireDate, calendar: calendar)
        scheduled.append((fireDate, request))
      }
    }

    return scheduled
      .sorted { $0.fireDate < $1.fireDate }
      .prefix(pendingLimit)
      .map(\.request)
  }

  /// 물건·오프셋·트리거 시각으로 단일 알림 요청을 만든다. 식별자는 물건 id + 오프셋으로
  /// 결정적으로 둬 충돌·중복을 막는다(cancel-and-reschedule 와 함께 멱등).
  private nonisolated static func makeRequest(
    for item: Item,
    offset: DayOffset,
    fireDate: Date,
    calendar: Calendar
  ) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = String(localized: "Expiring soon")
    content.body = offset.body(itemName: item.name)
    content.sound = .default

    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

    return UNNotificationRequest(
      identifier: "\(identifierPrefix)-\(item.id.uuidString)-\(offset.suffix)",
      content: content,
      trigger: trigger
    )
  }

  /// 알림 오프셋(D-1·D-0). 날짜 델타·식별자 접미사·본문 문구를 한 곳에 모은다.
  private enum DayOffset {
    case d1
    case d0

    var dayDelta: Int {
      switch self {
      case .d1: -1
      case .d0: 0
      }
    }

    var suffix: String {
      switch self {
      case .d1: "d1"
      case .d0: "d0"
      }
    }

    func body(itemName: String) -> String {
      switch self {
      case .d1: String(localized: "\(itemName) expires tomorrow.")
      case .d0: String(localized: "\(itemName) expires today.")
      }
    }
  }
}
