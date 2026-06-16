import SwiftData
import SwiftUI

/// 중앙 버튼이 띄우는 시트 — [추가 | 검색] 두 모드 + 공용 음성 입력.
/// - 추가: 입력 텍스트(타이핑·받아쓰기 공용)를 가용 시 온디바이스 AI 파서(`NLParseViewModel`)로
///   구조화 드래프트로 바꿔 확인 화면(screen-09)으로 push 하고, 미가용·실패·취소·빈 결과면
///   현 단건 스텁(이름 prefill 로 `ItemEditor` `create`)으로 폴백한다. 텍스트 경로는 항상 산다.
/// - 검색: `Item.normalizedName` 기반 이름 검색 → 결과에 위치 경로. 결과를 누르면
///   해당 물건 편집 시트로 진입한다. (자연어 검색은 후속)
/// - 음성(🎤): 모드 토글 아래 공용. 받아쓰기(`SpeechDictationViewModel`) 결과는 활성 모드의 입력
///   필드(추가=`text`, 검색=`searchText`)로 들어간 뒤, 추가 모드에선 텍스트와 같은 `add()`
///   파서 경로로 합류한다. STT 는 텍스트를 채우는 입력기일 뿐 텍스트 경로는 항상 살아 있다.
struct CaptureSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var mode: CaptureMode = .add
  @State private var text = ""
  @State private var searchText = ""
  @State private var dictation = SpeechDictationViewModel()
  @State private var parser = NLParseViewModel()
  @State private var editorRoute: ItemEditorRoute?
  @State private var reviewRoute: DraftReviewRoute?
  @FocusState private var focusedField: CaptureField?

  /// 검색 대상 전체 물건. 이름순으로 받아 정규화 키로 in-memory 필터한다(개인 재고
  /// 규모에선 충분). 동적 술어 대신 단일 `@Query` + 필터.
  @Query(sort: \Item.name) private var allItems: [Item]

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        modePicker
        micRow
        if let micHint {
          micHint
            .font(.appFootnote).foregroundStyle(AppColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        switch mode {
        case .add: addContent
        case .search: searchContent
        }
      }
      .padding(20)
      .background(AppColor.screenBackground)
      .navigationTitle(mode == .add ? Text("Add") : Text("Search"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
      }
      .navigationDestination(item: $reviewRoute) { route in
        CaptureDraftReviewView(drafts: route.drafts) { dismiss() }
      }
      .sheet(item: $editorRoute) { route in
        ItemEditorView(mode: route.mode) {
          dismiss()
        }
      }
      .onAppear { focusedField = mode == .add ? .add : .search }
      .onChange(of: mode) { _, newMode in
        dictation.reset()
        parser.reset()
        focusedField = newMode == .add ? .add : .search
      }
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

  // MARK: - 모드 토글

  private var modePicker: some View {
    Picker("Mode", selection: $mode) {
      ForEach(CaptureMode.allCases) { mode in
        Text(mode.title).tag(mode)
      }
    }
    .pickerStyle(.segmented)
  }

  // MARK: - 공용 음성 입력

  /// 모드 공용 음성 진입. 받아쓰기 결과는 활성 모드의 입력 필드로 들어간다.
  private var micRow: some View {
    let isRecording = dictation.state == .recording
    return HStack(spacing: 12) {
      Button { Task { await dictation.toggle() } } label: {
        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
          .background(isRecording ? AppColor.accentDark : AppColor.accent, in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(micAccessibilityLabel)
      VStack(alignment: .leading, spacing: 2) {
        Text(isRecording ? "Listening…" : "Speak")
          .font(.appRowLabel).foregroundStyle(AppColor.textSecondary)
        Text(micSubtitle)
          .font(.appCaption).foregroundStyle(AppColor.textMuted)
      }
      Spacer()
    }
    .padding(14)
    .appCard(radius: 16)
  }

  private var micAccessibilityLabel: LocalizedStringKey {
    if dictation.state == .recording { return "Stop dictation" }
    return mode == .add ? "Speak to add" : "Speak to search"
  }

  private var micSubtitle: LocalizedStringKey {
    if dictation.state == .recording { return "Tap again to stop" }
    return mode == .add ? "Speak to add it" : "Speak to search"
  }

  // MARK: - 추가

  private var addContent: some View {
    VStack(spacing: 18) {
      Text("Add by speaking or typing")
        .font(.appRowLabel)
        .foregroundStyle(AppColor.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)

      TextField("e.g. Put two packs of beef in the freezer", text: $text, axis: .vertical)
        .font(.appFieldText)
        .lineLimit(2...5)
        .focused($focusedField, equals: .add)
        .padding(16)
        .appCard(radius: 16)
        .disabled(parser.isParsing)

      Text(addHint)
        .font(.appCaption).foregroundStyle(AppColor.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)

      Spacer()

      if parser.isParsing {
        parsingIndicator
      } else {
        AppFullWidthPrimaryButton(title: "Add", isEnabled: canAdd, action: add)
      }
    }
  }

  /// 파서 가용 여부에 따른 안내. 미가용이면 단건(이름만) 폴백을 알린다.
  private var addHint: LocalizedStringKey {
    parser.isAvailable
      ? "Speak or type and AI sorts out the item, place, quantity, and category for you to confirm. Multiple items at once, too."
      : "AI sorting isn't available on this device, so only the name is captured quickly. Fill in the place and quantity on the next screen."
  }

  /// 추론 중 진행 표시 + 취소. 추론이 끝나면 확인 화면으로 넘어가거나 폴백한다.
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
    .appCard(radius: 14)
  }

  // MARK: - 검색

  private var searchContent: some View {
    VStack(spacing: 14) {
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass").foregroundStyle(AppColor.textTertiary)
        TextField("Find by item name", text: $searchText)
          .font(.appFieldText)
          .focused($focusedField, equals: .search)
          .submitLabel(.search)
        if !searchText.isEmpty {
          Button { searchText = "" } label: {
            Image(systemName: "xmark.circle.fill").foregroundStyle(AppColor.textFaint)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 14)
      .frame(height: 48)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColor.fieldBackground)
      )

      searchResults
    }
  }

  @ViewBuilder
  private var searchResults: some View {
    if searchQuery.isEmpty {
      Spacer()
      Text("Type an item name and we'll find where it is.")
        .font(.appFootnote).foregroundStyle(AppColor.textMuted)
      Spacer()
    } else if results.isEmpty {
      Spacer()
      Text("search.noResults.\(searchQuery)")
        .font(.appFootnote).foregroundStyle(AppColor.textMuted)
      Spacer()
    } else {
      ScrollView {
        VStack(spacing: 0) {
          ForEach(results) { item in
            resultRow(item)
          }
        }
        .appCard()
      }
    }
  }

  private func resultRow(_ item: Item) -> some View {
    Button {
      editorRoute = ItemEditorRoute(mode: .edit(item))
    } label: {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Text(verbatim: item.name).font(.appItemBody).foregroundStyle(AppColor.textPrimary)
          if !item.locationPath.isEmpty {
            Text(verbatim: item.locationPath).font(.appCaption).foregroundStyle(AppColor.textMuted)
          } else {
            Text("No location").font(.appCaption).foregroundStyle(AppColor.textFaint)
          }
        }
        Spacer()
        if item.quantity > 1 {
          Text("count.items.\(item.quantity)").font(.appCaptionStrong).foregroundStyle(AppColor.textMuted)
        }
        Image(systemName: "chevron.right").font(.appTag).foregroundStyle(AppColor.textFaint)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .overlay(alignment: .top) { Divider().padding(.leading, 16) }
    }
    .buttonStyle(.plain)
  }

  // MARK: - 음성 입력

  /// 받아쓰기 상태별 안내. 정상 대기 상태에서는 힌트를 숨긴다(텍스트 필드는 항상 노출).
  /// `reason` 은 엔진이 이미 현지화한 문구라 그대로 끼워 넣는다.
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

  /// 받아쓰기 텍스트를 활성 모드 필드에 채운다. 검색은 단일 라인이라 개행을 제거한다.
  private func applyTranscript(_ transcript: String) {
    guard !transcript.isEmpty else { return }
    switch mode {
    case .add:
      text = transcript
    case .search:
      searchText = transcript.replacingOccurrences(of: "\n", with: " ")
    }
  }

  // MARK: - 로직

  private var canAdd: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !parser.isParsing
  }

  /// 추가 진입. 파서 가용 시 자연어 파싱(→ 확인 화면 push), 미가용·실패·취소·빈 결과면
  /// 현 단건 스텁(이름 prefill)으로 폴백한다. 분기는 `parser.state` 변화를 받아 처리한다.
  private func add() {
    let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }
    guard parser.isAvailable else {
      fallbackToStub(name)
      return
    }
    focusedField = nil
    parser.parse(name, in: modelContext)
  }

  /// 파서 상태에 따라 분기한다. 성공이면 확인 화면 push, 실패·미가용이면 단건 스텁 폴백.
  private func applyParseState(_ state: NLParseViewModel.State) {
    switch state {
    case let .drafts(drafts):
      reviewRoute = DraftReviewRoute(drafts: drafts)
      parser.reset()
    case .unavailable, .failed:
      fallbackToStub(text.trimmingCharacters(in: .whitespacesAndNewlines))
      parser.reset()
    case .idle, .parsing:
      break
    }
  }

  /// 현 단건 스텁: 이름만 prefill 한 `ItemEditor` create 로 넘긴다(텍스트 경로 보장).
  private func fallbackToStub(_ name: String) {
    guard !name.isEmpty else { return }
    editorRoute = ItemEditorRoute(mode: .create(initialName: name))
  }

  /// 정규화한 검색어(빈 문자열이면 무검색).
  private var searchQuery: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// 정규화 키로 부분 일치한 물건(이름순, `@Query` 정렬 유지).
  private var results: [Item] {
    let key = Item.normalize(searchQuery)
    guard !key.isEmpty else { return [] }
    return allItems.filter { $0.normalizedName.contains(key) }
  }
}

/// 확인 드래프트 화면(screen-09) push 라우트. `navigationDestination(item:)` 요건
/// (`Hashable`)을 위해 안정 id 로 동등성을 정의한다(드래프트 자체는 참조 타입).
private struct DraftReviewRoute: Identifiable, Hashable {
  let id = UUID()
  let drafts: [AddDraft]

  static func == (lhs: DraftReviewRoute, rhs: DraftReviewRoute) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

private enum CaptureMode: String, CaseIterable, Identifiable {
  case add
  case search

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .add: "Add"
    case .search: "Search"
    }
  }
}

private enum CaptureField: Hashable {
  case add
  case search
}
