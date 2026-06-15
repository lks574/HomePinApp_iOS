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
  @FocusState private var focusedField: ItemEditorField?

  init(mode: ItemEditorModel.Mode, onSaved: (() -> Void)? = nil) {
    _model = State(initialValue: ItemEditorModel(mode: mode))
    self.onSaved = onSaved
  }

  var body: some View {
    @Bindable var model = model
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          basicInfoCard
          locationCard
          optionCard
        }
        .padding(20)
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        AppFullWidthPrimaryButton(title: model.saveTitle, isEnabled: model.canSave, action: save)
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 16)
          .background(.regularMaterial)
      }
      .background(AppColor.screenBackground)
      .navigationTitle(model.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("닫기") { dismiss() }
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
    }
  }

  private var basicInfoCard: some View {
    @Bindable var model = model
    return VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text("이름")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.textPrimary)
        TextField("예: AA 건전지", text: $model.name)
          .font(.system(size: 17))
          .foregroundStyle(AppColor.textPrimary)
          .focused($focusedField, equals: .name)
      }
      .padding(16)
      Divider().padding(.leading, 16)
      HStack {
        Text("수량")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.textPrimary)
        Spacer()
        Button {
          model.quantity = max(1, model.quantity - 1)
        } label: {
          Image(systemName: "minus")
            .font(.system(size: 13, weight: .bold))
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.quantity > 1 ? AppColor.accent : AppColor.textFaint)
        .disabled(model.quantity <= 1)

        Text("\(model.quantity)")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(AppColor.textPrimary)
          .monospacedDigit()
          .frame(minWidth: 34)

        Button {
          model.quantity += 1
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 13, weight: .bold))
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
        title: "장소",
        value: model.selectedArea?.name ?? "장소 선택",
        isPlaceholder: model.selectedArea == nil,
        action: { showingAreaPicker = true }
      )
      Divider().padding(.leading, 16)
      AppEditorSelectionRow(
        title: "세부위치",
        value: model.selectedSpot?.name ?? "선택 안 함",
        isPlaceholder: model.selectedSpot == nil,
        action: { showingSpotPicker = true }
      )
    }
    .appEditorCard()
  }

  private var optionCard: some View {
    @Bindable var model = model
    return VStack(spacing: 0) {
      Toggle(isOn: $model.hasExpiration) {
        Text("유통기한")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.textPrimary)
      }
      .tint(AppColor.accent)
      .padding(.horizontal, 16)
      .frame(height: 58)

      if model.hasExpiration {
        Divider().padding(.leading, 16)
        DatePicker("날짜", selection: $model.expiresAt, displayedComponents: .date)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.textPrimary)
          .padding(.horizontal, 16)
          .frame(height: 58)
      }

      Divider().padding(.leading, 16)
      VStack(alignment: .leading, spacing: 8) {
        Text("메모")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.textPrimary)
        TextField("선택 입력", text: $model.memo, axis: .vertical)
          .font(.system(size: 16))
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
  let title: String
  let value: String
  var isPlaceholder = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Text(title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.textPrimary)
        Spacer()
        Text(value)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(isPlaceholder ? AppColor.textMuted : AppColor.textSecondary)
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
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
