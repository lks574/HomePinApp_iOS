import SwiftData
import SwiftUI

/// 기본 상태 관리 패턴 예시: View ↔ SwiftData 직결.
/// - 읽기: `@Query` 로 `@Model` 직접 관찰
/// - 쓰기: `@Environment(\.modelContext)` 로 직접 insert/delete
struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]

  var body: some View {
    NavigationStack {
      List {
        ForEach(items) { item in
          Text(item.title)
        }
        .onDelete(perform: delete)
      }
      .navigationTitle("HomePin")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("추가", systemImage: "plus", action: addSample)
        }
      }
      .overlay {
        if items.isEmpty {
          ContentUnavailableView(
            "항목 없음",
            systemImage: "tray",
            description: Text("오른쪽 위 + 로 추가하세요."),
          )
        }
      }
    }
  }

  private func addSample() {
    modelContext.insert(Item(title: "새 항목"))
  }

  private func delete(at offsets: IndexSet) {
    for index in offsets {
      modelContext.delete(items[index])
    }
  }
}

#Preview {
  ContentView()
    .modelContainer(for: Item.self, inMemory: true)
}
