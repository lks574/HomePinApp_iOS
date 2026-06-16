import SwiftUI

/// 섹션 제목 라벨. 대시보드/리스트의 그룹 헤더용.
struct AppSectionTitle: View {
  let title: LocalizedStringKey
  var uppercase = false

  var body: some View {
    Text(title)
      .textCase(uppercase ? .uppercase : nil)
      .font(.appBadge)
      .foregroundStyle(AppColor.textTertiary)
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
