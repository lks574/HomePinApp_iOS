import SwiftUI

/// 시안 C 5-슬롯 탭바: 홈 / 장소 / [중앙 🎤] / 레시피 / 설정.
/// 중앙 마이크는 목적지가 아니라 NL 추가 시트를 띄운다.
struct AppTabBar: View {
  @Binding var selection: AppTab
  var onMic: () -> Void

  var body: some View {
    HStack(alignment: .bottom, spacing: 0) {
      tabButton(.home, icon: "house", label: "홈")
      tabButton(.places, icon: "square.grid.2x2", label: "장소")
      micButton
      tabButton(.recipes, icon: "book.closed", label: "레시피")
      tabButton(.settings, icon: "gearshape", label: "설정")
    }
    .padding(.horizontal, 12)
    .padding(.top, 9)
    .padding(.bottom, 4)
    .background(.regularMaterial)
    .overlay(alignment: .top) {
      Divider().opacity(0.6)
    }
  }

  private func tabButton(_ tab: AppTab, icon: String, label: String) -> some View {
    let selected = selection == tab
    return Button {
      selection = tab
    } label: {
      VStack(spacing: 4) {
        Image(systemName: selected ? "\(icon).fill" : icon)
          .font(.system(size: 22))
        Text(label)
          .font(.system(size: 10.5, weight: .semibold))
      }
      .foregroundStyle(selected ? AppColor.accent : AppColor.textMuted)
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
  }

  private var micButton: some View {
    Button(action: onMic) {
      Image(systemName: "mic.fill")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 54, height: 54)
        .background(AppColor.accent, in: Circle())
        .shadow(color: AppColor.accent.opacity(0.42), radius: 8, y: 6)
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
    .offset(y: -14)
    .accessibilityLabel("음성·텍스트로 추가")
  }
}
