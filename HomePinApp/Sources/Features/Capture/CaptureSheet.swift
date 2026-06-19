import SwiftData
import SwiftUI

/// 중앙 버튼이 띄우는 시트 — 검색-우선 통합 입력 + 공용 음성 입력.
/// - 단일 입력 필드 하나로 통합한다([추가|검색] 모드 토글 없음). 입력하면(타이핑·받아쓰기)
///   기존 항목을 실시간 검색해 물건/레시피 섹션으로 보여준다.
/// - 결과 아래 항상 `+ "{입력어}" 추가하기` 행을 둔다. 이 행을 눌러야만 명시적 추가가
///   일어난다(AI 가 추가/검색 의도를 자동 추측하지 않음 — 오분류 데이터 오염 방지).
/// - 추가는 장보기 재고 생성과 같은 `ItemEditor` `create` 화면으로 보낸다.
///   텍스트·음성 모두 같은 `add()` 경로에서 이름·수량·위치를 규칙 기반 prefill 한다.
/// - 음성(🎤): 받아쓰기(`SpeechDictationViewModel`) 결과가 같은 입력 필드로 들어가고,
///   `추가하기` 를 누르면 동일한 에디터 경로로 합류한다(단일 경로 원칙).
struct CaptureSheet: View {
  /// 시트를 여는 초기 모드. 진입점(중앙 ✨ 버튼·홈 빈 상태·새 구역 제안)이
  /// 같은 시트를 다른 입력 어댑터로 연다. nil(기본) 이면 검색-우선 단일 입력으로 연다.
  enum InitialMode {
    /// 스타터 템플릿으로 시작 — bulk 모드로 열고 템플릿 선택 시트를 띄운다.
    /// `area` 가 있으면 그 구역을 세션 Area 로, `suggestKind` 가 있으면 그 종류를 추천 강조한다.
    case starterTemplate(area: Area? = nil, suggestKind: StarterTemplate.Kind? = nil)
  }

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(AppRouter.self) private var router

  private let initialMode: InitialMode?

  @State private var query = ""
  @State private var dictation = SpeechDictationViewModel()
  @State private var editorRoute: ItemEditorRoute?
  @State private var showingRecipeCapture = false
  /// 같은 이름 물건 추가 시 합치기/새로 추가를 묻기 위한 후보(있으면 다이얼로그 표시).
  @State private var mergeCandidate: Item?
  /// 연속 입력(여러 개 추가) 모드 여부. 같은 시트 안에서 단일 입력 ↔ 칩 staging 으로 전환한다.
  @State private var isBulkMode = false
  @State private var bulkModel = ItemBulkAddModel()
  @State private var bulkDraft = ""
  @State private var showingSessionAreaPicker = false
  @State private var ignoredSpot: Spot?
  /// 스타터 템플릿 선택 시트 표시 여부.
  @State private var showingTemplatePicker = false
  @AppStorage(RecentSearches.storageKey) private var recentSearchesJSON = "[]"
  @FocusState private var inputFocused: Bool

  init(initialMode: InitialMode? = nil) {
    self.initialMode = initialMode
  }

  /// 검색 대상 전체 물건. 이름순으로 받아 정규화 키로 in-memory 필터한다(개인 재고
  /// 규모에선 충분). 동적 술어 대신 단일 `@Query` + 필터.
  @Query(sort: \Item.name) private var allItems: [Item]

  /// 검색 대상 전체 레시피. 제목·재료명을 정규화 키로 in-memory 필터한다.
  @Query(sort: \Recipe.title) private var allRecipes: [Recipe]
  @Query(sort: \Area.sortOrder) private var allAreas: [Area]
  @Query(sort: \Spot.name) private var allSpots: [Spot]

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        inputRow
        if let micHint {
          micHint
            .font(.appFootnote).foregroundStyle(AppColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if isBulkMode {
          bulkContent
        } else {
          content
        }
      }
      .padding(20)
      .background(AppColor.screenBackground)
      .navigationTitle(Text(isBulkMode ? "Add several" : "Add or find"))
      .compactNavTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
        ToolbarItem(placement: .primaryAction) {
          Button(isBulkMode ? "Single" : "Add several") { toggleBulkMode() }
        }
      }
      .sheet(isPresented: $showingSessionAreaPicker) {
        AreaPickerSheet(areas: allAreas, selectedArea: $bulkModel.sessionArea, selectedSpot: $ignoredSpot)
      }
      .sheet(item: $editorRoute) { route in
        ItemEditorView(mode: route.mode) {
          dismiss()
        }
      }
      .sheet(isPresented: $showingRecipeCapture) {
        RecipeCaptureView()
      }
      .sheet(isPresented: $showingTemplatePicker) {
        StarterTemplatePickerSheet(suggested: suggestedTemplate) { template in
          bulkModel.appendChips(from: template)
        }
      }
      .confirmationDialog(
        mergeDialogTitle,
        isPresented: mergeDialogPresented,
        titleVisibility: .visible
      ) {
        Button("Merge quantity") { mergeWithCandidate() }
        Button("Add as new") { addAsNewFromMerge() }
        Button("Cancel", role: .cancel) { mergeCandidate = nil }
      }
      .onAppear { applyInitialMode() }
      .onChange(of: dictation.transcript) { _, newTranscript in
        applyTranscript(newTranscript)
      }
      .onChange(of: dictation.state) { oldState, newState in
        handleDictationStateChange(from: oldState, to: newState)
      }
      .onChange(of: bulkDraft) { _, newValue in
        if isBulkMode { ingestBulkSeparators(newValue) }
      }
      .onDisappear {
        dictation.reset()
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
      TextField(isBulkMode ? "Add items, separated by commas" : "Type anything", text: inputBinding, axis: isBulkMode ? .vertical : .horizontal)
        .font(.appFieldText)
        .focused($inputFocused)
        .submitLabel(isBulkMode ? .return : .search)
      if !inputBinding.wrappedValue.isEmpty {
        Button { inputBinding.wrappedValue = "" } label: {
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

  /// 활성 입력 필드 바인딩. bulk 모드면 `bulkDraft`, 아니면 검색·단건 추가용 `query`.
  private var inputBinding: Binding<String> {
    isBulkMode ? $bulkDraft : $query
  }

  // MARK: - 초기 모드 (진입점별 어댑터)

  /// 진입점이 지정한 초기 모드를 적용한다. 기본(nil)이면 단일 입력 필드에 포커스만 둔다.
  /// 템플릿 모드는 bulk 모드로 열어 결과 칩이 같은 staging UI 로 합류하게 한다.
  private func applyInitialMode() {
    switch initialMode {
    case nil:
      inputFocused = true
    case let .starterTemplate(area, _):
      isBulkMode = true
      if let area { bulkModel.sessionArea = area }
      showingTemplatePicker = true
    }
  }

  /// 템플릿 선택 시트의 추천 템플릿. 명시적 종류 → 새 Area 이름 매칭 → 없으면 nil(전체 목록).
  private var suggestedTemplate: StarterTemplate? {
    guard case let .starterTemplate(area, suggestKind) = initialMode else { return nil }
    if let suggestKind { return StarterTemplate.template(for: suggestKind) }
    if let area { return StarterTemplate.match(areaName: area.name) }
    return nil
  }

  // MARK: - 연속 입력 (여러 개 추가)

  /// 단일 입력 ↔ 칩 staging 모드를 같은 시트 안에서 전환한다. 진행 중 받아쓰기·입력은 정리한다.
  private func toggleBulkMode() {
    dictation.reset()
    if isBulkMode {
      isBulkMode = false
      bulkDraft = ""
    } else {
      isBulkMode = true
      query = ""
    }
    inputFocused = true
  }

  /// 입력 텍스트에 분절자(쉼표·줄바꿈)가 들어오면 칩으로 커밋한다(자동 저장 아님).
  /// 분절자가 없으면 계속 입력 중이라 보고 draft 에 남겨 둔다.
  private func ingestBulkSeparators(_ text: String) {
    guard text.contains(where: { $0 == "," || $0 == "、" || $0 == "\n" }) else { return }
    commitBulkDraft()
  }

  /// 현재 draft 를 파싱해 칩으로 적재하고 draft 를 비운다. 빈 입력이면 no-op.
  private func commitBulkDraft() {
    let raw = bulkDraft
    bulkDraft = ""
    guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    bulkModel.appendChips(from: raw, areas: allAreas, spots: allSpots)
  }

  /// 칩들을 실제 재고로 반영한다(명시적 "추가"). 빈 staging 이면 no-op. 합치기 룩업을 위해
  /// 현재 전체 재고(`allItems`)를 모델에 넘긴다 — 템플릿·연속입력 진입이 모두 이 한
  /// 경로로 합류하므로 1곳만 정리하면 된다. 추가 후 시트를 닫는다(결과 요약은 후속 항목).
  private func commitBulkInsert() {
    commitBulkDraft()
    guard bulkModel.hasInsertableChips else { return }
    // 반환 (inserted, merged) 는 결과 요약용 — 시트 dismiss·범용 토스트 인프라 부재로
    // 표시 UI 는 후속(`docs/follow-ups.md`). 시그니처는 이번에 확정해 둔다.
    _ = bulkModel.bulkInsert(into: modelContext, existingItems: allItems)
    dismiss()
  }

  @ViewBuilder
  private var bulkContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        sessionAreaRow
        adapterRow
        if bulkModel.chips.isEmpty {
          Text("Type or speak items. Separate with commas or new lines to make chips.")
            .font(.appFootnote).foregroundStyle(AppColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } else {
          chipList
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      AppFullWidthPrimaryButton(
        title: "bulk.add.\(bulkModel.chips.count)",
        isEnabled: bulkModel.hasInsertableChips,
        action: commitBulkInsert
      )
      .padding(.top, 8)
    }
  }

  /// 세션 구역 선택 행. 모든 칩의 기본 구역(칩이 직접 구역을 인식하면 그 칩만 override).
  private var sessionAreaRow: some View {
    Button { showingSessionAreaPicker = true } label: {
      HStack(spacing: 10) {
        Image(systemName: "tray.full").font(.appItemBody).foregroundStyle(AppColor.accent)
        VStack(alignment: .leading, spacing: 2) {
          Text("Place for all").font(.appRowLabel).foregroundStyle(AppColor.textPrimary)
          Text(verbatim: bulkModel.sessionArea?.name ?? String(localized: "Unsorted (no location)"))
            .font(.appCaption)
            .foregroundStyle(bulkModel.sessionArea == nil ? AppColor.textMuted : AppColor.textSecondary)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.appTag).foregroundStyle(AppColor.textFaint)
      }
      .padding(.horizontal, 16).padding(.vertical, 12)
      .appCard()
    }
    .buttonStyle(.plain)
  }

  /// bulk 모드의 입력 어댑터 진입 행 — 스타터 템플릿(양 플랫폼).
  /// 어댑터 결과는 같은 칩 staging 으로 합류시킨다(insert 는 "추가" 버튼에서만).
  private var adapterRow: some View {
    HStack(spacing: 10) {
      adapterButton(title: "Starter templates", icon: "square.grid.2x2") {
        showingTemplatePicker = true
      }
    }
  }

  private func adapterButton(
    title: LocalizedStringKey,
    icon: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon).font(.appItemBody).foregroundStyle(AppColor.accent)
        Text(title).font(.appCaptionStrong).foregroundStyle(AppColor.textPrimary)
          .lineLimit(1).minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12).padding(.vertical, 12)
      .appCard()
    }
    .buttonStyle(.plain)
  }

  private var chipList: some View {
    let existingNames = Set(allItems.map(\.normalizedName))
    return VStack(spacing: 10) {
      ForEach(bulkModel.chips) { chip in
        chipRow(
          chip,
          isDuplicate: bulkModel.isDuplicate(chip, existingNormalizedNames: existingNames),
          conflictsWithStock: bulkModel.conflictsWithExistingStock(chip, existingNormalizedNames: existingNames)
        )
      }
    }
  }

  /// - Parameters:
  ///   - isDuplicate: staging 자기중복 또는 기존 재고 충돌(둘 다 경고 신호).
  ///   - conflictsWithStock: 기존 재고 Item 과만 충돌(합치기 토글을 노출할 조건).
  private func chipRow(
    _ chip: ItemBulkAddModel.Chip,
    isDuplicate: Bool,
    conflictsWithStock: Bool
  ) -> some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 4) {
        TextField("Item name", text: nameBinding(for: chip.id))
          .font(.appItemBody).foregroundStyle(AppColor.textPrimary)
        HStack(spacing: 6) {
          if let area = chip.parsedArea ?? bulkModel.sessionArea {
            Text(verbatim: area.name).font(.appTag).foregroundStyle(AppColor.textMuted)
          } else {
            Text("Unsorted").font(.appTag).foregroundStyle(AppColor.textFaint)
          }
          // 기존 재고와 충돌하는 칩만 탭 가능한 합치기 토글로 승격한다(미선택=경고, 선택=합치기).
          // staging 자기중복만인 칩은 기존 경고 배지 그대로(합치기 의미 없음).
          if conflictsWithStock {
            mergeToggle(for: chip)
          } else if isDuplicate {
            duplicateWarningBadge
          }
        }
      }
      Spacer()
      stepper(for: chip)
      Button { bulkModel.remove(chip.id) } label: {
        Image(systemName: "xmark.circle.fill").font(.appItemBody).foregroundStyle(AppColor.textFaint)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
    .appCard()
  }

  /// 기존 재고 충돌 칩의 인라인 토글. 미선택=경고 배지 ↔ 선택="기존에 합치기"(accent).
  /// 탭만으로 의도를 바꾸며 다이얼로그를 연쇄하지 않는다(비차단·비연쇄).
  private func mergeToggle(for chip: ItemBulkAddModel.Chip) -> some View {
    Button { bulkModel.toggleMerge(chip.id) } label: {
      HStack(spacing: 3) {
        Image(systemName: chip.mergeIntoExisting ? "arrow.merge" : "exclamationmark.triangle.fill")
        Text(chip.mergeIntoExisting ? "Merge into stock" : "Already in stock")
      }
      .font(.appTag)
      .foregroundStyle(chip.mergeIntoExisting ? Color.white : AppColor.chipSoonText)
      .padding(.horizontal, 8).padding(.vertical, 3)
      .background(chip.mergeIntoExisting ? AppColor.accent : AppColor.chipSoonBackground, in: Capsule())
    }
    .buttonStyle(.plain)
  }

  private var duplicateWarningBadge: some View {
    HStack(spacing: 3) {
      Image(systemName: "exclamationmark.triangle.fill")
      Text("Already in stock")
    }
    .font(.appTag)
    .foregroundStyle(AppColor.chipSoonText)
    .padding(.horizontal, 8).padding(.vertical, 3)
    .background(AppColor.chipSoonBackground, in: Capsule())
  }

  private func stepper(for chip: ItemBulkAddModel.Chip) -> some View {
    HStack(spacing: 8) {
      Button { bulkModel.decrement(chip.id) } label: {
        Image(systemName: "minus").font(.appBadge).frame(width: 28, height: 28)
      }
      .buttonStyle(.plain).foregroundStyle(AppColor.accent).disabled(chip.quantity <= 1)
      Text("\(chip.quantity)").font(.appValueStrong).monospacedDigit().frame(minWidth: 22)
        .foregroundStyle(AppColor.textPrimary)
      Button { bulkModel.increment(chip.id) } label: {
        Image(systemName: "plus").font(.appBadge).frame(width: 28, height: 28)
      }
      .buttonStyle(.plain).foregroundStyle(AppColor.accent)
    }
  }

  private func nameBinding(for id: ItemBulkAddModel.Chip.ID) -> Binding<String> {
    Binding(
      get: { bulkModel.chips.first(where: { $0.id == id })?.name ?? "" },
      set: { bulkModel.updateName($0, for: id) }
    )
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

  /// 명시적 추가 행. 결과 유무와 무관하게 항상 노출한다.
  private var addSection: some View {
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

  /// 받아쓰기 텍스트를 현재 활성 입력 필드에 채운다. 단일 라인이라 개행을 공백으로 바꾼다.
  /// bulk 모드에선 무음 자동 종료 시점에 `bulkDraft` 를 칩으로 커밋한다(아래 상태 핸들러).
  private func applyTranscript(_ transcript: String) {
    guard !transcript.isEmpty else { return }
    let cleaned = transcript.replacingOccurrences(of: "\n", with: " ")
    if isBulkMode {
      bulkDraft = cleaned
    } else {
      query = cleaned
    }
  }

  /// bulk 모드에서 받아쓰기 무음 자동 종료(`.recording` → `.idle`)를 칩 경계로 쓴다.
  /// transcript 누적분을 칩으로 커밋하고 draft 를 비운다(자동 재시작 OFF — 사용자가 mic 재탭).
  private func handleDictationStateChange(from oldState: SpeechDictationViewModel.State, to newState: SpeechDictationViewModel.State) {
    guard isBulkMode, oldState == .recording, newState == .idle else { return }
    commitBulkDraft()
    dictation.reset()
  }

  // MARK: - 추가 로직

  /// 명시적 추가 진입. 같은 정규화 이름의 기존 물건이 있으면 "수량 합치기/새로 추가" 를
  /// 먼저 제안하고(자동 합치기·자동 저장 없음), 없으면 바로 추가 경로로 진행한다.
  private func add() {
    let draft = ItemQuickAddParser.parse(trimmedQuery, areas: allAreas, spots: allSpots)
    let name = draft.name
    recordRecentSearch()
    let key = Item.normalize(name)
    if let duplicate = allItems.first(where: { $0.normalizedName == key }) {
      mergeCandidate = duplicate
      return
    }
    openItemEditor(draft)
  }

  /// 실제 추가 경로. 장보기 재고 추가와 같은 `ItemEditor` create 화면으로 보낸다.
  private func openItemEditor(_ draft: ItemQuickAddDraft) {
    guard !draft.name.isEmpty else { return }
    inputFocused = false
    editorRoute = ItemEditorRoute(
      mode: .create(
        initialName: draft.name,
        quantity: draft.quantity,
        area: draft.area,
        spot: draft.spot
      )
    )
  }

  /// 검색 의도가 확정된 시점(결과 탭·추가 진입)에 현재 입력어를 최근 검색어로 적재한다.
  private func recordRecentSearch() {
    recentSearchesJSON = RecentSearches.adding(trimmedQuery, to: recentSearchesJSON)
  }

  /// 중복 합치기 다이얼로그 표시 바인딩. 닫으면 후보를 비운다.
  private var mergeDialogPresented: Binding<Bool> {
    Binding(
      get: { mergeCandidate != nil },
      set: { if !$0 { mergeCandidate = nil } }
    )
  }

  /// 다이얼로그 제목 — 이미 있는 물건 이름을 끼워 안내한다(사용자 입력이라 verbatim).
  private var mergeDialogTitle: Text {
    if let name = mergeCandidate?.name {
      Text("merge.alreadyExists.\(name)")
    } else {
      Text("This item already exists")
    }
  }

  /// "수량 합치기" — 기존 물건 편집 화면으로 진입한다(수량 가산은 에디터에서 사용자가
  /// 직접 올려 저장; 자동 저장하지 않는다 — 명시적 쓰기 원칙).
  private func mergeWithCandidate() {
    guard let duplicate = mergeCandidate else { return }
    mergeCandidate = nil
    editorRoute = ItemEditorRoute(mode: .edit(duplicate))
  }

  /// "새로 추가" — 합치기를 거부하고 공용 물건 에디터로 진행한다.
  private func addAsNewFromMerge() {
    mergeCandidate = nil
    openItemEditor(ItemQuickAddParser.parse(trimmedQuery, areas: allAreas, spots: allSpots))
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
    fields.append(contentsOf: (item.tags ?? []).map { Optional($0.name) })
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
    fields.append(contentsOf: (recipe.tags ?? []).map { Optional($0.name) })
    fields.append(contentsOf: (recipe.ingredients ?? []).flatMap(searchableIngredientFields).map(Optional.init))
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
