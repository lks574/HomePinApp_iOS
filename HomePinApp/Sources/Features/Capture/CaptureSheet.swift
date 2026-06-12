import SwiftUI

/// NL 추가 입력 시트. (스텁 — Task 7 에서 텍스트+음성 4단계·확인 드래프트로 확장)
struct CaptureSheet: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Image(systemName: "mic.fill")
          .font(.system(size: 40))
          .foregroundStyle(AppColor.accent)
        Text("말하거나 입력해서 추가")
          .font(.headline)
          .foregroundStyle(AppColor.textPrimary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(AppColor.screenBackground)
      .navigationTitle("추가")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("닫기") { dismiss() }
        }
      }
    }
  }
}
