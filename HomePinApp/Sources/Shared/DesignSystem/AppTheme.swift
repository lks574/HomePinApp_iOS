import SwiftUI

/// 시안 C 디자인 토큰. 결정: docs/wiki/Decision/2026-06-12-네비게이션-UI구조.md
/// 라이트/다크를 모두 지원한다 — 모든 토큰이 컬러 스킴에 따라 자동 전환되는 동적 색.
/// 다크 팔레트는 라이트의 따뜻한 톤(테라코타·웜그레이)을 어둡게 재해석한 값.
enum AppColor {
  // 배경
  static let pageBackground = Color(lightHex: 0xE7E4DE, darkHex: 0x16130F)
  static let screenBackground = Color(lightHex: 0xF4EFE8, darkHex: 0x1F1B17)
  // 강조
  static let accent = Color(lightHex: 0xC0603C, darkHex: 0xCE6E48)
  static let accentDark = Color(lightHex: 0xA24E2F, darkHex: 0xDD8A63)
  /// accent 그라데이션 위 옅은 라벨(임박 배너 부제 등). accent 면은 두 모드 모두
  /// 테라코타라 라벨은 밝은 톤 유지.
  static let onAccentSubtle = Color(lightHex: 0xF6DDD0, darkHex: 0xF6DDD0)
  // 텍스트
  static let textPrimary = Color(lightHex: 0x2C2722, darkHex: 0xF1ECE5)
  static let textSecondary = Color(lightHex: 0x6F665C, darkHex: 0xC0B7AC)
  static let textTertiary = Color(lightHex: 0x8A8178, darkHex: 0xA39A90)
  static let textMuted = Color(lightHex: 0xA89E92, darkHex: 0x887F75)
  static let textFaint = Color(lightHex: 0xC0AEA0, darkHex: 0x6E655C)
  // 카드 / 표면
  static let card = Color(lightHex: 0xFFFFFF, darkHex: 0x2B2723)
  static let fieldBackground = Color(lightHex: 0xECE5DB, darkHex: 0x34302A)
  /// 리스트 아이템 앞 점 표식.
  static let itemDot = Color(lightHex: 0xE0CDBF, darkHex: 0x4A4036)
  /// 진행바 트랙(빈 부분).
  static let progressTrack = Color(lightHex: 0xEFE7DD, darkHex: 0x3A332C)
  // 장소 배지
  static let badgeBackground = Color(lightHex: 0xF3E2D8, darkHex: 0x3A2A22)
  static let badgeText = Color(lightHex: 0xA24E2F, darkHex: 0xE3A082)
  // 재료 칩
  static let chipHaveBackground = Color(lightHex: 0xF2EDE4, darkHex: 0x322E28)
  static let chipHaveText = Color(lightHex: 0x6F665C, darkHex: 0xC0B7AC)
  static let chipSoonBackground = Color(lightHex: 0xFBEFE8, darkHex: 0x3E2A20)
  static let chipSoonText = Color(lightHex: 0xC0603C, darkHex: 0xE89066)
  static let chipReadyBackground = Color(lightHex: 0xE7F2EB, darkHex: 0x1E2E25)
  static let chipReadyText = Color(lightHex: 0x1F8A5B, darkHex: 0x63CC95)
  static let chipMissingBorder = Color(lightHex: 0xDCD2C5, darkHex: 0x4C443A)
  static let chipMissingText = Color(lightHex: 0xB7AEA2, darkHex: 0x8C8378)
}

extension View {
  /// 시안 카드 스타일: 흰 배경 + 둥근 모서리 + 옅은 그림자.
  func appCard(radius: CGFloat = 20) -> some View {
    background(AppColor.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
      .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
  }
}

/// 타이포그래피 토큰. 2회 이상 반복되는 역할만 토큰화한다(1회용 크기는 원시값 유지).
/// 값은 기존 인라인 스펙과 1:1 동일 — 시각 변화 없음.
extension Font {
  static let appScreenTitle = Font.system(size: 34, weight: .heavy)   // 탭 루트 큰 제목
  static let appValueStrong = Font.system(size: 17, weight: .bold)    // 강조 값(수량 등)
  static let appFieldText = Font.system(size: 17)                     // 입력 필드 텍스트
  static let appItemBody = Font.system(size: 16)                      // 아이템 본문
  static let appRowLabel = Font.system(size: 15, weight: .semibold)   // 행/필드 라벨
  static let appBadge = Font.system(size: 13, weight: .bold)          // 개수 배지
  static let appSectionLabel = Font.system(size: 13, weight: .semibold) // 섹션/부제 라벨
  static let appFootnote = Font.system(size: 13)                      // 보조 설명
  static let appCaptionStrong = Font.system(size: 12.5, weight: .semibold)
  static let appCaption = Font.system(size: 12.5)                     // 캡션
  static let appTag = Font.system(size: 12, weight: .semibold)        // 칩/태그/캡슐 라벨
}
