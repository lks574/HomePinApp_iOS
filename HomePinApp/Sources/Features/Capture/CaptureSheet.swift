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
          Text(micHint)
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
      .navigationTitle(mode == .add ? "추가" : "검색")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } }
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
    Picker("모드", selection: $mode) {
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
      .accessibilityLabel(isRecording ? "받아쓰기 멈추기" : (mode == .add ? "말해서 추가" : "말해서 검색"))
      VStack(alignment: .leading, spacing: 2) {
        Text(isRecording ? "듣는 중…" : "말하기")
          .font(.appRowLabel).foregroundStyle(AppColor.textSecondary)
        Text(micSubtitle)
          .font(.appCaption).foregroundStyle(AppColor.textMuted)
      }
      Spacer()
    }
    .padding(14)
    .appCard(radius: 16)
  }

  private var micSubtitle: String {
    if dictation.state == .recording { return "다시 누르면 멈춰요" }
    return mode == .add ? "말하면 추가돼요" : "말하면 검색해요"
  }

  // MARK: - 추가

  private var addContent: some View {
    VStack(spacing: 18) {
      Text("말하거나 입력해서 추가")
        .font(.appRowLabel)
        .foregroundStyle(AppColor.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)

      TextField("예: 냉동실에 소고기 두 팩 넣었어", text: $text, axis: .vertical)
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
        AppFullWidthPrimaryButton(title: "추가", isEnabled: canAdd, action: add)
      }
    }
  }

  /// 파서 가용 여부에 따른 안내. 미가용이면 단건(이름만) 폴백을 알린다.
  private var addHint: String {
    parser.isAvailable
      ? "말하거나 적으면 AI가 물건·장소·수량·분류를 정리해 확인 화면을 보여줘요. 여러 개도 한 번에 돼요."
      : "이 기기에서는 AI 정리를 쓸 수 없어 이름만 빠르게 담겨요. 위치·수량은 다음 화면에서 채우세요."
  }

  /// 추론 중 진행 표시 + 취소. 추론이 끝나면 확인 화면으로 넘어가거나 폴백한다.
  private var parsingIndicator: some View {
    HStack(spacing: 12) {
      ProgressView()
      Text("정리하는 중…").font(.appRowLabel).foregroundStyle(AppColor.textSecondary)
      Spacer()
      Button("취소") { parser.cancel() }
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
        TextField("물건 이름으로 찾기", text: $searchText)
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
      Text("물건 이름을 입력하면 위치를 찾아드려요.")
        .font(.appFootnote).foregroundStyle(AppColor.textMuted)
      Spacer()
    } else if results.isEmpty {
      Spacer()
      Text("‘\(searchQuery)’ 와 일치하는 물건이 없어요.")
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
          Text(item.name).font(.appItemBody).foregroundStyle(AppColor.textPrimary)
          if !item.locationPath.isEmpty {
            Text(item.locationPath).font(.appCaption).foregroundStyle(AppColor.textMuted)
          } else {
            Text("위치 미지정").font(.appCaption).foregroundStyle(AppColor.textFaint)
          }
        }
        Spacer()
        if item.quantity > 1 {
          Text("\(item.quantity)개").font(.appCaptionStrong).foregroundStyle(AppColor.textMuted)
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
  private var micHint: String? {
    switch dictation.state {
    case .denied:
      "마이크·음성 인식 권한이 꺼져 있어요. 설정에서 허용하거나 텍스트로 입력해 주세요."
    case let .unavailable(reason):
      "\(reason) 텍스트로 입력해 주세요."
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

  var title: String {
    switch self {
    case .add: "추가"
    case .search: "검색"
    }
  }
}

private enum CaptureField: Hashable {
  case add
  case search
}
