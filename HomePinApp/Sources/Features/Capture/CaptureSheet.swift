import SwiftData
import SwiftUI

/// 중앙 버튼이 띄우는 시트 — 검색-우선 통합 입력 + 공용 음성 입력.
/// - 단일 입력 필드 하나로 통합한다([추가|검색] 모드 토글 없음). 입력하면(타이핑·받아쓰기)
///   기존 항목을 실시간 검색해 물건/레시피 섹션으로 보여준다.
/// - 결과 아래 항상 `+ "{입력어}" 추가하기` 행을 둔다. 이 행을 눌러야만 명시적 추가가
///   일어난다(AI 가 추가/검색 의도를 자동 추측하지 않음 — 오분류 데이터 오염 방지).
/// - 추가는 가용 시 온디바이스 AI 파서(`NLParseViewModel`)로 구조화 드래프트로 바꿔
///   확인 화면(screen-09)으로 push 하고, 미가용·실패·취소·빈 결과면 현 단건 스텁(이름
///   prefill 로 `ItemEditor` `create`)으로 폴백한다. 텍스트·음성 모두 같은 `add()` 경로.
/// - 음성(🎤): 받아쓰기(`SpeechDictationViewModel`) 결과가 같은 입력 필드로 들어가고,
///   `추가하기` 를 누르면 동일한 파서 경로로 합류한다(단일 경로 원칙).
struct CaptureSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(AppRouter.self) private var router
  @State private var query = ""
  @State private var dictation = SpeechDictationViewModel()
  @State private var parser = NLParseViewModel()
  @State private var editorRoute: ItemEditorRoute?
  @State private var reviewRoute: DraftReviewRoute?
  @FocusState private var inputFocused: Bool

  /// 검색 대상 전체 물건. 이름순으로 받아 정규화 키로 in-memory 필터한다(개인 재고
  /// 규모에선 충분). 동적 술어 대신 단일 `@Query` + 필터.
  @Query(sort: \Item.name) private var allItems: [Item]

  /// 검색 대상 전체 레시피. 제목·재료명을 정규화 키로 in-memory 필터한다.
  @Query(sort: \Recipe.title) private var allRecipes: [Recipe]

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        inputRow
        if let micHint {
          micHint
            .font(.appFootnote).foregroundStyle(AppColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        content
      }
      .padding(20)
      .background(AppColor.screenBackground)
      .navigationTitle(Text("Add or find"))
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

  // MARK: - 입력 (음성 + 단일 필드)

  /// 공용 음성 진입 + 단일 입력 필드. 받아쓰기 결과·타이핑 모두 같은 `query` 로 들어간다.
  private var inputRow: some View {
    let isRecording = dictation.state == .recording
    return HStack(spacing: 10) {
      Button { Task { await dictation.toggle() } } label: {
        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 40, height: 40)
          .background(isRecording ? AppColor.accentDark : AppColor.accent, in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(micAccessibilityLabel)
      Image(systemName: "sparkles").foregroundStyle(AppColor.accent)
      TextField("Type anything", text: $query)
        .font(.appFieldText)
        .focused($inputFocused)
        .submitLabel(.search)
        .disabled(parser.isParsing)
      if !query.isEmpty {
        Button { query = "" } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(AppColor.textFaint)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColor.fieldBackground)
    )
  }

  private var micAccessibilityLabel: LocalizedStringKey {
    dictation.state == .recording ? "Stop dictation" : "Speak to fill the field"
  }

  // MARK: - 본문 (빈 상태 / 결과 + 추가 행)

  @ViewBuilder
  private var content: some View {
    if trimmedQuery.isEmpty {
      Spacer()
      Text("Find or add items and recipes by typing or speaking.")
        .font(.appFootnote).foregroundStyle(AppColor.textMuted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
      Spacer()
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if !itemResults.isEmpty {
            resultSection(title: "Items") {
              ForEach(itemResults) { item in
                itemResultRow(item)
              }
            }
          }
          if !recipeResults.isEmpty {
            resultSection(title: "Recipes") {
              ForEach(recipeResults) { recipe in
                recipeResultRow(recipe)
              }
            }
          }
          addSection
        }
      }
    }
  }

  /// 명시적 추가 행. 결과 유무와 무관하게 항상 노출한다. 파서 추론 중에는 진행 표시로 바꾼다.
  @ViewBuilder
  private var addSection: some View {
    if parser.isParsing {
      parsingIndicator
    } else {
      Button(action: add) {
        HStack(spacing: 10) {
          Image(systemName: "plus.circle.fill")
            .font(.appItemBody).foregroundStyle(AppColor.accent)
          Text("add.create.\(trimmedQuery)")
            .font(.appItemBody).foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
          Image(systemName: "chevron.right").font(.appTag).foregroundStyle(AppColor.textFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .appCard()
      }
      .buttonStyle(.plain)
    }
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

  // MARK: - 결과 섹션

  private func resultSection(
    title: LocalizedStringKey,
    @ViewBuilder rows: () -> some View
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.appSectionLabel).foregroundStyle(AppColor.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
      VStack(spacing: 0) { rows() }.appCard()
    }
  }

  private func itemResultRow(_ item: Item) -> some View {
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

  /// 레시피 결과 행 — 누르면 시트를 닫고 레시피 탭 상세로 push 한다.
  private func recipeResultRow(_ recipe: Recipe) -> some View {
    Button {
      dismiss()
      router.openRecipe(recipe)
    } label: {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Text(verbatim: recipe.title).font(.appItemBody).foregroundStyle(AppColor.textPrimary)
          Text("recipe.ingredientCount.\(recipe.inStockCount).\(recipe.ingredients.count)")
            .font(.appCaption).foregroundStyle(AppColor.textMuted)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.appTag).foregroundStyle(AppColor.textFaint)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .overlay(alignment: .top) { Divider().padding(.leading, 16) }
    }
    .buttonStyle(.plain)
  }

  // MARK: - 음성 입력

  /// 받아쓰기 상태별 안내. 정상 대기 상태에서는 힌트를 숨긴다(입력 필드는 항상 노출).
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

  /// 받아쓰기 텍스트를 단일 입력 필드에 채운다. 단일 라인이라 개행을 공백으로 바꾼다.
  private func applyTranscript(_ transcript: String) {
    guard !transcript.isEmpty else { return }
    query = transcript.replacingOccurrences(of: "\n", with: " ")
  }

  // MARK: - 추가 로직

  /// 명시적 추가 진입. 파서 가용 시 자연어 파싱(→ 확인 화면 push), 미가용·실패·취소·빈
  /// 결과면 현 단건 스텁(이름 prefill)으로 폴백한다. 분기는 `parser.state` 변화를 받아 처리.
  private func add() {
    let name = trimmedQuery
    guard !name.isEmpty else { return }
    guard parser.isAvailable else {
      fallbackToStub(name)
      return
    }
    inputFocused = false
    parser.parse(name, in: modelContext)
  }

  /// 파서 상태에 따라 분기한다. 성공이면 확인 화면 push, 실패·미가용이면 단건 스텁 폴백.
  private func applyParseState(_ state: NLParseViewModel.State) {
    switch state {
    case let .drafts(drafts):
      reviewRoute = DraftReviewRoute(drafts: drafts)
      parser.reset()
    case .unavailable, .failed:
      fallbackToStub(trimmedQuery)
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

  // MARK: - 검색 로직

  /// 정규화한 입력어(앞뒤 공백 제거).
  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// 정규화 키로 부분 일치한 물건(이름순, `@Query` 정렬 유지).
  private var itemResults: [Item] {
    let key = Item.normalize(trimmedQuery)
    guard !key.isEmpty else { return [] }
    return allItems.filter { $0.normalizedName.contains(key) }
  }

  /// 제목 또는 재료명이 부분 일치한 레시피(제목순, `@Query` 정렬 유지).
  private var recipeResults: [Recipe] {
    let key = Item.normalize(trimmedQuery)
    guard !key.isEmpty else { return [] }
    return allRecipes.filter { recipe in
      Item.normalize(recipe.title).contains(key)
        || recipe.ingredients.contains { Item.normalize($0.name).contains(key) }
    }
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
