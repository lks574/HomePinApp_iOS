import SwiftData
import SwiftUI

/// 세부위치(Spot) 추가/편집 공용 에디터.
/// 저장 전 draft 는 SwiftData 에 넣지 않고 화면 로컬 `@State` 로만 보관한다.
struct SpotEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  private let mode: Mode

  @State private var name: String
  @FocusState private var nameFocused: Bool

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
          nameCard
        }
        .padding(20)
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        AppFullWidthPrimaryButton(title: saveTitle, isEnabled: canSave, action: save)
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 16)
          .background(.regularMaterial)
      }
      .background(AppColor.screenBackground)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("닫기") { dismiss() }
        }
      }
      .onAppear { nameFocused = true }
    }
  }

  private var nameCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("이름")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(AppColor.textPrimary)
      TextField("예: 냉동실, 두번째 서랍, 우측 하단", text: $name)
        .font(.system(size: 17))
        .foregroundStyle(AppColor.textPrimary)
        .focused($nameFocused)
        .submitLabel(.done)
        .onSubmit(save)
    }
    .padding(16)
    .appCard(radius: 18)
  }

  private var title: String {
    switch mode {
    case .create: "세부위치 추가"
    case .edit: "세부위치 편집"
    }
  }

  private var saveTitle: String {
    switch mode {
    case .create: "추가"
    case .edit: "저장"
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
