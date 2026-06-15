import SwiftData
import SwiftUI

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
          Text("레시피").font(.appScreenTitle).foregroundStyle(AppColor.textPrimary)
          Text("냉장고 재료로 만들 수 있는 요리")
            .font(.system(size: 14)).foregroundStyle(AppColor.textTertiary)
            .padding(.bottom, 16)

          AppSearchBar(placeholder: "레시피 · 재료 검색")
            .padding(.bottom, 14)
          cuisineChips
          dishChips

          if !soonItems.isEmpty {
            AppExpiringItemsBanner(
              items: soonItems,
              headline: "\(soonItems.prefix(3).map(\.name).joined(separator: " · ")), 오늘 다 써볼까요?"
            )
            .padding(.bottom, 26)
          }

          if !soonRecipes.isEmpty {
            AppSectionTitle(title: "임박 재료로 만들기", uppercase: true)
            VStack(spacing: 13) {
              ForEach(soonRecipes) { recipeSoonCard($0) }
            }
            .padding(.bottom, 26)
          }

          AppSectionTitle(title: "내 재료로 만들 수 있어요", uppercase: true)
          VStack(spacing: 13) {
            ForEach(otherRecipes) { recipeCompactRow($0) }
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

  private var soonItems: [Item] { items.expiringSoonByExpiry }

  private var soonRecipes: [Recipe] {
    filteredRecipes.filter(\.usesExpiringIngredient)
  }

  private var otherRecipes: [Recipe] {
    let soonIDs = Set(soonRecipes.map(\.id))
    return filteredRecipes.filter { !soonIDs.contains($0.id) }
  }

  /// 도메인 재고 상태 → 칩 시각 상태 매핑(UI 책임).
  private func chipState(_ ing: RecipeIngredient) -> AppIngredientChipState {
    switch ing.stockStatus {
    case .missing: .missing
    case .soon: .soon
    case .have: .have
    }
  }

  // MARK: 조각

  private var cuisineChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(cuisines, id: \.self) { c in
          AppFilterChip(title: c, isSelected: cuisine == c) { cuisine = c }
        }
      }
    }
    .padding(.bottom, 10)
  }

  private var dishChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(dishes, id: \.self) { d in
          AppOutlinedChip(title: d)
        }
      }
    }
    .padding(.bottom, 22)
  }


  // MARK: 레시피 카드

  /// 임박 재료가 있는 레시피 카드 — 진행률 + 재료 칩.
  private func recipeSoonCard(_ recipe: Recipe) -> some View {
    let ingredients = recipe.ingredients.sorted { $0.sortOrder < $1.sortOrder }
    let soon = ingredients.filter { $0.stockStatus == .soon }
    let badge = soon.isEmpty ? nil : (soon.count == 1 ? "임박 \(soon[0].name)" : "임박 \(soon.count)개")
    let have = ingredients.filter(\.isInStock).count
    let total = ingredients.count
    let pct = total == 0 ? 0 : Double(have) / Double(total)

    return VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text(recipe.title).font(.system(size: 18, weight: .bold)).foregroundStyle(AppColor.textPrimary)
          Text("\(recipe.totalMinutes ?? 0)분").font(.appFootnote).foregroundStyle(AppColor.textMuted)
        }
        Spacer()
        if let badge {
          AppStatusPill(title: badge, style: .accent)
        }
      }
      FlowLayout(spacing: 6) {
        ForEach(ingredients) { ing in
          AppIngredientChip(name: ing.name, state: chipState(ing))
        }
      }
      .padding(.top, 13)
      HStack(spacing: 9) {
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(AppColor.progressTrack)
            Capsule().fill(AppColor.accent).frame(width: geo.size.width * pct)
          }
        }
        .frame(height: 6)
        Text("재료 \(have)/\(total)")
          .font(.appSectionLabel).foregroundStyle(AppColor.textSecondary)
          .fixedSize()
      }
      .padding(.top, 14)
    }
    .padding(EdgeInsets(top: 17, leading: 17, bottom: 15, trailing: 17))
    .appCard()
  }

  /// 보유 재료로 만들 수 있는 레시피 한 줄.
  private func recipeCompactRow(_ recipe: Recipe) -> some View {
    let have = recipe.inStockCount
    let total = recipe.ingredients.count
    let ready = total > 0 && have == total

    return HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 2) {
        Text(recipe.title).font(.appValueStrong).foregroundStyle(AppColor.textPrimary)
        Text("\(recipe.totalMinutes ?? 0)분").font(.appFootnote).foregroundStyle(AppColor.textMuted)
      }
      Spacer()
      AppStatusPill(title: ready ? "재료 완비" : "재료 \(have)/\(total)", style: ready ? .ready : .neutral)
    }
    .padding(EdgeInsets(top: 15, leading: 17, bottom: 15, trailing: 17))
    .appCard(radius: 18)
  }
}
