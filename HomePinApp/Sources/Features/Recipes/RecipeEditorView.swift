import SwiftData
import SwiftUI

/// 레시피 추가/편집 공용 에디터. draft·저장 규칙은 `RecipeEditorModel` 이 소유하고,
/// 이 View 는 레이아웃과 순수 UI 상태(포커스·삭제 확인)만 갖는다.
/// 재료는 보유 물건(`@Query items`)과 이름 정규화로 매칭해 재고 상태를 잇는다.
struct RecipeEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query private var items: [Item]

  @State private var model: RecipeEditorModel
  private let onSaved: (() -> Void)?

  @State private var showingDeleteConfirm = false
  @FocusState private var focusedField: RecipeEditorField?

  /// 분류 빠른 선택 칩(RecipesView 필터와 동일). 재탭하면 해제.
  private let cuisinePresets = ["한식", "일식", "중식", "양식", "분식"]
  private let dishPresets = ["국·찌개", "볶음", "구이", "조림", "밥·면", "반찬"]

  init(mode: RecipeEditorModel.Mode, onSaved: (() -> Void)? = nil) {
    _model = State(initialValue: RecipeEditorModel(mode: mode))
    self.onSaved = onSaved
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          basicInfoCard
          classificationCard
          ingredientsCard
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
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("닫기") { dismiss() }
        }
      }
      .onAppear {
        if model.title.isEmpty {
          focusedField = .title
        }
      }
      .confirmationDialog(
        "이 레시피를 삭제할까요?",
        isPresented: $showingDeleteConfirm,
        titleVisibility: .visible
      ) {
        Button("삭제", role: .destructive) { deleteRecipe() }
        Button("취소", role: .cancel) {}
      }
    }
  }

  // MARK: - 기본정보

  private var basicInfoCard: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text("제목")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
        TextField("예: 두부조림", text: $model.title)
          .font(.appFieldText)
          .foregroundStyle(AppColor.textPrimary)
          .focused($focusedField, equals: .title)
      }
      .padding(16)

      Divider().padding(.leading, 16)
      HStack(spacing: 12) {
        numberField(title: "인분", placeholder: "2", text: $model.servings, field: .servings)
        Divider().frame(height: 32)
        numberField(title: "소요(분)", placeholder: "20", text: $model.totalMinutes, field: .totalMinutes)
      }
      .padding(16)

      Divider().padding(.leading, 16)
      VStack(alignment: .leading, spacing: 8) {
        Text("설명")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
        TextField("선택 입력", text: $model.summary, axis: .vertical)
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
    title: String,
    placeholder: String,
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
        .keyboardType(.numberPad)
        .focused($focusedField, equals: field)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - 분류(요리권 + 종류)

  private var classificationCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      chipPickerRow(label: "요리권", presets: cuisinePresets, selection: $model.cuisine)
      chipPickerRow(label: "종류", presets: dishPresets, selection: $model.dishType)
    }
    .padding(16)
    .appEditorCard()
  }

  /// 프리셋 칩 단일 선택(재탭 해제). 빈 문자열 = 미선택.
  private func chipPickerRow(
    label: String,
    presets: [String],
    selection: Binding<String>
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(label)
        .font(.appRowLabel)
        .foregroundStyle(AppColor.textPrimary)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(presets, id: \.self) { preset in
            AppFilterChip(title: preset, isSelected: selection.wrappedValue == preset) {
              selection.wrappedValue = (selection.wrappedValue == preset) ? "" : preset
            }
          }
        }
      }
    }
  }

  // MARK: - 재료

  private var ingredientsCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeader(title: "재료", action: model.addIngredient)

      ForEach($model.ingredients) { $ingredient in
        Divider().padding(.leading, 16)
        ingredientRow($ingredient)
      }
    }
    .appEditorCard()
  }

  private func ingredientRow(_ ingredient: Binding<RecipeEditorModel.IngredientDraft>) -> some View {
    HStack(spacing: 10) {
      TextField("재료명", text: ingredient.name)
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)

      TextField("양", text: ingredient.quantity)
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .frame(width: 44)

      TextField("단위", text: ingredient.unit)
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
        .frame(width: 48)

      removeRowButton {
        model.removeIngredient(ingredient.wrappedValue)
      }
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 52)
  }

  // MARK: - 단계

  private var stepsCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeader(title: "조리 단계", action: model.addStep)

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
        TextField("단계 설명", text: step.text, axis: .vertical)
          .font(.appFieldText)
          .foregroundStyle(AppColor.textPrimary)
          .lineLimit(1...4)

        HStack(spacing: 6) {
          Text("타이머(분)")
            .font(.appCaption)
            .foregroundStyle(AppColor.textTertiary)
          TextField("선택", text: step.minutes)
            .font(.appFootnote)
            .foregroundStyle(AppColor.textPrimary)
            .keyboardType(.numberPad)
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

  private func sectionHeader(title: String, action: @escaping () -> Void) -> some View {
    HStack {
      Text(title)
        .font(.appRowLabel)
        .foregroundStyle(AppColor.textPrimary)
      Spacer()
      Button(action: action) {
        Label("추가", systemImage: "plus")
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
      Text("레시피 삭제")
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
