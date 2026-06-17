import Foundation
import Observation
import SwiftData
import SwiftUI

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
  /// `isOptional` 로 주재료/부재료를 구분한다(섹션별 편집).
  /// 불변식: `isOptional` 은 소속 배열과 항상 일치한다 — `mainIngredients` 안의 draft 는
  /// `false`, `optionalIngredients` 안의 draft 는 `true`. add/prefill/edit 모든 경로가
  /// 소속 배열에 맞춰 값을 세팅하므로 이 둘은 단일 진실 소스처럼 동작한다.
  struct IngredientDraft: Identifiable {
    let id = UUID()
    var name: String = ""
    var quantity: String = ""
    var unit: String = ""
    var isOptional: Bool = false
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
  /// 주재료 draft 행(조리 가능 판정 대상). 섹션별 편집을 위해 부재료와 별도 배열로 둔다.
  var mainIngredients: [IngredientDraft]
  /// 부재료 draft 행(선택적, 비어 있어도 됨). 판정에서 빠지고 보유 표시만 한다.
  var optionalIngredients: [IngredientDraft]
  var steps: [StepDraft]

  /// AI 파서가 채운 값인가(create 모드일 때만 의미). 확인 화면이 "AI 가 채움" 을 가볍게
  /// 시각 구분하는 데 쓴다. 수동 create 는 false.
  let isAIPrefilled: Bool

  /// 재고 매칭 후보. View 가 `@Query` 로 채워 넣는다(저장 시 이름 정규화로 매칭).
  @ObservationIgnored var availableItems: [Item] = []

  init(mode: Mode) {
    self.mode = mode
    isAIPrefilled = false
    switch mode {
    case .create:
      title = ""
      cuisine = ""
      dishType = ""
      servings = ""
      totalMinutes = ""
      summary = ""
      mainIngredients = [IngredientDraft()]
      optionalIngredients = []
      steps = [StepDraft()]

    case let .edit(recipe):
      title = recipe.title
      cuisine = recipe.cuisine ?? ""
      dishType = recipe.dishType ?? ""
      servings = recipe.servings.map(String.init) ?? ""
      totalMinutes = recipe.totalMinutes.map(String.init) ?? ""
      summary = recipe.summary ?? ""
      let sorted = (recipe.ingredients ?? []).sorted { $0.sortOrder < $1.sortOrder }
      let mainDrafts = sorted.filter { !$0.isOptional }.map(Self.draft(from:))
      mainIngredients = mainDrafts.isEmpty ? [IngredientDraft()] : mainDrafts
      optionalIngredients = sorted.filter(\.isOptional).map(Self.draft(from:))
      let stepDrafts = recipe.steps.map { step in
        StepDraft(text: step.text, minutes: step.minutes.map(String.init) ?? "")
      }
      steps = stepDrafts.isEmpty ? [StepDraft()] : stepDrafts
    }
  }

  /// AI 파서(`ParsedRecipe`) 결과로 prefill 한 create 모델. 분류는 raw 키 매핑이 끝난
  /// 값을 받고, 재료·단계는 draft 행으로 materialize 한다. AI 가 뽑은 행만 채우고 빈 행을
  /// 덧붙이지 않는다(불필요한 빈 칸 방지 — 추가는 각 섹션의 "+ Add" 버튼으로). 결과가 비면
  /// 빈 행 하나로 시작한다. 저장 로직은 수동 create 와 동일(`save(into:)` 의 `availableItems`
  /// 정규화 매칭으로 재료 Item grounding).
  init(prefill: RecipeEditorPrefill) {
    mode = .create
    isAIPrefilled = true
    title = prefill.title
    cuisine = prefill.cuisine
    dishType = prefill.dishType
    servings = prefill.servings
    totalMinutes = prefill.totalMinutes
    summary = ""
    let mainDrafts = prefill.ingredients
      .filter { !$0.isOptional }
      .map { IngredientDraft(name: $0.name, quantity: $0.quantity, unit: $0.unit, isOptional: false) }
    mainIngredients = mainDrafts.isEmpty ? [IngredientDraft()] : mainDrafts
    optionalIngredients = prefill.ingredients
      .filter(\.isOptional)
      .map { IngredientDraft(name: $0.name, quantity: $0.quantity, unit: $0.unit, isOptional: true) }
    let stepDrafts = prefill.steps.map { StepDraft(text: $0, minutes: "") }
    steps = stepDrafts.isEmpty ? [StepDraft()] : stepDrafts
  }

  var navigationTitle: LocalizedStringKey {
    switch mode {
    case .create: "Add Recipe"
    case .edit: "Edit Recipe"
    }
  }

  var saveTitle: LocalizedStringKey {
    switch mode {
    case .create: "Add"
    case .edit: "Save"
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

  func addMainIngredient() {
    mainIngredients.append(IngredientDraft(isOptional: false))
  }

  func removeMainIngredient(_ draft: IngredientDraft) {
    mainIngredients.removeAll { $0.id == draft.id }
  }

  func addOptionalIngredient() {
    optionalIngredients.append(IngredientDraft(isOptional: true))
  }

  func removeOptionalIngredient(_ draft: IngredientDraft) {
    optionalIngredients.removeAll { $0.id == draft.id }
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
    for old in recipe.ingredients ?? [] {
      modelContext.delete(old)
    }
    recipe.ingredients = []

    let itemsByNormalizedName = Dictionary(
      availableItems.map { (Item.normalize($0.name), $0) },
      uniquingKeysWith: { first, _ in first }
    )

    // 주재료 먼저, 부재료를 이어서 연속 sortOrder 로 materialize 한다(섹션 순서 보존).
    var order = 0
    for draft in mainIngredients + optionalIngredients {
      let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { continue }
      let matched = itemsByNormalizedName[Item.normalize(name)]
      let ingredient = RecipeIngredient(
        name: name,
        quantity: parsedQuantity(draft.quantity),
        unit: trimmedOrNil(draft.unit),
        sortOrder: order,
        isOptional: draft.isOptional,
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

  /// 저장된 재료를 편집 draft 행으로 옮긴다(주/부 구분 보존).
  private static func draft(from ingredient: RecipeIngredient) -> IngredientDraft {
    IngredientDraft(
      name: ingredient.name,
      quantity: ingredient.quantity.map(formatQuantity) ?? "",
      unit: ingredient.unit ?? "",
      isOptional: ingredient.isOptional
    )
  }

  /// 정수면 소수점 없이, 아니면 그대로 문자열화(편집 라운드트립용).
  private static func formatQuantity(_ value: Double) -> String {
    if value == value.rounded() {
      return String(Int(value))
    }
    return String(value)
  }
}
