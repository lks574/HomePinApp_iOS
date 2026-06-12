import SwiftUI

/// 시안 C 디자인 토큰. 결정: docs/wiki/Decision/2026-06-12-네비게이션-UI구조.md
enum AppColor {
  // 배경
  static let pageBackground = Color(hex: 0xE7E4DE)
  static let screenBackground = Color(hex: 0xF4EFE8)
  // 강조
  static let accent = Color(hex: 0xC0603C)
  static let accentDark = Color(hex: 0xA24E2F)
  // 텍스트
  static let textPrimary = Color(hex: 0x2C2722)
  static let textSecondary = Color(hex: 0x6F665C)
  static let textTertiary = Color(hex: 0x8A8178)
  static let textMuted = Color(hex: 0xA89E92)
  static let textFaint = Color(hex: 0xC0AEA0)
  // 카드 / 표면
  static let card = Color.white
  static let fieldBackground = Color(hex: 0xECE5DB)
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
