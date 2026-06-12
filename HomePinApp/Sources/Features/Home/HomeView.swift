import SwiftData
import SwiftUI

/// 홈 — 스플래시 다음의 메인 화면. 현재는 공간(Space) 목록(임시).
/// 상태 관리 기본 패턴(View ↔ SwiftData 직결): 읽기 `@Query`, 쓰기 `modelContext`.
struct HomeView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Space.sortOrder) private var spaces: [Space]

  var body: some View {
    NavigationStack {
      List {
        ForEach(spaces) { space in
          Label(space.name, systemImage: space.icon ?? "house")
        }
        .onDelete(perform: deleteSpaces)
      }
      .navigationTitle("홈")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("추가", systemImage: "plus", action: addSpace)
        }
      }
      .overlay {
        if spaces.isEmpty {
          ContentUnavailableView(
            "공간 없음",
            systemImage: "house",
            description: Text("오른쪽 위 + 로 공간을 추가하세요."),
          )
        }
      }
    }
  }

  private func addSpace() {
    modelContext.insert(Space(name: "새 공간", sortOrder: spaces.count))
  }

  private func deleteSpaces(at offsets: IndexSet) {
    for index in offsets {
      modelContext.delete(spaces[index])
    }
  }
}

#Preview {
  HomeView()
    .modelContainer(for: Space.self, inMemory: true)
}
