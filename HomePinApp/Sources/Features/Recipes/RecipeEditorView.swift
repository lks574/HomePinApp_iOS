import SwiftData
import SwiftUI

/// 레시피 추가/편집 공용 에디터. draft·저장 규칙은 `RecipeEditorModel` 이 소유하고,
/// 이 View 는 레이아웃과 순수 UI 상태(포커스·삭제 확인)만 갖는다.
/// 재료는 보유 물건(`@Query items`)과 이름 정규화로 매칭해 재고 상태를 잇는다.
struct RecipeEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(AdService.self) private var adService
  @Query private var items: [Item]

  @State private var model: RecipeEditorModel
  private let onSaved: (() -> Void)?

  @State private var showingDeleteConfirm = false
  /// 이번 세션에 새 레시피를 저장(생성)했는지. 닫힐 때 전면 광고 적격 시도 판단에만 쓴다
  /// (편집·삭제·단순 닫기는 트리거 금지 — 신규 추가 완료 경계만).
  @State private var didCreateThisSession = false
  @FocusState private var focusedField: RecipeEditorField?

  /// 분류 빠른 선택 칩(RecipesView 필터와 동일 raw 키). 저장/비교는 raw, 표시만 현지화.
  private let cuisinePresets = RecipeClassification.cuisineKeys
  private let dishPresets = RecipeClassification.dishTypeKeys

  init(mode: RecipeEditorModel.Mode, onSaved: (() -> Void)? = nil) {
    _model = State(initialValue: RecipeEditorModel(mode: mode))
    self.onSaved = onSaved
  }

  /// AI 파싱 결과로 prefill 한 create 에디터(레시피 NL 추가 확인 화면).
  init(prefill: RecipeEditorPrefill, onSaved: (() -> Void)? = nil) {
    _model = State(initialValue: RecipeEditorModel(prefill: prefill))
    self.onSaved = onSaved
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          if model.isAIPrefilled {
            aiPrefillBanner
          }
          basicInfoCard
          classificationCard
          ingredientsCard
          optionalIngredientsCard
          stepsCard
          if model.isEditing {
            deleteButton
          }
        }
        .padding(20)
      }
      .appEditorSaveBar(title: model.saveTitle, isEnabled: model.canSave, action: save)
      .background(AppColor.screenBackground)
      .navigationTitle(model.navigationTitle)
      .compactNavTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
      .onAppear {
        if model.title.isEmpty {
          focusedField = .title
        }
      }
      .onDisappear {
        // 새 레시피 추가 완료 트리거: 이번 세션에 신규 생성했을 때만 전면 광고 적격 시도.
        // best-effort — 미로드/캡 미통과면 AdService 가 조용히 skip 한다.
        if didCreateThisSession {
          adService.showInterstitialIfEligible(trigger: .recipeAdded)
        }
      }
      .confirmationDialog(
        "Delete this recipe?",
        isPresented: $showingDeleteConfirm,
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive) { deleteRecipe() }
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  // MARK: - AI prefill 안내

  /// AI 가 채운 값임을 가볍게 알리는 배너. 모델이 단계 순서·수량을 가끔 틀리니 교정 유도.
  private var aiPrefillBanner: some View {
    HStack(spacing: 10) {
      Image(systemName: "sparkles")
        .font(.appItemBody)
        .foregroundStyle(AppColor.accent)
      Text("AI filled these in from your text. Check the ingredients and steps, then add.")
        .font(.appFootnote)
        .foregroundStyle(AppColor.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .appCard(radius: 16)
  }

  // MARK: - 기본정보

  private var basicInfoCard: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Title")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
        TextField("e.g. Braised Tofu", text: $model.title)
          .font(.appFieldText)
          .foregroundStyle(AppColor.textPrimary)
          .focused($focusedField, equals: .title)
      }
      .padding(16)

      Divider().padding(.leading, 16)
      HStack(spacing: 12) {
        numberField(title: "Servings", placeholder: "2", text: $model.servings, field: .servings)
        Divider().frame(height: 32)
        numberField(title: "Time (min)", placeholder: "20", text: $model.totalMinutes, field: .totalMinutes)
      }
      .padding(16)

      Divider().padding(.leading, 16)
      VStack(alignment: .leading, spacing: 8) {
        Text("Description")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
        TextField("Optional", text: $model.summary, axis: .vertical)
          .font(.appItemBody)
          .foregroundStyle(AppColor.textPrimary)
          .lineLimit(2...5)
          .focused($focusedField, equals: .summary)
      }
      .padding(16)
    }
    .appEditorCard()
  }

  private func numberField(
    title: LocalizedStringKey,
    placeholder: LocalizedStringKey,
    text: Binding<String>,
    field: RecipeEditorField
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.appCaptionStrong)
        .foregroundStyle(AppColor.textSecondary)
      TextField(placeholder, text: text)
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
        .numericKeyboard()
        .focused($focusedField, equals: field)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - 분류(요리권 + 종류)

  private var classificationCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      chipPickerRow(
        label: "Cuisine",
        presets: cuisinePresets,
        labelFor: RecipeClassification.cuisineLabel,
        selection: $model.cuisine
      )
      chipPickerRow(
        label: "Type",
        presets: dishPresets,
        labelFor: RecipeClassification.dishTypeLabel,
        selection: $model.dishType
      )
    }
    .padding(16)
    .appEditorCard()
  }

  /// 프리셋 칩 단일 선택(재탭 해제). 빈 문자열 = 미선택. 저장/비교는 raw 키(`preset`),
  /// 칩 표시는 `labelFor` 로 현지화한다.
  private func chipPickerRow(
    label: LocalizedStringKey,
    presets: [String],
    labelFor: @escaping (String) -> String,
    selection: Binding<String>
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(label)
        .font(.appRowLabel)
        .foregroundStyle(AppColor.textPrimary)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(presets, id: \.self) { preset in
            AppFilterChip(title: labelFor(preset), isSelected: selection.wrappedValue == preset) {
              selection.wrappedValue = (selection.wrappedValue == preset) ? "" : preset
            }
          }
        }
      }
    }
  }

  // MARK: - 재료

  /// 주재료 섹션 — 조리 가능 판정 대상. 행은 항상 최소 하나 유지된다.
  private var ingredientsCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeader(title: "Ingredients", action: model.addMainIngredient)

      ForEach($model.mainIngredients) { $ingredient in
        Divider().padding(.leading, 16)
        ingredientRow($ingredient) { model.removeMainIngredient($ingredient.wrappedValue) }
      }
    }
    .appEditorCard()
  }

  /// 부재료 섹션 — 선택적(비어 있어도 됨). 보유/부족 표시만 하고 판정·장보기에서 빠진다.
  private var optionalIngredientsCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeader(title: "Optional ingredients", action: model.addOptionalIngredient)

      if model.optionalIngredients.isEmpty {
        Divider().padding(.leading, 16)
        Text("Optional ingredients aren't counted toward what you can make now.")
          .font(.appFootnote)
          .foregroundStyle(AppColor.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
      } else {
        ForEach($model.optionalIngredients) { $ingredient in
          Divider().padding(.leading, 16)
          ingredientRow($ingredient) { model.removeOptionalIngredient($ingredient.wrappedValue) }
        }
      }
    }
    .appEditorCard()
  }

  private func ingredientRow(
    _ ingredient: Binding<RecipeEditorModel.IngredientDraft>,
    onRemove: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 10) {
      TextField("Ingredient", text: ingredient.name)
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)

      TextField("Qty", text: ingredient.quantity)
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
        .numericKeyboard(decimal: true)
        .multilineTextAlignment(.trailing)
        .frame(width: 44)

      TextField("Unit", text: ingredient.unit)
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
        .frame(width: 48)

      removeRowButton(action: onRemove)
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 52)
  }

  // MARK: - 단계

  private var stepsCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeader(title: "Steps", action: model.addStep)

      ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, _ in
        Divider().padding(.leading, 16)
        stepRow(index: index, step: $model.steps[index])
      }
    }
    .appEditorCard()
  }

  private func stepRow(index: Int, step: Binding<RecipeEditorModel.StepDraft>) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(index + 1)")
        .font(.appValueStrong)
        .foregroundStyle(AppColor.accent)
        .monospacedDigit()
        .frame(width: 22, alignment: .leading)
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: 8) {
        TextField("Step description", text: step.text, axis: .vertical)
          .font(.appFieldText)
          .foregroundStyle(AppColor.textPrimary)
          .lineLimit(1...4)

        HStack(spacing: 6) {
          Text("Timer (min)")
            .font(.appCaption)
            .foregroundStyle(AppColor.textTertiary)
          TextField("Optional", text: step.minutes)
            .font(.appFootnote)
            .foregroundStyle(AppColor.textPrimary)
            .numericKeyboard()
            .frame(width: 56)
        }
      }

      removeRowButton {
        model.removeStep(step.wrappedValue)
      }
      .padding(.top, 2)
    }
    .padding(16)
  }

  // MARK: - 공통 조각

  private func sectionHeader(title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    HStack {
      Text(title)
        .font(.appRowLabel)
        .foregroundStyle(AppColor.textPrimary)
      Spacer()
      Button(action: action) {
        Label("Add", systemImage: "plus")
          .font(.appTag)
          .foregroundStyle(AppColor.accent)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .frame(height: 50)
  }

  private func removeRowButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: "minus.circle.fill")
        .font(.appFieldText)
        .foregroundStyle(AppColor.textFaint)
    }
    .buttonStyle(.plain)
  }

  private var deleteButton: some View {
    Button(role: .destructive) {
      showingDeleteConfirm = true
    } label: {
      Text("Delete Recipe")
        .font(.appRowLabel)
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }
    .buttonStyle(.plain)
    .appCard(radius: 18)
  }

  // MARK: - 액션

  private func save() {
    guard model.canSave else { return }
    // 신규 생성 여부는 저장 전(모드 기준)에 확정해 둔다 — 닫힘 시 전면 트리거 판단에 쓴다.
    didCreateThisSession = !model.isEditing
    model.availableItems = items
    model.save(into: modelContext)
    onSaved?()
    dismiss()
  }

  private func deleteRecipe() {
    model.delete(from: modelContext)
    onSaved?()
    dismiss()
  }
}

struct RecipeEditorRoute: Identifiable {
  let id = UUID()
  let mode: RecipeEditorModel.Mode
}

private enum RecipeEditorField: Hashable {
  case title
  case servings
  case totalMinutes
  case summary
}

private extension View {
  func appEditorCard() -> some View {
    padding(0)
      .appCard(radius: 18)
  }
}
