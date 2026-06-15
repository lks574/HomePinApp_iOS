import SwiftUI

/// 이름 첫 글자 배지(둥근 사각). 장소 그리드·상세 헤더 등.
struct AppInitialBadge: View {
  let text: String
  var size: CGFloat = 42
  var fontSize: CGFloat = 17
  var radius: CGFloat = 13

  var body: some View {
    Text(String(text.prefix(1)))
      .font(.system(size: fontSize, weight: .bold))
      .foregroundStyle(AppColor.badgeText)
      .frame(width: size, height: size)
      .background(AppColor.badgeBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
  }
}
