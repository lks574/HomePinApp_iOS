import SwiftData
import SwiftUI

enum IngredientStatus { case have, soon, missing }

/// 레시피 — 임박 카드 + "임박 재료로 만들기" + "내 재료로 만들 수 있어요".
struct RecipesView: View {
  @Query(sort: \Recipe.title) private var recipes: [Recipe]
  @Query private var items: [Item]
  @State private var cuisine = "전체"

  private let cuisines = ["전체", "한식", "일식", "중식", "양식", "분식"]
  private let dishes = ["국·찌개", "볶음", "구이", "조림", "밥·면", "반찬"]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text("레시피").font(.system(size: 34, weight: .heavy)).foregroundStyle(AppColor.textPrimary)
          Text("냉장고 재료로 만들 수 있는 요리")
            .font(.system(size: 14)).foregroundStyle(AppColor.textTertiary)
            .padding(.bottom, 16)

          searchBar
          cuisineChips
          dishChips

          if !soonItems.isEmpty {
            soonCard.padding(.bottom, 26)
          }

          if !soonRecipes.isEmpty {
            sectionTitle("임박 재료로 만들기")
            VStack(spacing: 13) {
              ForEach(soonRecipes) { RecipeSoonCard(recipe: $0, status: status, dDay: dDay) }
            }
            .padding(.bottom, 26)
          }

          sectionTitle("내 재료로 만들 수 있어요")
          VStack(spacing: 13) {
            ForEach(otherRecipes) { RecipeCompactRow(recipe: $0, haveCount: haveCount) }
          }
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .toolbar(.hidden, for: .navigationBar)
    }
  }

  // MARK: 파생

  private var filteredRecipes: [Recipe] {
    cuisine == "전체" ? recipes : recipes.filter { $0.cuisine == cuisine }
  }

  private var soonItems: [Item] {
    items.filter(isSoon).sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
  }

  private var soonRecipes: [Recipe] {
    filteredRecipes.filter { r in r.ingredients.contains { ing in ing.item.map { isSoon($0) } ?? false } }
  }

  private var otherRecipes: [Recipe] {
    let soonIDs = Set(soonRecipes.map(\.id))
    return filteredRecipes.filter { !soonIDs.contains($0.id) }
  }

  private func isSoon(_ item: Item) -> Bool { item.isExpiringSoon }

  private func dDay(_ item: Item) -> Int { item.daysUntilExpiry ?? .max }

  private func status(_ ing: RecipeIngredient) -> IngredientStatus {
    guard ing.isInStock, let item = ing.item else { return .missing }
    return isSoon(item) ? .soon : .have
  }

  private func haveCount(_ recipe: Recipe) -> Int {
    recipe.ingredients.filter(\.isInStock).count
  }

  // MARK: 조각

  private func sectionTitle(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 13, weight: .bold))
      .foregroundStyle(AppColor.textTertiary)
      .textCase(.uppercase)
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var searchBar: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass").foregroundStyle(AppColor.textMuted)
      Text("레시피 · 재료 검색").foregroundStyle(AppColor.textMuted)
      Spacer()
    }
    .font(.system(size: 16))
    .padding(.horizontal, 15).frame(height: 46)
    .appCard(radius: 14)
    .padding(.bottom, 14)
  }

  private var cuisineChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(cuisines, id: \.self) { c in
          let on = cuisine == c
          Text(c)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(on ? .white : AppColor.textSecondary)
            .padding(.horizontal, 15).padding(.vertical, 8)
            .background(on ? AppColor.accent : AppColor.card, in: Capsule())
            .onTapGesture { cuisine = c }
        }
      }
    }
    .padding(.bottom, 10)
  }

  private var dishChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(dishes, id: \.self) { d in
          Text(d)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(hex: 0x6F4A38))
            .padding(.horizontal, 15).padding(.vertical, 8)
            .overlay(Capsule().strokeBorder(Color(hex: 0xE0D3C6)))
        }
      }
    }
    .padding(.bottom, 22)
  }

  private var soonCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("유통기한 임박 \(soonItems.count)가지")
        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: 0xF6DDD0))
        .padding(.bottom, 5)
      Text("\(soonItems.prefix(3).map(\.name).joined(separator: " · ")), 오늘 다 써볼까요?")
        .font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
      HStack(spacing: 6) {
        ForEach(soonItems.prefix(3)) { item in
          Text("\(item.name) D-\(max(dDay(item), 0))")
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.white.opacity(0.22), in: Capsule())
        }
      }
      .padding(.top, 12)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(colors: [AppColor.accent, AppColor.accentDark], startPoint: .topLeading, endPoint: .bottomTrailing),
      in: RoundedRectangle(cornerRadius: 20, style: .continuous)
    )
  }
}

private struct RecipeSoonCard: View {
  let recipe: Recipe
  let status: (RecipeIngredient) -> IngredientStatus
  let dDay: (Item) -> Int

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text(recipe.title).font(.system(size: 18, weight: .bold)).foregroundStyle(AppColor.textPrimary)
          Text(meta).font(.system(size: 13)).foregroundStyle(AppColor.textMuted)
        }
        Spacer()
        if let badge = soonBadge {
          Text(badge)
            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(AppColor.accent, in: Capsule())
        }
      }
      chips.padding(.top, 13)
      progress.padding(.top, 14)
    }
    .padding(EdgeInsets(top: 17, leading: 17, bottom: 15, trailing: 17))
    .appCard()
  }

  private var sortedIngredients: [RecipeIngredient] {
    recipe.ingredients.sorted { $0.sortOrder < $1.sortOrder }
  }

  private var meta: String { "\(recipe.totalMinutes ?? 0)분" }

  private var soonBadge: String? {
    let soon = sortedIngredients.filter { status($0) == .soon }
    guard !soon.isEmpty else { return nil }
    return soon.count == 1 ? "임박 \(soon[0].name)" : "임박 \(soon.count)개"
  }

  private var chips: some View {
    FlowChips(ingredients: sortedIngredients, status: status)
  }

  private var progress: some View {
    let have = sortedIngredients.filter(\.isInStock).count
    let total = sortedIngredients.count
    let pct = total == 0 ? 0 : Double(have) / Double(total)
    return HStack(spacing: 9) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color(hex: 0xEFE7DD))
          Capsule().fill(AppColor.accent).frame(width: geo.size.width * pct)
        }
      }
      .frame(height: 6)
      Text("재료 \(have)/\(total)")
        .font(.system(size: 13, weight: .semibold)).foregroundStyle(AppColor.textSecondary)
        .fixedSize()
    }
  }
}

/// 재료 칩들을 줄바꿈 배치.
private struct FlowChips: View {
  let ingredients: [RecipeIngredient]
  let status: (RecipeIngredient) -> IngredientStatus

  var body: some View {
    // 간단히 가로 래핑 대신 2줄 한도 내 HStack 래핑 효과를 위해 FlowLayout 사용.
    FlowLayout(spacing: 6) {
      ForEach(ingredients) { ing in
        IngredientChip(name: ing.name, status: status(ing))
      }
    }
  }
}

private struct IngredientChip: View {
  let name: String
  let status: IngredientStatus

  var body: some View {
    Text(status == .missing ? "\(name) 부족" : name)
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(textColor)
      .padding(.horizontal, 11).padding(.vertical, 5)
      .background(background, in: Capsule())
      .overlay {
        if status == .missing {
          Capsule().strokeBorder(AppColor.chipMissingBorder, style: StrokeStyle(lineWidth: 1, dash: [3]))
        }
      }
  }

  private var textColor: Color {
    switch status {
    case .have: AppColor.chipHaveText
    case .soon: AppColor.chipSoonText
    case .missing: AppColor.chipMissingText
    }
  }

  private var background: Color {
    switch status {
    case .have: AppColor.chipHaveBackground
    case .soon: AppColor.chipSoonBackground
    case .missing: .clear
    }
  }
}

private struct RecipeCompactRow: View {
  let recipe: Recipe
  let haveCount: (Recipe) -> Int

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 2) {
        Text(recipe.title).font(.system(size: 17, weight: .bold)).foregroundStyle(AppColor.textPrimary)
        Text("\(recipe.totalMinutes ?? 0)분").font(.system(size: 13)).foregroundStyle(AppColor.textMuted)
      }
      Spacer()
      Text(haveLabel)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(ready ? AppColor.chipReadyText : AppColor.textSecondary)
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(ready ? AppColor.chipReadyBackground : AppColor.chipHaveBackground, in: Capsule())
    }
    .padding(EdgeInsets(top: 15, leading: 17, bottom: 15, trailing: 17))
    .appCard(radius: 18)
  }

  private var have: Int { haveCount(recipe) }
  private var total: Int { recipe.ingredients.count }
  private var ready: Bool { total > 0 && have == total }
  private var haveLabel: String { ready ? "재료 완비" : "재료 \(have)/\(total)" }
}
