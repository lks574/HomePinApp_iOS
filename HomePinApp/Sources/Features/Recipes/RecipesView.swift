import SwiftData
import SwiftUI

/// 레시피 목록. (스텁 — Task 6 에서 임박 카드·재료칩·진행바로 확장)
struct RecipesView: View {
  @Query(sort: \Recipe.title) private var recipes: [Recipe]

  var body: some View {
    NavigationStack {
      List(recipes) { recipe in
        Text(recipe.title)
      }
      .navigationTitle("레시피")
    }
  }
}
