import SwiftData
import SwiftUI

/// NL 추가 입력 시트 — 텍스트 + 음성 진입(2-입력). UI 우선이라 STT/AI 파싱은 후속.
/// 지금은 텍스트로 빠르게 이름만 담는다(위치/분류는 AI 단계에서 자동 채움 예정).
struct CaptureSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var text = ""
  @State private var showMicHint = false
  @FocusState private var focused: Bool

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        Text("말하거나 입력해서 추가")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(spacing: 12) {
          TextField("예: 냉동실에 소고기 두 팩 넣었어", text: $text, axis: .vertical)
            .font(.system(size: 17))
            .lineLimit(2...5)
            .focused($focused)
          Divider()
          HStack(spacing: 10) {
            Button { showMicHint = true } label: {
              Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AppColor.accent, in: Circle())
            }
            .buttonStyle(.plain)
            Text("말하기").font(.system(size: 13)).foregroundStyle(AppColor.textMuted)
            Spacer()
          }
        }
        .padding(16)
        .appCard(radius: 16)

        if showMicHint {
          Text("음성 입력은 곧 지원돼요. 지금은 텍스트로 추가할 수 있어요.")
            .font(.system(size: 13)).foregroundStyle(AppColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text("AI가 물건·장소·분류를 자동으로 채우는 기능은 곧 추가돼요. 지금은 이름만 빠르게 담깁니다.")
          .font(.system(size: 12.5)).foregroundStyle(AppColor.textMuted)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer()

        Button(action: add) {
          Text("추가")
            .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(canAdd ? AppColor.accent : AppColor.textMuted,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
      }
      .padding(20)
      .background(AppColor.screenBackground)
      .navigationTitle("추가")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } }
      }
      .onAppear { focused = true }
    }
  }

  private var canAdd: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func add() {
    let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }
    modelContext.insert(Item(name: name))
    dismiss()
  }
}
