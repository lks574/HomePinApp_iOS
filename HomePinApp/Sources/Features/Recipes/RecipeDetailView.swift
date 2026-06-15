import SwiftData
import SwiftUI

/// 레시피 상세 — 헤더(메타·요약) + 재고 요약 + 재료 목록(보유 상태 칩) + 조리 단계.
/// NavigationLink push 진입(자체 NavigationStack 없음). 상단 Menu 로 편집/삭제.
struct RecipeDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var editorRoute: RecipeEditorRoute?
  @State private var showingDeleteConfirm = false
  let recipe: Recipe

  init(recipe: Recipe) {
    self.recipe = recipe
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        backButton
        headerRow
        stockSummaryCard
          .padding(.top, 20)
        ingredientsCard
          .padding(.top, 14)
        if !sortedSteps.isEmpty {
          stepsCard
            .padding(.top, 14)
        }
      }
      .padding(20)
    }
    .background(AppColor.screenBackground)
    .toolbar(.hidden, for: .navigationBar)
    .sheet(item: $editorRoute) { route in
      RecipeEditorView(mode: route.mode)
    }
    .confirmationDialog(
      "‘\(recipe.title)’ 레시피를 삭제할까요?",
      isPresented: $showingDeleteConfirm
    ) {
      Button("삭제", role: .destructive) { deleteRecipe() }
      Button("취소", role: .cancel) {}
    } message: {
      Text("재료 \(recipe.ingredients.count)개도 함께 삭제됩니다. 보관 중인 재고는 삭제되지 않습니다.")
    }
  }

  // MARK: 파생

  private var sortedIngredients: [RecipeIngredient] {
    recipe.ingredients.sorted { $0.sortOrder < $1.sortOrder }
  }

  private var sortedSteps: [RecipeStep] {
    recipe.steps
  }

  /// 헤더 메타 한 줄(cuisine · 종류 · 인분 · 분) — nil 값은 생략.
  private var metaText: String? {
    var parts: [String] = []
    if let cuisine = recipe.cuisine, !cuisine.isEmpty { parts.append(cuisine) }
    if let dishType = recipe.dishType, !dishType.isEmpty { parts.append(dishType) }
    if let servings = recipe.servings { parts.append("\(servings)인분") }
    if let minutes = recipe.totalMinutes { parts.append("\(minutes)분") }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// 도메인 재고 상태 → 칩 시각 상태 매핑(UI 책임, RecipesView 와 동일).
  private func chipState(_ ingredient: RecipeIngredient) -> AppIngredientChipState {
    switch ingredient.stockStatus {
    case .missing: .missing
    case .soon: .soon
    case .have: .have
    }
  }

  // MARK: 조각

  private var backButton: some View {
    Button(action: { dismiss() }) {
      HStack(spacing: 4) {
        Image(systemName: "chevron.left").font(.appRowLabel)
        Text("레시피").font(.system(size: 16, weight: .semibold))
      }
      .foregroundStyle(AppColor.accent)
    }
    .buttonStyle(.plain)
    .padding(.bottom, 16)
  }

  private var headerRow: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Text(recipe.title)
          .font(.system(size: 30, weight: .heavy))
          .foregroundStyle(AppColor.textPrimary)
        Spacer(minLength: 8)
        Menu {
          Button {
            editorRoute = RecipeEditorRoute(mode: .edit(recipe))
          } label: {
            Label("편집", systemImage: "pencil")
          }
          Button(role: .destructive) {
            showingDeleteConfirm = true
          } label: {
            Label("삭제", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppColor.textSecondary)
            .frame(width: 36, height: 36)
            .background(AppColor.card, in: Circle())
        }
      }
      if let metaText {
        Text(metaText)
          .font(.appFootnote)
          .foregroundStyle(AppColor.textTertiary)
      }
      if let summary = recipe.summary, !summary.isEmpty {
        Text(summary)
          .font(.appItemBody)
          .foregroundStyle(AppColor.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  /// 재고 요약 — "내 재료 X/전체" + 준비 완료/부족 안내(RecipesView 톤과 맞춤).
  private var stockSummaryCard: some View {
    let have = recipe.inStockCount
    let total = recipe.ingredients.count
    let pct = total == 0 ? 0 : Double(have) / Double(total)
    let missing = recipe.missingIngredients

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text("내 재료 \(have)/\(total)")
            .font(.appValueStrong)
            .foregroundStyle(AppColor.textPrimary)
          if recipe.isReadyToCook, total > 0 {
            Text("지금 만들 수 있어요")
              .font(.appSectionLabel)
              .foregroundStyle(AppColor.chipReadyText)
          } else if !missing.isEmpty {
            Text("부족한 재료 \(missing.count)개")
              .font(.appSectionLabel)
              .foregroundStyle(AppColor.textSecondary)
          }
        }
        Spacer()
        AppStatusPill(
          title: recipe.isReadyToCook && total > 0 ? "재료 완비" : "재료 \(have)/\(total)",
          style: recipe.isReadyToCook && total > 0 ? .ready : .neutral
        )
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(AppColor.progressTrack)
          Capsule().fill(AppColor.accent).frame(width: geo.size.width * pct)
        }
      }
      .frame(height: 6)
      if !recipe.isReadyToCook, !missing.isEmpty {
        FlowLayout(spacing: 6) {
          ForEach(missing) { ingredient in
            AppIngredientChip(name: ingredient.name, state: .missing)
          }
        }
      }
    }
    .padding(EdgeInsets(top: 17, leading: 17, bottom: 17, trailing: 17))
    .appCard()
  }

  /// 재료 목록(sortOrder 정렬) — name · quantity+unit · 보유 상태 칩.
  private var ingredientsCard: some View {
    VStack(spacing: 0) {
      HStack {
        Text("재료").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColor.textPrimary)
        Spacer()
        Text("\(recipe.ingredients.count)개").font(.appCaptionStrong).foregroundStyle(AppColor.textFaint)
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 10)

      ForEach(sortedIngredients) { ingredient in
        ingredientRow(ingredient)
      }
    }
    .appCard()
  }

  private func ingredientRow(_ ingredient: RecipeIngredient) -> some View {
    HStack(spacing: 10) {
      Circle().fill(AppColor.itemDot).frame(width: 6, height: 6)
      Text(ingredient.name).font(.appItemBody).foregroundStyle(AppColor.textPrimary)
      Spacer()
      if let amount = amountText(ingredient) {
        Text(amount)
          .font(.appCaptionStrong)
          .foregroundStyle(AppColor.textMuted)
      }
      AppIngredientChip(name: stockLabel(ingredient.stockStatus), state: chipState(ingredient))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 11)
    .overlay(alignment: .top) { Divider().padding(.leading, 16) }
  }

  /// 수량+단위 표시 문자열 — 둘 다 없으면 nil. 정수 수량은 소수점 제거.
  private func amountText(_ ingredient: RecipeIngredient) -> String? {
    guard let quantity = ingredient.quantity else {
      return ingredient.unit
    }
    let quantityText = quantity == quantity.rounded()
      ? String(Int(quantity))
      : String(quantity)
    if let unit = ingredient.unit, !unit.isEmpty {
      return "\(quantityText)\(unit)"
    }
    return quantityText
  }

  private func stockLabel(_ status: RecipeIngredient.StockStatus) -> String {
    switch status {
    case .have: "보유"
    case .soon: "임박"
    case .missing: "없음"
    }
  }

  /// 조리 단계 — 번호 매긴 목록, 각 단계 text + minutes("N분").
  private var stepsCard: some View {
    VStack(spacing: 0) {
      HStack {
        Text("조리 단계").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColor.textPrimary)
        Spacer()
        Text("\(sortedSteps.count)단계").font(.appCaptionStrong).foregroundStyle(AppColor.textFaint)
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 10)

      ForEach(Array(sortedSteps.enumerated()), id: \.offset) { index, step in
        stepRow(number: index + 1, step: step)
      }
    }
    .appCard()
  }

  private func stepRow(number: Int, step: RecipeStep) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(number)")
        .font(.appBadge)
        .foregroundStyle(AppColor.accent)
        .frame(width: 24, height: 24)
        .background(AppColor.badgeBackground, in: Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text(step.text)
          .font(.appItemBody)
          .foregroundStyle(AppColor.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
        if let minutes = step.minutes {
          Text("\(minutes)분")
            .font(.appCaptionStrong)
            .foregroundStyle(AppColor.textMuted)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .overlay(alignment: .top) { Divider().padding(.leading, 16) }
  }

  // MARK: 액션

  private func deleteRecipe() {
    modelContext.delete(recipe)
    dismiss()
  }
}
