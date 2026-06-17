import Foundation
import SwiftData

/// 파서가 뽑은 순수 문자열(`ParsedItem`)과 SwiftData 사이의 도메인 경계.
/// "없으면생성/있으면매핑" 매칭과 다건 일괄 저장(여러 `@Model` 트랜잭션)을 담당한다 —
/// 엔진은 추출만 하고(SwiftData 무지), 매칭/생성은 전부 여기서 한다(ADR 분리 원칙).
///
/// 매칭은 `Item.normalize(_:)` 정규화 키 일치로 한다. 위치는 앱 규칙(`Item` 은 최소 Area
/// 소속, spot.area == area)을 따라 세부위치가 정해지면 그 구역에 종속시킨다.
enum AddDraftResolver {
  /// 저장에 쓸 grounding 후보(이름)를 SwiftData 에서 모은다. 엔진 프롬프트 주입용.
  static func grounding(in modelContext: ModelContext) -> NLParseGrounding {
    let spaces = (try? modelContext.fetch(FetchDescriptor<Space>())) ?? []
    let areas = (try? modelContext.fetch(FetchDescriptor<Area>())) ?? []
    let spots = (try? modelContext.fetch(FetchDescriptor<Spot>())) ?? []
    let categories = (try? modelContext.fetch(FetchDescriptor<ItemCategory>())) ?? []
    let tags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
    return NLParseGrounding(
      spaces: spaces.map(\.name),
      areas: areas.map(\.name),
      spots: spots.map(\.name),
      categories: categories.map(\.name),
      tags: tags.map(\.name),
    )
  }

  /// 추출된 물건 배열을 확인 드래프트로 해석한다(저장 아님). 각 이름 문자열을 기존
  /// 엔티티와 정규화 매칭해 신규/기존을 정한다. 빈 이름 물건은 건너뛴다.
  static func makeDrafts(from parsed: [ParsedItem], in modelContext: ModelContext) -> [AddDraft] {
    let areas = (try? modelContext.fetch(FetchDescriptor<Area>())) ?? []
    let spots = (try? modelContext.fetch(FetchDescriptor<Spot>())) ?? []
    let categories = (try? modelContext.fetch(FetchDescriptor<ItemCategory>())) ?? []
    let tags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []

    return parsed.compactMap { item -> AddDraft? in
      let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedName.isEmpty else { return nil }

      // 세부위치를 먼저 매칭하고, 매칭되면 그 구역을 우선한다(위치 불변식).
      let spotMatch = match(item.spot, in: spots)
      let areaMatch: NameMatch<Area> = if case let .existing(spot)? = spotMatch, let area = spot.area {
        .existing(area)
      } else {
        match(item.area, in: areas) ?? .new("")
      }

      return AddDraft(
        name: trimmedName,
        quantity: max(item.quantity, 1),
        areaMatch: areaMatch,
        spotMatch: spotMatch,
        categoryMatch: match(item.category, in: categories),
        tagMatches: item.tags.compactMap { match($0, in: tags) ?? newMatch($0) },
      )
    }
  }

  /// 드래프트 배열을 SwiftData 에 일괄 저장한다. 신규 위치/분류/태그는 함께 생성하고,
  /// 위치 불변식(spot.area == area)을 유지한다. `ItemEditorModel.save` 의 패턴을 따른다.
  static func save(_ drafts: [AddDraft], into modelContext: ModelContext) {
    // 같은 신규 이름을 여러 드래프트가 쓰면 한 번만 만들어 공유한다(세션 내 캐시).
    var newAreas: [String: Area] = [:]
    var newSpots: [String: Spot] = [:]
    var newCategories: [String: ItemCategory] = [:]
    var newTags: [String: Tag] = [:]
    let defaultSpace = try? modelContext.fetch(FetchDescriptor<Space>(sortBy: [SortDescriptor(\.sortOrder)])).first

    for draft in drafts where draft.canSave {
      let area = resolveArea(draft.areaMatch, cache: &newAreas, defaultSpace: defaultSpace ?? nil, modelContext: modelContext)
      let spot = resolveSpot(draft.spotMatch, area: area, cache: &newSpots, modelContext: modelContext)
      let resolvedArea = spot?.area ?? area
      let category = resolveCategory(draft.categoryMatch, cache: &newCategories, modelContext: modelContext)
      let resolvedTags = draft.tagMatches.compactMap { resolveTag($0, cache: &newTags, modelContext: modelContext) }

      let item = Item(
        name: draft.trimmedName,
        quantity: draft.quantity,
        area: resolvedArea,
        spot: spot,
        category: category,
      )
      item.tags = resolvedTags
      modelContext.insert(item)
    }
  }

  // MARK: - 매칭

  /// 정규화 키 일치로 기존 엔티티를 찾는다. 빈 이름이면 매칭 없음(nil).
  /// 드래프트 전용 인라인 편집 시트가 자유 입력을 `.existing`/`.new` 로 판정할 때도
  /// 같은 로직을 쓰도록 `internal` 로 노출한다(매칭 규칙 단일화).
  static func match<Model: NameMatchable>(_ raw: String, in candidates: [Model]) -> NameMatch<Model>? {
    let key = Item.normalize(raw)
    guard !key.isEmpty else { return nil }
    if let found = candidates.first(where: { Item.normalize($0.name) == key }) {
      return .existing(found)
    }
    return .new(raw.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  static func newMatch<Model: NameMatchable>(_ raw: String) -> NameMatch<Model>? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return .new(trimmed)
  }

  // MARK: - 저장 해석(신규 생성/기존 연결)

  private static func resolveArea(
    _ match: NameMatch<Area>,
    cache: inout [String: Area],
    defaultSpace: Space?,
    modelContext: ModelContext,
  ) -> Area? {
    switch match {
    case let .existing(area):
      area
    case let .new(name):
      makeOrReuse(name, cache: &cache) {
        let area = Area(name: $0, space: defaultSpace)
        modelContext.insert(area)
        return area
      }
    }
  }

  private static func resolveSpot(
    _ match: NameMatch<Spot>?,
    area: Area?,
    cache: inout [String: Spot],
    modelContext: ModelContext,
  ) -> Spot? {
    guard let match else { return nil }
    switch match {
    case let .existing(spot):
      return spot
    case let .new(name):
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }
      return makeOrReuse(trimmed, cache: &cache) {
        let spot = Spot(name: $0, area: area)
        modelContext.insert(spot)
        return spot
      }
    }
  }

  private static func resolveCategory(
    _ match: NameMatch<ItemCategory>?,
    cache: inout [String: ItemCategory],
    modelContext: ModelContext,
  ) -> ItemCategory? {
    guard let match else { return nil }
    switch match {
    case let .existing(category):
      return category
    case let .new(name):
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }
      return makeOrReuse(trimmed, cache: &cache) {
        let category = ItemCategory(name: $0)
        modelContext.insert(category)
        return category
      }
    }
  }

  private static func resolveTag(
    _ match: NameMatch<Tag>,
    cache: inout [String: Tag],
    modelContext: ModelContext,
  ) -> Tag? {
    switch match {
    case let .existing(tag):
      return tag
    case let .new(name):
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }
      return makeOrReuse(trimmed, cache: &cache) {
        let tag = Tag(name: $0)
        modelContext.insert(tag)
        return tag
      }
    }
  }

  /// 같은 정규화 키로 이번 세션에서 이미 만든 신규 엔티티가 있으면 재사용한다.
  private static func makeOrReuse<Model>(
    _ name: String,
    cache: inout [String: Model],
    make: (String) -> Model,
  ) -> Model {
    let key = Item.normalize(name)
    if let existing = cache[key] { return existing }
    let created = make(name)
    cache[key] = created
    return created
  }
}

/// `AddDraftResolver` 가 정규화 매칭하는 이름 보유 모델 공통 인터페이스.
protocol NameMatchable: AnyObject {
  var name: String { get }
}

extension Area: NameMatchable {}
extension Spot: NameMatchable {}
extension ItemCategory: NameMatchable {}
extension Tag: NameMatchable {}
