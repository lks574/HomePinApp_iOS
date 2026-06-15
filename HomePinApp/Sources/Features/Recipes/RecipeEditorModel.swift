import Foundation
import Observation
import SwiftData

/// 레시피 추가/편집 에디터의 화면 로컬 모델.
/// 저장 전 draft(기본정보·재료 행·단계 행)와 다단계 쓰기 불변식
/// (create/edit 분기·ingredients 재구성·sortOrder 부여)을 소유한다.
/// SwiftData 직결로 충분하지 않은, CLAUDE.md 가 허용한 "얇은 @Observable 모델" 케이스.
@Observable
final class RecipeEditorModel {
  enum Mode {
    case create
    case edit(Recipe)
  }

  /// 동적 재료 행의 draft. 저장 시 `RecipeIngredient` 로 materialize 한다.
  struct IngredientDraft: Identifiable {
    let id = UUID()
    var name: String = ""
    var quantity: String = ""
    var unit: String = ""
  }

  /// 동적 단계 행의 draft. 저장 시 `RecipeStep` 값으로 materialize 한다.
  struct StepDraft: Identifiable {
    let id = UUID()
    var text: String = ""
    var minutes: String = ""
  }

  let mode: Mode

  var title: String
  var cuisine: String
  var dishType: String
  var servings: String
  var totalMinutes: String
  var summary: String
  var ingredients: [IngredientDraft]
  var steps: [StepDraft]

  /// 재고 매칭 후보. View 가 `@Query` 로 채워 넣는다(저장 시 이름 정규화로 매칭).
  @ObservationIgnored var availableItems: [Item] = []

  init(mode: Mode) {
    self.mode = mode
    switch mode {
    case .create:
      title = ""
      cuisine = ""
      dishType = ""
      servings = ""
      totalMinutes = ""
      summary = ""
      ingredients = [IngredientDraft()]
      steps = [StepDraft()]

    case let .edit(recipe):
      title = recipe.title
      cuisine = recipe.cuisine ?? ""
      dishType = recipe.dishType ?? ""
      servings = recipe.servings.map(String.init) ?? ""
      totalMinutes = recipe.totalMinutes.map(String.init) ?? ""
      summary = recipe.summary ?? ""
      let ingredientDrafts = recipe.ingredients
        .sorted { $0.sortOrder < $1.sortOrder }
        .map { ing in
          IngredientDraft(
            name: ing.name,
            quantity: ing.quantity.map(Self.formatQuantity) ?? "",
            unit: ing.unit ?? ""
          )
        }
      ingredients = ingredientDrafts.isEmpty ? [IngredientDraft()] : ingredientDrafts
      let stepDrafts = recipe.steps.map { step in
        StepDraft(text: step.text, minutes: step.minutes.map(String.init) ?? "")
      }
      steps = stepDrafts.isEmpty ? [StepDraft()] : stepDrafts
    }
  }

  var navigationTitle: String {
    switch mode {
    case .create: "레시피 추가"
    case .edit: "레시피 편집"
    }
  }

  var saveTitle: String {
    switch mode {
    case .create: "추가"
    case .edit: "저장"
    }
  }

  var isEditing: Bool {
    if case .edit = mode { return true }
    return false
  }

  /// 제목이 공백이 아니면 저장 가능.
  var canSave: Bool {
    !trimmedTitle.isEmpty
  }

  // MARK: - 동적 행 편집

  func addIngredient() {
    ingredients.append(IngredientDraft())
  }

  func removeIngredient(_ draft: IngredientDraft) {
    ingredients.removeAll { $0.id == draft.id }
  }

  func addStep() {
    steps.append(StepDraft())
  }

  func removeStep(_ draft: StepDraft) {
    steps.removeAll { $0.id == draft.id }
  }

  // MARK: - 저장 / 삭제

  /// draft 를 SwiftData 에 반영한다. 재료는 보유 물건(`availableItems`)과 이름 정규화로
  /// 매칭해 `RecipeIngredient.item` 을 연결한다(매칭 없으면 nil). 편집 시 기존 재료는
  /// cascade 로 정리한 뒤 draft 로 재구성한다.
  func save(into modelContext: ModelContext) {
    guard canSave else { return }

    let recipe: Recipe
    switch mode {
    case .create:
      recipe = Recipe(title: trimmedTitle)
      modelContext.insert(recipe)
    case let .edit(existing):
      recipe = existing
      recipe.title = trimmedTitle
    }

    recipe.cuisine = trimmedOrNil(cuisine)
    recipe.dishType = trimmedOrNil(dishType)
    recipe.summary = trimmedOrNil(summary)
    recipe.servings = parsedInt(servings)
    recipe.totalMinutes = parsedInt(totalMinutes)
    recipe.steps = materializedSteps()
    recipe.updatedAt = .now

    // 재료 재구성: 기존 라인은 cascade 삭제 후 draft 로 새로 만든다.
    for old in recipe.ingredients {
      modelContext.delete(old)
    }
    recipe.ingredients = []

    let itemsByNormalizedName = Dictionary(
      availableItems.map { (Item.normalize($0.name), $0) },
      uniquingKeysWith: { first, _ in first }
    )

    var order = 0
    for draft in ingredients {
      let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { continue }
      let matched = itemsByNormalizedName[Item.normalize(name)]
      let ingredient = RecipeIngredient(
        name: name,
        quantity: parsedQuantity(draft.quantity),
        unit: trimmedOrNil(draft.unit),
        sortOrder: order,
        recipe: recipe,
        item: matched
      )
      modelContext.insert(ingredient)
      order += 1
    }
  }

  /// 편집 중인 레시피를 삭제한다(create 모드면 무시). ingredients 는 cascade 로 함께 삭제.
  func delete(from modelContext: ModelContext) {
    guard case let .edit(recipe) = mode else { return }
    modelContext.delete(recipe)
  }

  // MARK: - 파생

  private var trimmedTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func materializedSteps() -> [RecipeStep] {
    steps.compactMap { draft in
      let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { return nil }
      return RecipeStep(text: text, minutes: parsedInt(draft.minutes))
    }
  }

  private func trimmedOrNil(_ raw: String) -> String? {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  private func parsedInt(_ raw: String) -> Int? {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : Int(value)
  }

  private func parsedQuantity(_ raw: String) -> Double? {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : Double(value)
  }

  /// 정수면 소수점 없이, 아니면 그대로 문자열화(편집 라운드트립용).
  private static func formatQuantity(_ value: Double) -> String {
    if value == value.rounded() {
      return String(Int(value))
    }
    return String(value)
  }
}
