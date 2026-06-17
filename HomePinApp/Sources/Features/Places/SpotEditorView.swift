import SwiftData
import SwiftUI

/// 세부위치(Spot) 추가/편집 공용 에디터.
/// 저장 전 draft 는 SwiftData 에 넣지 않고 화면 로컬 `@State` 로만 보관한다.
struct SpotEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  private let mode: Mode

  @State private var name: String

  enum Mode {
    case create(area: Area)
    case edit(Spot)
  }

  init(mode: Mode) {
    self.mode = mode
    switch mode {
    case .create:
      _name = State(initialValue: "")
    case let .edit(spot):
      _name = State(initialValue: spot.name)
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          AppEditorNameCard(placeholder: "e.g. Freezer, Second drawer, Bottom right", text: $name, onSubmit: save)
        }
        .padding(20)
      }
      .appEditorSaveBar(title: saveTitle, isEnabled: canSave, action: save)
      .background(AppColor.screenBackground)
      .navigationTitle(title)
      .compactNavTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
    }
  }

  private var title: LocalizedStringKey {
    switch mode {
    case .create: "Add Spot"
    case .edit: "Edit Spot"
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
    case let .create(area):
      let spot = Spot(
        name: trimmedName,
        sortOrder: area.spots.count,
        area: area
      )
      modelContext.insert(spot)
    case let .edit(spot):
      spot.name = trimmedName
      spot.updatedAt = .now
    }

    dismiss()
  }
}

struct SpotEditorRoute: Identifiable {
  let id = UUID()
  let mode: SpotEditorView.Mode
}
