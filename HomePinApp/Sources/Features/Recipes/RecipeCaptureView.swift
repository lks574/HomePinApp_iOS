import SwiftUI

/// screen-12 — 레시피 자연어 추가 입력 화면. 중앙 ✨ 시트(`CaptureSheet`)의 "Add recipe"
/// 액션이 띄우는 레시피 전용 입력 공간이다.
///
/// 물건 빠른 추가(한 단어)와 달리 레시피는 재료+단계가 긴 텍스트라 별도 입력 공간을 둔다.
/// **여러 줄 텍스트 입력 = 타이핑 + 붙여넣기 + 음성** 셋이 같은 단일 입력으로 합류한다
/// (단일 경로 원칙). "Sort with AI" 를 눌러야만 파싱이 시작된다(명시적 추가 — 의도 자동
/// 추측 없음). 파싱이 가용·성공이면 prefill 된 확인 에디터(`RecipeEditorView`)를 시트로 띄우고,
/// 미가용·실패·취소·빈 결과면 수동 에디터(제목만 prefill 가능)로 폴백한다.
struct RecipeCaptureView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  @State private var dictation = SpeechDictationViewModel()
  @State private var parser = NLRecipeParseViewModel()
  @State private var confirmRoute: RecipeConfirmRoute?
  @FocusState private var inputFocused: Bool

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 14) {
        prompt
        editor
        if let micHint {
          micHint
            .font(.appFootnote).foregroundStyle(AppColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Spacer(minLength: 0)
        actionRow
      }
      .padding(20)
      .background(AppColor.screenBackground)
      .navigationTitle(Text("Add a recipe"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
      }
      .sheet(item: $confirmRoute) { route in
        RecipeEditorView(prefill: route.prefill) { dismiss() }
      }
      .sheet(item: $manualRoute) { _ in
        RecipeEditorView(mode: .create) { dismiss() }
      }
      .onAppear { inputFocused = true }
      .onChange(of: dictation.transcript) { _, newTranscript in
        applyTranscript(newTranscript)
      }
      .onChange(of: parser.state) { _, newState in
        applyParseState(newState)
      }
      .onDisappear {
        dictation.reset()
        parser.reset()
      }
    }
  }

  /// 수동 에디터 폴백 라우트(미가용·실패·취소). 확인 라우트와 동일하게 시트로 띄운다.
  @State private var manualRoute: ManualRoute?

  // MARK: - 입력

  private var prompt: some View {
    Text("Type, paste, or speak a recipe. AI sorts the title, ingredients, and steps for you to confirm.")
      .font(.appFootnote)
      .foregroundStyle(AppColor.textMuted)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// 여러 줄 입력 + 음성 토글. 받아쓰기 결과·붙여넣기·타이핑이 모두 같은 `text` 로 들어간다.
  private var editor: some View {
    let isRecording = dictation.state == .recording
    return VStack(alignment: .leading, spacing: 0) {
      TextEditor(text: $text)
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 180)
        .focused($inputFocused)
        .disabled(parser.isParsing)
      Divider()
      HStack(spacing: 12) {
        Button { Task { await dictation.toggle() } } label: {
          Image(systemName: isRecording ? "stop.fill" : "mic.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(isRecording ? AppColor.accentDark : AppColor.accent, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(micAccessibilityLabel)
        Spacer()
        if !text.isEmpty {
          Button { text = "" } label: {
            Text("Clear").font(.appFootnote).foregroundStyle(AppColor.textMuted)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.top, 10)
    }
    .padding(14)
    .appCard(radius: 18)
  }

  private var micAccessibilityLabel: LocalizedStringKey {
    dictation.state == .recording ? "Stop dictation" : "Speak the recipe"
  }

  /// 받아쓰기 상태별 안내. 정상 대기에서는 숨긴다. `reason` 은 엔진이 현지화한 문구.
  private var micHint: Text? {
    switch dictation.state {
    case .denied:
      Text("Microphone or speech recognition permission is off. Allow it in Settings or type instead.")
    case let .unavailable(reason):
      Text("dictation.unavailableHint.\(reason)")
    case .idle, .preparing, .recording:
      nil
    }
  }

  // MARK: - 액션

  @ViewBuilder
  private var actionRow: some View {
    if parser.isParsing {
      parsingIndicator
    } else {
      Button(action: sort) {
        HStack(spacing: 8) {
          Image(systemName: "sparkles").font(.appItemBody)
          Text("Sort with AI").font(.appRowLabel)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(canSort ? AppColor.accent : AppColor.textFaint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(!canSort)
    }
  }

  private var parsingIndicator: some View {
    HStack(spacing: 12) {
      ProgressView()
      Text("Sorting…").font(.appRowLabel).foregroundStyle(AppColor.textSecondary)
      Spacer()
      Button("Cancel") { parser.cancel() }
        .font(.appRowLabel)
        .foregroundStyle(AppColor.accent)
    }
    .padding(.horizontal, 16)
    .frame(height: 52)
    .frame(maxWidth: .infinity)
    .appCard(radius: 16)
  }

  private var trimmed: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSort: Bool {
    !trimmed.isEmpty
  }

  /// 받아쓰기 텍스트를 입력에 채운다. 여러 줄 입력이라 개행을 보존한다.
  private func applyTranscript(_ transcript: String) {
    guard !transcript.isEmpty else { return }
    text = transcript
  }

  /// 명시적 파싱 진입. 가용 시 AI 파싱(→ 확인 시트 제시), 미가용이면 수동 에디터 폴백.
  private func sort() {
    guard canSort else { return }
    guard parser.isAvailable else {
      manualRoute = ManualRoute()
      return
    }
    inputFocused = false
    parser.parse(trimmed)
  }

  /// 파서 상태에 따라 분기한다. 성공이면 확인 시트 제시, 실패·미가용이면 수동 에디터 폴백.
  private func applyParseState(_ state: NLRecipeParseViewModel.State) {
    switch state {
    case let .prefill(prefill):
      confirmRoute = RecipeConfirmRoute(prefill: prefill)
      parser.reset()
    case .unavailable, .failed:
      manualRoute = ManualRoute()
      parser.reset()
    case .idle, .parsing:
      break
    }
  }
}

/// prefill 확인 에디터 시트 라우트.
private struct RecipeConfirmRoute: Identifiable {
  let id = UUID()
  let prefill: RecipeEditorPrefill
}

/// 수동 에디터 폴백 시트 라우트.
private struct ManualRoute: Identifiable {
  let id = UUID()
}
