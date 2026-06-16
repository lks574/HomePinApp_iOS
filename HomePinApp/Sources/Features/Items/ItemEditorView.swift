import SwiftData
import SwiftUI

/// 물건 추가/편집 공용 에디터. draft·저장 규칙은 `ItemEditorModel` 이 소유하고,
/// 이 View 는 레이아웃과 순수 UI 상태(포커스·picker 시트 표시)만 갖는다.
struct ItemEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Area.sortOrder) private var areas: [Area]

  @State private var model: ItemEditorModel
  private let onSaved: (() -> Void)?

  @State private var showingAreaPicker = false
  @State private var showingSpotPicker = false
  @State private var showingDeleteConfirm = false
  @FocusState private var focusedField: ItemEditorField?

  init(mode: ItemEditorModel.Mode, onSaved: (() -> Void)? = nil) {
    _model = State(initialValue: ItemEditorModel(mode: mode))
    self.onSaved = onSaved
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          basicInfoCard
          locationCard
          optionCard
          if model.isEditing {
            deleteButton
          }
        }
        .padding(20)
      }
      .appEditorSaveBar(title: model.saveTitle, isEnabled: model.canSave, action: save)
      .background(AppColor.screenBackground)
      .navigationTitle(model.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
      .sheet(isPresented: $showingAreaPicker) {
        AreaPickerSheet(areas: areas, selectedArea: $model.selectedArea, selectedSpot: $model.selectedSpot)
      }
      .sheet(isPresented: $showingSpotPicker) {
        SpotPickerSheet(area: model.selectedArea, selectedSpot: $model.selectedSpot, selectedArea: $model.selectedArea)
      }
      .onAppear {
        if model.name.isEmpty {
          focusedField = .name
        }
      }
      .confirmationDialog(
        "Delete this item?",
        isPresented: $showingDeleteConfirm,
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive) { deleteItem() }
        Button("Cancel", role: .cancel) {}
      }
    }
  }

  private var deleteButton: some View {
    Button(role: .destructive) {
      showingDeleteConfirm = true
    } label: {
      Text("Delete Item")
        .font(.appRowLabel)
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }
    .buttonStyle(.plain)
    .appCard(radius: 18)
  }

  private var basicInfoCard: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Name")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
        TextField("e.g. AA batteries", text: $model.name)
          .font(.appFieldText)
          .foregroundStyle(AppColor.textPrimary)
          .focused($focusedField, equals: .name)
      }
      .padding(16)
      Divider().padding(.leading, 16)
      HStack {
        Text("Quantity")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
        Spacer()
        Button {
          model.quantity = max(1, model.quantity - 1)
        } label: {
          Image(systemName: "minus")
            .font(.appBadge)
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.quantity > 1 ? AppColor.accent : AppColor.textFaint)
        .disabled(model.quantity <= 1)

        Text("\(model.quantity)")
          .font(.appValueStrong)
          .foregroundStyle(AppColor.textPrimary)
          .monospacedDigit()
          .frame(minWidth: 34)

        Button {
          model.quantity += 1
        } label: {
          Image(systemName: "plus")
            .font(.appBadge)
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColor.accent)
      }
      .padding(.horizontal, 16)
      .frame(height: 58)
    }
    .appEditorCard()
  }

  private var locationCard: some View {
    VStack(spacing: 0) {
      AppEditorSelectionRow(
        title: "Place",
        value: model.selectedArea?.name ?? String(localized: "Select place"),
        isPlaceholder: model.selectedArea == nil,
        action: { showingAreaPicker = true }
      )
      Divider().padding(.leading, 16)
      AppEditorSelectionRow(
        title: "Spot",
        value: model.selectedSpot?.name ?? String(localized: "None"),
        isPlaceholder: model.selectedSpot == nil,
        action: { showingSpotPicker = true }
      )
    }
    .appEditorCard()
  }

  private var optionCard: some View {
    VStack(spacing: 0) {
      Toggle(isOn: $model.hasExpiration) {
        Text("Expiration")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
      }
      .tint(AppColor.accent)
      .padding(.horizontal, 16)
      .frame(height: 58)

      if model.hasExpiration {
        Divider().padding(.leading, 16)
        DatePicker("Date", selection: $model.expiresAt, displayedComponents: .date)
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
          .padding(.horizontal, 16)
          .frame(height: 58)
      }

      Divider().padding(.leading, 16)
      VStack(alignment: .leading, spacing: 8) {
        Text("Memo")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
        TextField("Optional", text: $model.memo, axis: .vertical)
          .font(.appItemBody)
          .foregroundStyle(AppColor.textPrimary)
          .lineLimit(2...5)
          .focused($focusedField, equals: .memo)
      }
      .padding(16)
    }
    .appEditorCard()
  }

  private func save() {
    guard model.canSave else { return }
    model.save(into: modelContext)
    onSaved?()
    dismiss()
  }

  private func deleteItem() {
    model.delete(from: modelContext)
    onSaved?()
    dismiss()
  }
}

struct ItemEditorRoute: Identifiable {
  let id = UUID()
  let mode: ItemEditorModel.Mode
}

private enum ItemEditorField: Hashable {
  case name
  case memo
}

private struct AppEditorSelectionRow: View {
  let title: LocalizedStringKey
  let value: String
  var isPlaceholder = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text(title)
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
        Spacer()
        Text(verbatim: value)
          .font(.appRowLabel)
          .foregroundStyle(isPlaceholder ? AppColor.textMuted : AppColor.textSecondary)
        Image(systemName: "chevron.right")
          .font(.appTag)
          .foregroundStyle(AppColor.textFaint)
      }
      .frame(height: 58)
      .padding(.horizontal, 16)
    }
    .buttonStyle(.plain)
  }
}

private extension View {
  func appEditorCard() -> some View {
    padding(0)
      .appCard(radius: 18)
  }
}
