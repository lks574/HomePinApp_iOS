import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 물건 추가/편집 공용 에디터. draft·저장 규칙은 `ItemEditorModel` 이 소유하고,
/// 이 View 는 레이아웃과 순수 UI 상태(포커스·picker 시트 표시)만 갖는다.
struct ItemEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Area.sortOrder) private var areas: [Area]
  @Query(sort: \Spot.name) private var spots: [Spot]
  @Query(sort: \ItemCategory.sortOrder) private var categories: [ItemCategory]
  @Query(sort: \Tag.name) private var tags: [Tag]

  /// 직전 추가 위치(다음 추가 기본값으로 prefill). UUID 문자열로 저장한다.
  @AppStorage("lastAreaID") private var lastAreaID = ""
  @AppStorage("lastSpotID") private var lastSpotID = ""

  @State private var model: ItemEditorModel
  private let onSaved: (() -> Void)?
  private let onSavedItem: ((Item) -> Void)?

  @State private var showingAreaPicker = false
  @State private var showingSpotPicker = false
  @State private var showingCategoryPicker = false
  @State private var showingTagPicker = false
  @State private var showingPhotoPicker = false
  @State private var showingDeleteConfirm = false
  @State private var photoItem: PhotosPickerItem?
  @FocusState private var focusedField: ItemEditorField?

  init(mode: ItemEditorModel.Mode, onSaved: (() -> Void)? = nil, onSavedItem: ((Item) -> Void)? = nil) {
    _model = State(initialValue: ItemEditorModel(mode: mode))
    self.onSaved = onSaved
    self.onSavedItem = onSavedItem
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          basicInfoCard
          photoCard
          locationCard
          taxonomyCard
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
      .sheet(isPresented: $showingCategoryPicker) {
        ItemCategoryPickerSheet(categories: categories, selectedCategory: $model.selectedCategory)
      }
      .sheet(isPresented: $showingTagPicker) {
        ItemTagPickerSheet(tags: tags, selectedTags: $model.selectedTags)
      }
      .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
      .onChange(of: photoItem) { _, newItem in
        loadPickedPhoto(newItem)
      }
      .onAppear {
        prefillLastLocationIfNeeded()
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
        Button(action: decrementQuantity) {
          Image(systemName: "minus")
            .font(.appBadge)
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.canDeleteAtMinimumQuantity ? .red : AppColor.accent)
        .disabled(model.quantity <= 1 && !model.canDeleteAtMinimumQuantity)

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

  private var photoCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Photo")
          .font(.appRowLabel)
          .foregroundStyle(AppColor.textPrimary)
        Spacer()
        Button(model.photoData == nil ? "Choose Photo" : "Change Photo") {
          showingPhotoPicker = true
        }
        .font(.appRowLabel)
        .foregroundStyle(AppColor.accent)
      }

      if let image = selectedImage {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(maxWidth: .infinity)
          .frame(height: 170)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        Button(role: .destructive) {
          model.photoData = nil
          photoItem = nil
        } label: {
          Text("Remove Photo")
            .font(.appCaptionStrong)
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
      } else {
        Button {
          showingPhotoPicker = true
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "photo")
              .font(.appItemBody)
              .foregroundStyle(AppColor.textFaint)
            Text("No photo")
              .font(.appItemBody)
              .foregroundStyle(AppColor.textMuted)
            Spacer()
          }
          .frame(height: 56)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(16)
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

  private var taxonomyCard: some View {
    VStack(spacing: 0) {
      AppEditorSelectionRow(
        title: "Category",
        value: model.selectedCategory?.name ?? String(localized: "Uncategorized"),
        isPlaceholder: model.selectedCategory == nil,
        action: { showingCategoryPicker = true }
      )
      Divider().padding(.leading, 16)
      AppEditorSelectionRow(
        title: "Tags",
        value: tagSummary,
        isPlaceholder: model.selectedTags.isEmpty,
        action: { showingTagPicker = true }
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

  private var selectedImage: UIImage? {
    guard let data = model.photoData else { return nil }
    return UIImage(data: data)
  }

  private var tagSummary: String {
    guard !model.selectedTags.isEmpty else {
      return String(localized: "No tags")
    }
    return model.selectedTags
      .sorted { $0.name < $1.name }
      .map(\.name)
      .joined(separator: ", ")
  }

  private func save() {
    guard model.canSave else { return }
    let item = model.save(into: modelContext)
    if let item {
      rememberLastLocation(of: item)
      onSavedItem?(item)
    }
    onSaved?()
    dismiss()
  }

  /// create 모드에서 위치가 비어 있으면 직전 추가 위치를 기본값으로 채운다. 저장된 id 가
  /// 삭제된 위치를 가리키면 fetch 가 nil 이라 무시한다(안전 폴백). 위치 불변식 유지.
  private func prefillLastLocationIfNeeded() {
    guard case .create = model.mode else { return }
    guard model.selectedArea == nil, model.selectedSpot == nil else { return }
    if let spotID = UUID(uuidString: lastSpotID),
       let spot = spots.first(where: { $0.id == spotID }) {
      model.selectedSpot = spot
      model.selectedArea = spot.area
      return
    }
    if let areaID = UUID(uuidString: lastAreaID),
       let area = areas.first(where: { $0.id == areaID }) {
      model.selectedArea = area
    }
  }

  /// 저장 성공 시 위치를 직전 위치로 기록한다(세부위치 없으면 비운다).
  private func rememberLastLocation(of item: Item) {
    lastAreaID = item.area?.id.uuidString ?? ""
    lastSpotID = item.spot?.id.uuidString ?? ""
  }

  private func deleteItem() {
    model.delete(from: modelContext)
    onSaved?()
    dismiss()
  }

  private func decrementQuantity() {
    if model.quantity > 1 {
      model.quantity -= 1
    } else if model.canDeleteAtMinimumQuantity {
      showingDeleteConfirm = true
    }
  }

  private func loadPickedPhoto(_ item: PhotosPickerItem?) {
    guard let item else { return }
    Task {
      let data = try? await item.loadTransferable(type: Data.self)
      await MainActor.run {
        if let data {
          model.photoData = data
        }
        photoItem = nil
      }
    }
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
