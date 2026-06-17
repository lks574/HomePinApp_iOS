import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
  /// 0xRRGGBB 형태의 16진수로 색을 만든다.
  init(hex: UInt32) {
    let red = Double((hex >> 16) & 0xFF) / 255
    let green = Double((hex >> 8) & 0xFF) / 255
    let blue = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
  }

  /// 라이트/다크 컬러 스킴에 따라 자동으로 달라지는 동적 색.
  /// 플랫폼 동적 색 provider(iOS `UIColor` / macOS `NSColor`) 기반이라 사용처에서 별도
  /// 분기 없이 적용된다.
  init(lightHex: UInt32, darkHex: UInt32) {
    #if os(macOS)
    self.init(nsColor: NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      return NSColor(hex: isDark ? darkHex : lightHex)
    })
    #else
    self.init(uiColor: UIColor { traits in
      UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
    })
    #endif
  }
}

#if os(macOS)
extension NSColor {
  /// 0xRRGGBB 형태의 16진수로 NSColor 를 만든다(동적 색 구성용).
  convenience init(hex: UInt32) {
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
  }
}
#else
extension UIColor {
  /// 0xRRGGBB 형태의 16진수로 UIColor 를 만든다(동적 색 구성용).
  convenience init(hex: UInt32) {
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    self.init(red: red, green: green, blue: blue, alpha: 1)
  }
}
#endif
