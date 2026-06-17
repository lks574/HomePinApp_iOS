import PhotosUI
import SwiftUI

/// screen-12 — 레시피 자연어 추가 입력 화면. 중앙 ✨ 시트(`CaptureSheet`)의 "Add recipe"
/// 액션이 띄우는 레시피 전용 입력 공간이다.
///
/// 물건 빠른 추가(한 단어)와 달리 레시피는 재료+단계가 긴 텍스트라 별도 입력 공간을 둔다.
/// **여러 줄 텍스트 입력 = 타이핑 + 붙여넣기 + 음성 + 사진/스크린샷 OCR** 넷이 같은 단일
/// 입력으로 합류한다(단일 경로 원칙). 사진/카메라(screen-13)는 온디바이스 Vision OCR
/// (`RecipeOCRViewModel`)로 텍스트를 뽑아 입력 필드에 채울 뿐, 그다음 "Sort with AI" →
/// 파싱 → 확인 경로는 텍스트 입력과 똑같이 합류한다(자동 파싱·자동 저장 안 함 — OCR 은
/// 부정확할 수 있어 사용자가 보고 고친다). "Sort with AI" 를 눌러야만 파싱이 시작된다
/// (명시적 추가 — 의도 자동 추측 없음). 파싱이 가용·성공이면 prefill 된 확인 에디터
/// (`RecipeEditorView`)를 시트로 띄우고, 미가용·실패·취소·빈 결과면 수동 에디터로 폴백한다.
struct RecipeCaptureView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  @State private var dictation = SpeechDictationViewModel()
  @State private var parser = NLRecipeParseViewModel()
  @State private var ocr = RecipeOCRViewModel()
  @State private var photoItem: PhotosPickerItem?
  @State private var showingCamera = false
  @State private var showingPhotoLibrary = false
  @State private var confirmRoute: RecipeConfirmRoute?
  @FocusState private var inputFocused: Bool

  /// 카메라 사용 가능 여부(시뮬레이터는 미지원이라 사진 라이브러리만 노출).
  private var cameraAvailable: Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera)
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 14) {
        prompt
        editor
        photoSourceRow
        if let captureHint {
          captureHint
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
      .fullScreenCover(isPresented: $showingCamera) {
        CameraImagePicker { image in ocr.recognize(image) }
          .ignoresSafeArea()
      }
      .photosPicker(isPresented: $showingPhotoLibrary, selection: $photoItem, matching: .images)
      .onAppear { inputFocused = true }
      .onChange(of: dictation.transcript) { _, newTranscript in
        applyTranscript(newTranscript)
      }
      .onChange(of: parser.state) { _, newState in
        applyParseState(newState)
      }
      .onChange(of: photoItem) { _, newItem in
        loadPickedPhoto(newItem)
      }
      .onChange(of: ocr.recognizedText) { _, newText in
        applyRecognizedText(newText)
      }
      .onDisappear {
        dictation.reset()
        parser.reset()
        ocr.reset()
      }
    }
  }

  /// 수동 에디터 폴백 라우트(미가용·실패·취소). 확인 라우트와 동일하게 시트로 띄운다.
  @State private var manualRoute: ManualRoute?

  // MARK: - 입력

  private var prompt: some View {
    Text("Type, paste, speak, or scan a recipe. AI sorts the title, ingredients, and steps for you to confirm.")
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

  /// 사진/카메라 OCR 진입. 카메라(즉석 촬영)와 사진 라이브러리(스크린샷·기존 사진) 둘 다 제공한다.
  /// 카메라는 시뮬레이터 미지원이라 가용할 때만 노출하고, 사진 라이브러리는 항상 노출한다.
  /// 텍스트 입력은 항상 살아 있으므로 OCR 권한 거부·실패여도 폴백된다.
  @ViewBuilder
  private var photoSourceRow: some View {
    if ocr.isRecognizing {
      HStack(spacing: 10) {
        ProgressView()
        Text("Reading text from the image…")
          .font(.appFootnote).foregroundStyle(AppColor.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      HStack(spacing: 10) {
        if cameraAvailable {
          photoSourceButton(title: "Scan", systemImage: "camera") { showingCamera = true }
        }
        photoSourceButton(title: "Photo", systemImage: "photo.on.rectangle") { showingPhotoLibrary = true }
        Spacer(minLength: 0)
      }
    }
  }

  private func photoSourceButton(
    title: LocalizedStringKey,
    systemImage: String,
    action: @escaping () -> Void,
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: systemImage).font(.appFootnote)
        Text(title).font(.appFootnote)
      }
      .foregroundStyle(AppColor.accent)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .appCard(radius: 12)
    }
    .buttonStyle(.plain)
    .disabled(parser.isParsing)
  }

  /// 받아쓰기·OCR 상태별 안내. 정상 대기에서는 숨긴다. dictation `reason` 은 엔진이 현지화한 문구.
  private var captureHint: Text? {
    switch ocr.state {
    case .failed:
      return Text("Couldn't read text from the image. Try another photo or type instead.")
    case .empty:
      return Text("No text found in the image. Try a clearer photo or type instead.")
    case .idle, .recognizing, .recognized:
      break
    }
    return micHint
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

  // MARK: - 사진/카메라 OCR

  /// 사진 라이브러리에서 고른 항목을 `UIImage` 로 불러와 OCR 에 넘긴다. 로딩 실패는 OCR 실패와
  /// 같은 안내로 떨어뜨린다(텍스트 입력 폴백 유지).
  private func loadPickedPhoto(_ item: PhotosPickerItem?) {
    guard let item else { return }
    Task {
      guard
        let data = try? await item.loadTransferable(type: Data.self),
        let image = PlatformImage.from(data: data)
      else {
        photoItem = nil
        return
      }
      ocr.recognize(image)
      photoItem = nil
    }
  }

  /// OCR 로 인식한 텍스트를 입력 필드에 채운다(자동 파싱 안 함 — 사용자가 보고 고친 뒤 "Sort with AI").
  /// 기존 입력이 있으면 개행으로 이어 붙이고(append), 비어 있으면 그대로 채운다. 전달 채널은 비운다.
  private func applyRecognizedText(_ recognized: String) {
    guard !recognized.isEmpty else { return }
    if trimmed.isEmpty {
      text = recognized
    } else {
      text += "\n" + recognized
    }
    ocr.clearRecognizedText()
    inputFocused = true
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
