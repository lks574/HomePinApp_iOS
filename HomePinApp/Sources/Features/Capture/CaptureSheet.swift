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
  @State private var showingRecipeCapture = false
  @AppStorage(RecentSearches.storageKey) private var recentSearchesJSON = "[]"
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
      .sheet(isPresented: $showingRecipeCapture) {
        RecipeCaptureView()
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
      emptyStateContent
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
          addRecipeRow
        }
      }
    }
  }

  /// 빈 입력 상태. 최근 검색어·임박 물건 추천 칩을 보여준다(있을 때만). 칩 탭은
  /// 입력 필드만 채우고 검색/추가를 자동 실행하지 않는다(명시적 추가 원칙 유지).
  @ViewBuilder
  private var emptyStateContent: some View {
    let recents = RecentSearches.decode(recentSearchesJSON)
    let expiring = Array(allItems.expiringSoonByExpiry.prefix(6))
    if recents.isEmpty, expiring.isEmpty {
      Spacer()
      Text("Find or add items and recipes by typing or speaking.")
        .font(.appFootnote).foregroundStyle(AppColor.textMuted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
      Spacer()
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if !recents.isEmpty {
            suggestionSection(title: "Recent searches") {
              ForEach(recents, id: \.self) { term in
                suggestionChip(title: term, icon: "clock.arrow.circlepath") { fillQuery(term) }
              }
            }
          }
          if !expiring.isEmpty {
            suggestionSection(title: "Expiring soon") {
              ForEach(expiring) { item in
                suggestionChip(title: item.name, icon: "exclamationmark.circle") { fillQuery(item.name) }
              }
            }
          }
        }
      }
    }
    addRecipeRow
  }

  /// 추천 칩 섹션(제목 + 줄바꿈 흐름 배치 칩). 칩이 없으면 호출부에서 분기로 숨긴다.
  private func suggestionSection(
    title: LocalizedStringKey,
    @ViewBuilder chips: () -> some View
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.appSectionLabel).foregroundStyle(AppColor.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
      FlowLayout(spacing: 8) { chips() }
    }
  }

  /// 추천 칩 한 개. 탭하면 입력 필드를 채우고 포커스를 둔다(자동 검색·추가 아님).
  private func suggestionChip(title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: icon).font(.appTag)
        Text(verbatim: title).font(.appSectionLabel)
      }
      .foregroundStyle(AppColor.textSecondary)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(AppColor.card, in: Capsule())
    }
    .buttonStyle(.plain)
  }

  /// 칩 탭 → 입력 필드 채우기(검색은 입력 반응으로 자연히 일어남, 추가는 명시적 행 필요).
  private func fillQuery(_ term: String) {
    query = term
    inputFocused = true
  }

  /// 레시피 추가 진입(검색어와 무관, 항상 노출). 물건 빠른 추가와 입력 형태가 다른
  /// 레시피 전용 입력 화면으로 보낸다 — 의도 자동 추측 없이 사용자가 명시적으로 선택한다.
  private var addRecipeRow: some View {
    Button { showingRecipeCapture = true } label: {
      HStack(spacing: 10) {
        Image(systemName: "book.closed")
          .font(.appItemBody).foregroundStyle(AppColor.accent)
        Text("Add a recipe")
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
      recordRecentSearch()
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
      recordRecentSearch()
      dismiss()
      router.openRecipe(recipe)
    } label: {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Text(verbatim: recipe.title).font(.appItemBody).foregroundStyle(AppColor.textPrimary)
          Text("recipe.ingredientCount.\(recipe.inStockCount).\(recipe.mainIngredientCount)")
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
    recordRecentSearch()
    guard parser.isAvailable else {
      fallbackToStub(name)
      return
    }
    inputFocused = false
    parser.parse(name, in: modelContext)
  }

  /// 검색 의도가 확정된 시점(결과 탭·추가 진입)에 현재 입력어를 최근 검색어로 적재한다.
  private func recordRecentSearch() {
    recentSearchesJSON = RecentSearches.adding(trimmedQuery, to: recentSearchesJSON)
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

  /// 매칭 물건을 정확>접두>부분 등급, 동등급은 상태 가중치(임박 우선·위치없음 후순),
  /// 그 다음 이름순으로 정렬한다. `@Query` 가 이름순이라 동점은 안정적으로 이름순이 된다.
  private var itemResults: [Item] {
    let search = CaptureSearchQuery(trimmedQuery)
    guard search.hasSearchText else { return [] }
    let ranked = allItems
      .compactMap { item in itemRank(item, search: search).map { (item, $0) } }
      .sorted { lhs, rhs in lhs.1 < rhs.1 }
      .map(\.0)
    if !ranked.isEmpty { return ranked }
    return fuzzyItemFallback(search: search)
  }

  /// 정상 매칭 결과가 하나도 없을 때만, 전체 물건에 대해 토큰별 편집 거리 근사 매칭으로
  /// 폴백한다. `hasConcreteSignal` 가드를 유지해 빈 토큰 질의에서는 작동하지 않는다.
  /// 결과는 최하위 `.fuzzy` 등급으로 상태 가중치·이름순 정렬한다.
  private func fuzzyItemFallback(search: CaptureSearchQuery) -> [Item] {
    guard search.hasConcreteSignal, !search.isChoseongQuery, !search.tokens.isEmpty else { return [] }
    return allItems
      .filter { fuzzyMatchesAllTokens($0, search: search) }
      .map { (item: $0, rank: SearchRank(tier: .fuzzy, statusWeight: itemStatusWeight($0))) }
      .sorted { lhs, rhs in lhs.rank < rhs.rank }
      .map(\.item)
  }

  /// 모든 질의 토큰이 물건 필드의 어떤 단어와도 임계 이내 편집 거리인지.
  private func fuzzyMatchesAllTokens(_ item: Item, search: CaptureSearchQuery) -> Bool {
    let words = searchableItemFields(item)
      .flatMap { Item.normalize($0).split(separator: " ").map(String.init) }
    guard !words.isEmpty else { return false }
    return search.tokens.allSatisfy { token in
      let limit = Levenshtein.threshold(forLength: token.count)
      return words.contains { word in Levenshtein.distance(token, word) <= limit }
    }
  }

  /// 매칭 레시피를 같은 규칙(등급 → 상태 가중치 → 제목순)으로 정렬한다.
  private var recipeResults: [Recipe] {
    let search = CaptureSearchQuery(trimmedQuery)
    guard search.hasSearchText else { return [] }
    return allRecipes
      .compactMap { recipe in recipeRank(recipe, search: search).map { (recipe, $0) } }
      .sorted { lhs, rhs in lhs.1 < rhs.1 }
      .map(\.0)
  }

  /// 물건 검색은 이름 외에 위치·분류·태그·메모·수량 단위까지 같은 부분 일치로 본다.
  /// 매칭이면 등급·상태 가중치를 담은 `SearchRank` 를, 아니면 nil 을 반환한다.
  private func itemRank(_ item: Item, search: CaptureSearchQuery) -> SearchRank? {
    let fields = searchableItemFields(item).map(Item.normalize)
    guard let tier = matchTier(
      fields: fields,
      search: search,
      semanticFiltersPass: { itemMatchesSemanticFilters(item, search: search) }
    ) else { return nil }
    return SearchRank(tier: tier, statusWeight: itemStatusWeight(item))
  }

  /// 레시피 검색은 제목 외에 요약·분류·태그·재료 세부 텍스트까지 같은 부분 일치로 본다.
  private func recipeRank(_ recipe: Recipe, search: CaptureSearchQuery) -> SearchRank? {
    let fields = searchableRecipeFields(recipe).map(Item.normalize)
    guard let tier = matchTier(
      fields: fields,
      search: search,
      semanticFiltersPass: { recipeMatchesSemanticFilters(recipe, search: search) }
    ) else { return nil }
    return SearchRank(tier: tier, statusWeight: recipeStatusWeight(recipe))
  }

  /// 정규화한 필드들에 대한 매칭 등급을 계산한다(매칭 없으면 nil). `fullKey` 직접 매칭이
  /// 가장 강한 신호이고(정확>접두>부분), 없으면 의미 플래그 가드 통과 시 토큰 전체 일치를
  /// 부분 일치로 본다. `hasConcreteSignal` 가드를 유지해 불용어/조사만 남은 빈 토큰 질의가
  /// 전체를 매칭하지 못하게 한다. 의미 플래그(임박/만료 등)는 토큰 경로에만 적용한다(기존 동작).
  private func matchTier(
    fields: [String],
    search: CaptureSearchQuery,
    semanticFiltersPass: () -> Bool
  ) -> MatchTier? {
    // 초성 전용 질의는 일반 텍스트/토큰 경로 대신 초성 매칭만 쓴다(최하위 등급).
    if search.isChoseongQuery {
      let initialsMatch = fields.contains { Hangul.initials(of: $0).contains(search.choseongKey) }
      return initialsMatch ? .choseong : nil
    }
    if let tier = SearchRanking.bestTier(fields: fields, query: search.fullKey) {
      return tier
    }
    // `fullKey` 직접 매칭이 없으면 토큰 경로. 구체적 신호가 없으면(빈 토큰) 매칭하지 않는다.
    guard search.hasConcreteSignal else { return nil }
    guard semanticFiltersPass() else { return nil }
    let allTokensMatch = search.tokens.allSatisfy { token in
      fields.contains { $0.contains(token) }
    }
    return allTokensMatch ? .contains : nil
  }

  private func searchableItemFields(_ item: Item) -> [String] {
    var fields: [String?] = [
      item.name,
      item.normalizedName,
      item.locationPath,
      item.area?.space?.name,
      item.area?.name,
      item.spot?.name,
      item.category?.name,
      item.memo,
      item.quantity > 1 ? String(item.quantity) : nil,
    ]
    fields.append(contentsOf: item.tags.map { Optional($0.name) })
    return fields.compactMap { $0 }.filter { !$0.isEmpty }
  }

  private func searchableRecipeFields(_ recipe: Recipe) -> [String] {
    var fields: [String?] = [
      recipe.title,
      recipe.summary,
      recipe.cuisine,
      recipe.dishType,
      recipe.cuisine.map(RecipeClassification.cuisineLabel),
      recipe.dishType.map(RecipeClassification.dishTypeLabel),
      recipe.servings.map(String.init),
      recipe.totalMinutes.map(String.init),
    ]
    fields.append(contentsOf: recipe.tags.map { Optional($0.name) })
    fields.append(contentsOf: recipe.ingredients.flatMap(searchableIngredientFields).map(Optional.init))
    return fields.compactMap { $0 }.filter { !$0.isEmpty }
  }

  private func searchableIngredientFields(_ ingredient: RecipeIngredient) -> [String] {
    [
      ingredient.name,
      ingredient.unit,
      ingredient.note,
      ingredient.quantity.map { String($0) },
      ingredient.item?.name,
      ingredient.isOptional ? String(localized: "Optional ingredients") : nil,
    ].compactMap { $0 }.filter { !$0.isEmpty }
  }

  /// 물건 동등급 정렬 가중치. 임박은 위로(-1), 위치 미지정은 아래로(+1) 보낸다.
  private func itemStatusWeight(_ item: Item) -> Int {
    var weight = 0
    if item.isExpiringSoon { weight -= 1 }
    if item.area == nil, item.spot == nil { weight += 1 }
    return weight
  }

  /// 레시피 동등급 정렬 가중치. 지금 만들 수 있는 레시피·임박 재료 활용을 위로 보낸다.
  private func recipeStatusWeight(_ recipe: Recipe) -> Int {
    var weight = 0
    if recipe.isReadyToCook { weight -= 1 }
    if recipe.usesExpiringIngredient { weight -= 1 }
    return weight
  }

  private func itemMatchesSemanticFilters(_ item: Item, search: CaptureSearchQuery) -> Bool {
    if search.wantsExpiringSoon, !item.isExpiringSoon { return false }
    if search.wantsExpired, !(item.expiresAt.map { $0 < .now } ?? false) { return false }
    if search.wantsNoLocation, item.area != nil || item.spot != nil { return false }
    return true
  }

  private func recipeMatchesSemanticFilters(_ recipe: Recipe, search: CaptureSearchQuery) -> Bool {
    if search.wantsExpiringSoon, !recipe.usesExpiringIngredient { return false }
    if search.wantsReadyRecipe, !recipe.isReadyToCook { return false }
    if search.wantsMissingRecipe, recipe.missingIngredients.isEmpty { return false }
    return true
  }
}

/// 중앙 검색 자연어 질의. Foundation Models 의도 추측 없이 조사·불용어를 걷어낸
/// 토큰 전체 일치 + 작은 속성 플래그만 적용한다.
private struct CaptureSearchQuery {
  let fullKey: String
  let tokens: [String]
  /// 질의가 전부 초성 자음일 때의 초성 키(공백 제거). 일반 질의면 빈 문자열이다.
  /// 이 값이 비어 있지 않을 때만 초성 매칭을 활성화한다.
  let choseongKey: String
  let wantsExpiringSoon: Bool
  let wantsExpired: Bool
  let wantsNoLocation: Bool
  let wantsReadyRecipe: Bool
  let wantsMissingRecipe: Bool

  var hasSearchText: Bool {
    !fullKey.isEmpty
  }

  /// 초성 전용 질의인지. 이때는 일반 텍스트/토큰 경로 대신 초성 경로만 쓴다.
  var isChoseongQuery: Bool {
    !choseongKey.isEmpty
  }

  /// 토큰 또는 의미 플래그 같은 구체적 검색 신호가 하나라도 있는지. 모두 없으면(불용어·
  /// 조사만 남은 질의) 빈 토큰 `allSatisfy` 의 vacuous truth 로 전체가 매칭되는 것을 막는다.
  var hasConcreteSignal: Bool {
    !tokens.isEmpty
      || wantsExpiringSoon || wantsExpired || wantsNoLocation
      || wantsReadyRecipe || wantsMissingRecipe
  }

  init(_ raw: String) {
    let normalized = Item.normalize(raw)
    let compact = normalized.replacingOccurrences(of: " ", with: "")
    fullKey = normalized
    wantsExpiringSoon = Self.containsAny(compact, ["임박", "곧만료", "유통기한임박", "expiringsoon", "soon"])
    wantsExpired = Self.containsAny(compact, ["만료됨", "기한지남", "유통기한지남", "expired"])
    wantsNoLocation = Self.containsAny(compact, ["위치없음", "위치없는", "위치미정", "위치미지정", "장소없음", "noloca"])
    wantsReadyRecipe = Self.containsAny(compact, ["지금가능", "만들수있는", "바로가능", "ready", "cookable"])
    wantsMissingRecipe = Self.containsAny(compact, ["부족", "없는재료", "missing"])
    choseongKey = Hangul.isChoseongQuery(normalized) ? normalized.replacingOccurrences(of: " ", with: "") : ""
    tokens = Self.tokens(from: raw)
  }

  private static func tokens(from raw: String) -> [String] {
    let rules = SearchRules.shared
    let separators = CharacterSet.whitespacesAndNewlines
      .union(.punctuationCharacters)
      .union(.symbols)
    let rawTokens = raw.lowercased()
      .components(separatedBy: separators)
      .map(Item.normalize)
    let normalizedTokens = rawTokens
      .map { stripKoreanSuffixes($0, suffixes: rules.koreanSuffixes) }
      .filter { !$0.isEmpty }
      .filter { !rules.stopwords.contains($0) }
      .filter { !rules.semanticWords.contains($0) }
    var seen = Set<String>()
    return normalizedTokens.filter { seen.insert($0).inserted }
  }

  private static func stripKoreanSuffixes(_ raw: String, suffixes: [String]) -> String {
    var token = raw
    var didStrip = true
    while didStrip {
      didStrip = false
      for suffix in suffixes where token.hasSuffix(suffix) && token.count > suffix.count + 1 {
        token.removeLast(suffix.count)
        didStrip = true
        break
      }
    }
    return token
  }

  private static func containsAny(_ text: String, _ candidates: [String]) -> Bool {
    candidates.contains { text.contains($0) }
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
