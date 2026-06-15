import SwiftData
import SwiftUI

/// 중앙 버튼이 띄우는 시트 — [추가 | 검색] 두 모드 + 공용 음성 입력.
/// - 추가: 텍스트를 이름 draft 로 넘겨 사용자가 위치/수량을 확인한 뒤 저장한다.
/// - 검색: `Item.normalizedName` 기반 이름 검색 → 결과에 위치 경로. 결과를 누르면
///   해당 물건 편집 시트로 진입한다. (자연어 검색은 후속)
/// - 음성(🎤): 모드 토글 아래 공용. 받아쓰기(`SpeechDictationViewModel`) 결과는 활성 모드의 입력
///   필드(추가=`text`, 검색=`searchText`)로 들어간다. STT 는 텍스트를 채우는 입력기일 뿐
///   텍스트 입력 경로는 항상 살아 있어 불가용·거부 시 폴백된다. (AI 파서는 후속)
struct CaptureSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var mode: CaptureMode = .add
  @State private var text = ""
  @State private var searchText = ""
  @State private var dictation = SpeechDictationViewModel()
  @State private var editorRoute: ItemEditorRoute?
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
      .sheet(item: $editorRoute) { route in
        ItemEditorView(mode: route.mode) {
          dismiss()
        }
      }
      .onAppear { focusedField = mode == .add ? .add : .search }
      .onChange(of: mode) { _, newMode in
        dictation.reset()
        focusedField = newMode == .add ? .add : .search
      }
      .onChange(of: dictation.transcript) { _, newTranscript in
        applyTranscript(newTranscript)
      }
      .onDisappear { dictation.reset() }
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

      Text("AI가 물건·장소·분류를 자동으로 채우는 기능은 곧 추가돼요. 지금은 이름만 빠르게 담깁니다.")
        .font(.appCaption).foregroundStyle(AppColor.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)

      Spacer()

      AppFullWidthPrimaryButton(title: "추가", isEnabled: canAdd, action: add)
    }
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
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func add() {
    let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
