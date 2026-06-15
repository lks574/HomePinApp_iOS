import SwiftUI
import UIKit

extension Color {
  /// 0xRRGGBB 형태의 16진수로 색을 만든다.
  init(hex: UInt32) {
    let red = Double((hex >> 16) & 0xFF) / 255
    let green = Double((hex >> 8) & 0xFF) / 255
    let blue = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
  }

  /// 라이트/다크 컬러 스킴에 따라 자동으로 달라지는 동적 색.
  /// (UIColor dynamic provider 기반 → 사용처에서 별도 분기 없이 적용된다.)
  init(lightHex: UInt32, darkHex: UInt32) {
    self.init(uiColor: UIColor { traits in
      UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
    })
  }
}

extension UIColor {
  /// 0xRRGGBB 형태의 16진수로 UIColor 를 만든다(동적 색 구성용).
  convenience init(hex: UInt32) {
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    self.init(red: red, green: green, blue: blue, alpha: 1)
  }
}
