import SwiftData
import SwiftUI

/// 레시피 — 임박 카드 + "임박 재료로 만들기" + "내 재료로 만들 수 있어요".
struct RecipesView: View {
  @Query(sort: \Recipe.title) private var recipes: [Recipe]
  @Query private var items: [Item]
  /// 필터 선택값은 저장값(raw 한국어 키) 또는 `allKey`(전체) 다. 표시 라벨만 현지화한다.
  @State private var cuisine = Self.allKey
  @State private var dish = Self.allKey
  @State private var editorRoute: RecipeEditorRoute?

  /// "전체"(필터 해제) 센티넬. raw 키와 충돌하지 않게 빈 문자열로 둔다.
  private static let allKey = ""

  private let cuisines = [allKey] + RecipeClassification.cuisineKeys
  private let dishes = [allKey] + RecipeClassification.dishTypeKeys

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          HStack(alignment: .firstTextBaseline) {
            Text("Recipes").font(.appScreenTitle).foregroundStyle(AppColor.textPrimary)
            Spacer()
            AppPrimaryButton(title: "Add Recipe", systemImage: "plus") {
              editorRoute = RecipeEditorRoute(mode: .create)
            }
          }
          Text("Dishes you can make with what's in your fridge")
            .font(.system(size: 14)).foregroundStyle(AppColor.textTertiary)
            .padding(.bottom, 16)

          AppSearchBar(placeholder: "Search recipes and ingredients")
            .padding(.bottom, 14)
          cuisineChips
          dishChips

          if !soonItems.isEmpty {
            AppExpiringItemsBanner(
              items: soonItems,
              headline: expiringHeadline
            )
            .padding(.bottom, 26)
          }

          if !soonRecipes.isEmpty {
            AppSectionTitle(title: "Make with Expiring Ingredients", uppercase: true)
            VStack(spacing: 13) {
              ForEach(soonRecipes) { recipe in
                NavigationLink(value: recipe) { recipeSoonCard(recipe) }
                  .buttonStyle(.plain)
              }
            }
            .padding(.bottom, 26)
          }

          AppSectionTitle(title: "You Can Make Now", uppercase: true)
          VStack(spacing: 13) {
            ForEach(otherRecipes) { recipe in
              NavigationLink(value: recipe) { recipeCompactRow(recipe) }
                .buttonStyle(.plain)
            }
          }
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
      .sheet(item: $editorRoute) { route in
        RecipeEditorView(mode: route.mode)
      }
    }
  }

  // MARK: 파생

  private var filteredRecipes: [Recipe] {
    recipes.filter { recipe in
      (cuisine == Self.allKey || recipe.cuisine == cuisine)
        && (dish == Self.allKey || recipe.dishType == dish)
    }
  }

  /// 임박 재료 배너 헤드라인: 임박 물건 이름(사용자 데이터) + 현지화 권유 문구.
  private var expiringHeadline: String {
    let names = soonItems.prefix(3).map(\.name).joined(separator: " · ")
    return String(localized: "recipes.expiringHeadline.\(names)")
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
          AppFilterChip(title: cuisineFilterLabel(c), isSelected: cuisine == c) { cuisine = c }
        }
      }
    }
    .padding(.bottom, 10)
  }

  private var dishChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(dishes, id: \.self) { d in
          AppFilterChip(title: dishFilterLabel(d), isSelected: dish == d) { dish = d }
        }
      }
    }
    .padding(.bottom, 22)
  }

  /// 필터 칩 표시 라벨: allKey 는 "전체"(현지화), 그 외 raw 키는 분류 표시 라벨.
  private func cuisineFilterLabel(_ raw: String) -> String {
    raw == Self.allKey ? String(localized: "All") : RecipeClassification.cuisineLabel(raw)
  }

  private func dishFilterLabel(_ raw: String) -> String {
    raw == Self.allKey ? String(localized: "All") : RecipeClassification.dishTypeLabel(raw)
  }


  // MARK: 레시피 카드

  /// 임박 재료가 있는 레시피 카드 — 진행률 + 재료 칩.
  private func recipeSoonCard(_ recipe: Recipe) -> some View {
    let ingredients = recipe.ingredients.sorted { $0.sortOrder < $1.sortOrder }
    let soon = ingredients.filter { $0.stockStatus == .soon }
    let badge: String? = soon.isEmpty
      ? nil
      : (soon.count == 1
        ? String(localized: "recipe.expiringBadge.one.\(soon[0].name)")
        : String(localized: "recipe.expiringBadge.count.\(soon.count)"))
    let have = ingredients.filter(\.isInStock).count
    let total = ingredients.count
    let pct = total == 0 ? 0 : Double(have) / Double(total)

    return VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: recipe.title).font(.system(size: 18, weight: .bold)).foregroundStyle(AppColor.textPrimary)
          Text("recipe.minutes.\(recipe.totalMinutes ?? 0)").font(.appFootnote).foregroundStyle(AppColor.textMuted)
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
        Text("recipe.ingredientCount.\(have).\(total)")
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
        Text(verbatim: recipe.title).font(.appValueStrong).foregroundStyle(AppColor.textPrimary)
        Text("recipe.minutes.\(recipe.totalMinutes ?? 0)").font(.appFootnote).foregroundStyle(AppColor.textMuted)
      }
      Spacer()
      AppStatusPill(
        title: ready
          ? String(localized: "recipe.ready")
          : String(localized: "recipe.ingredientCount.\(have).\(total)"),
        style: ready ? .ready : .neutral
      )
    }
    .padding(EdgeInsets(top: 15, leading: 17, bottom: 15, trailing: 17))
    .appCard(radius: 18)
  }
}
