import SwiftUI

/// 캡슐형 강조 버튼(아이콘 옵션). 헤더 액션 등 작은 액션용.
struct AppPrimaryButton: View {
  let title: String
  var systemImage: String?
  var isEnabled = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.appBadge)
        }
        Text(title)
      }
      .font(.system(size: 14, weight: .bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .frame(height: 36)
      .background(isEnabled ? AppColor.accent : AppColor.textMuted, in: Capsule())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }
}

/// 전체폭 기본 버튼. 시트 하단 저장 등 주요 액션용. (하단 고정은 `appEditorSaveBar`.)
struct AppFullWidthPrimaryButton: View {
  let title: String
  var isEnabled = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.appValueStrong)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
          isEnabled ? AppColor.accent : AppColor.textMuted,
          in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }
}
