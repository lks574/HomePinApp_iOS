import SwiftUI

/// NL 추가 입력 시트 — 텍스트 + 음성 진입(2-입력). UI 우선이라 STT/AI 파싱은 후속.
/// 지금은 텍스트를 이름 draft 로 넘겨 사용자가 위치/수량을 확인한 뒤 저장한다.
struct CaptureSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  @State private var showMicHint = false
  @State private var editorRoute: ItemEditorRoute?
  @FocusState private var focused: Bool

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        Text("말하거나 입력해서 추가")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(spacing: 12) {
          TextField("예: 냉동실에 소고기 두 팩 넣었어", text: $text, axis: .vertical)
            .font(.appFieldText)
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
            Text("말하기").font(.appFootnote).foregroundStyle(AppColor.textMuted)
            Spacer()
          }
        }
        .padding(16)
        .appCard(radius: 16)

        if showMicHint {
          Text("음성 입력은 곧 지원돼요. 지금은 텍스트로 추가할 수 있어요.")
            .font(.appFootnote).foregroundStyle(AppColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text("AI가 물건·장소·분류를 자동으로 채우는 기능은 곧 추가돼요. 지금은 이름만 빠르게 담깁니다.")
          .font(.appCaption).foregroundStyle(AppColor.textMuted)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer()

        AppFullWidthPrimaryButton(title: "추가", isEnabled: canAdd, action: add)
      }
      .padding(20)
      .background(AppColor.screenBackground)
      .navigationTitle("추가")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } }
      }
      .sheet(item: $editorRoute) { route in
        ItemEditorView(mode: route.mode) {
          dismiss()
        }
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
    editorRoute = ItemEditorRoute(mode: .create(initialName: name))
  }
}
