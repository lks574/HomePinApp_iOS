import SwiftUI

/// 시안 C 디자인 토큰. 결정: docs/wiki/Decision/2026-06-12-네비게이션-UI구조.md
enum AppColor {
  // 배경
  static let pageBackground = Color(hex: 0xE7E4DE)
  static let screenBackground = Color(hex: 0xF4EFE8)
  // 강조
  static let accent = Color(hex: 0xC0603C)
  static let accentDark = Color(hex: 0xA24E2F)
  /// accent 그라데이션 위 옅은 라벨(임박 배너 부제 등).
  static let onAccentSubtle = Color(hex: 0xF6DDD0)
  // 텍스트
  static let textPrimary = Color(hex: 0x2C2722)
  static let textSecondary = Color(hex: 0x6F665C)
  static let textTertiary = Color(hex: 0x8A8178)
  static let textMuted = Color(hex: 0xA89E92)
  static let textFaint = Color(hex: 0xC0AEA0)
  // 카드 / 표면
  static let card = Color.white
  static let fieldBackground = Color(hex: 0xECE5DB)
  /// 리스트 아이템 앞 점 표식.
  static let itemDot = Color(hex: 0xE0CDBF)
  /// 진행바 트랙(빈 부분).
  static let progressTrack = Color(hex: 0xEFE7DD)
  // 장소 배지
  static let badgeBackground = Color(hex: 0xF3E2D8)
  static let badgeText = Color(hex: 0xA24E2F)
  // 재료 칩
  static let chipHaveBackground = Color(hex: 0xF2EDE4)
  static let chipHaveText = Color(hex: 0x6F665C)
  static let chipSoonBackground = Color(hex: 0xFBEFE8)
  static let chipSoonText = Color(hex: 0xC0603C)
  static let chipReadyBackground = Color(hex: 0xE7F2EB)
  static let chipReadyText = Color(hex: 0x1F8A5B)
  static let chipMissingBorder = Color(hex: 0xDCD2C5)
  static let chipMissingText = Color(hex: 0xB7AEA2)
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
