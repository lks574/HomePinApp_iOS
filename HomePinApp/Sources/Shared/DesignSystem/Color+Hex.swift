import SwiftUI

extension Color {
  /// 0xRRGGBB 형태의 16진수로 색을 만든다.
  init(hex: UInt32) {
    let red = Double((hex >> 16) & 0xFF) / 255
    let green = Double((hex >> 8) & 0xFF) / 255
    let blue = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
  }
}
