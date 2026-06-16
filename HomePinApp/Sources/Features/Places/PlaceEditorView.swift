import SwiftData
import SwiftUI

/// 장소(Area) 추가/편집 공용 에디터.
/// 저장 전 draft 는 SwiftData 에 넣지 않고 화면 로컬 `@State` 로만 보관한다.
struct PlaceEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Area.sortOrder) private var areas: [Area]
  @Query(sort: \Space.sortOrder) private var spaces: [Space]

  private let mode: Mode

  @State private var name: String

  enum Mode {
    case create
    case edit(Area)
  }

  init(mode: Mode) {
    self.mode = mode
    switch mode {
    case .create:
      _name = State(initialValue: "")
    case let .edit(area):
      _name = State(initialValue: area.name)
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          AppEditorNameCard(placeholder: "e.g. Kitchen, Bedroom, Balcony", text: $name, onSubmit: save)
        }
        .padding(20)
      }
      .appEditorSaveBar(title: saveTitle, isEnabled: canSave, action: save)
      .background(AppColor.screenBackground)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
    }
  }

  private var title: LocalizedStringKey {
    switch mode {
    case .create: "Add Place"
    case .edit: "Edit Place"
    }
  }

  private var saveTitle: LocalizedStringKey {
    switch mode {
    case .create: "Add"
    case .edit: "Save"
    }
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSave: Bool {
    !trimmedName.isEmpty
  }

  private func save() {
    guard canSave else { return }

    switch mode {
    case .create:
      let area = Area(
        name: trimmedName,
        sortOrder: areas.count,
        space: spaces.first
      )
      modelContext.insert(area)
    case let .edit(area):
      area.name = trimmedName
      area.updatedAt = .now
    }

    dismiss()
  }
}

struct PlaceEditorRoute: Identifiable {
  let id = UUID()
  let mode: PlaceEditorView.Mode
}
