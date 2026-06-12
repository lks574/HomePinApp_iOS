import SwiftData
import SwiftUI

/// 임시 루트 화면. 상태 관리 기본 패턴(View ↔ SwiftData 직결) 예시:
/// - 읽기: `@Query` 로 공간(Space) 직접 관찰
/// - 쓰기: `modelContext` 로 직접 insert/delete
/// 실제 화면이 생기면 교체한다.
struct ContentView: View {
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
      .navigationTitle("공간")
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
  ContentView()
    .modelContainer(for: Space.self, inMemory: true)
}
