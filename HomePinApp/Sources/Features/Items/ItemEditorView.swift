import SwiftData
import SwiftUI

/// 물건 추가/편집 공용 에디터.
/// 저장 전 draft 는 SwiftData 에 넣지 않고 화면 로컬 `@State` 로만 보관한다.
struct ItemEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Area.sortOrder) private var areas: [Area]

  private let mode: Mode
  private let onSaved: (() -> Void)?

  @State private var name: String
  @State private var quantity: Int
  @State private var selectedArea: Area?
  @State private var selectedSpot: Spot?
  @State private var hasExpiration: Bool
  @State private var expiresAt: Date
  @State private var memo: String
  @State private var showingAreaPicker = false
  @State private var showingSpotPicker = false
  @FocusState private var focusedField: ItemEditorField?

  enum Mode {
    case create(initialName: String = "", area: Area? = nil, spot: Spot? = nil)
    case edit(Item)
  }

  init(mode: Mode, onSaved: (() -> Void)? = nil) {
    self.mode = mode
    self.onSaved = onSaved

    switch mode {
    case let .create(initialName, area, spot):
      _name = State(initialValue: initialName)
      _quantity = State(initialValue: 1)
      _selectedArea = State(initialValue: spot?.area ?? area)
      _selectedSpot = State(initialValue: spot)
      _hasExpiration = State(initialValue: false)
      _expiresAt = State(initialValue: .now)
      _memo = State(initialValue: "")
    case let .edit(item):
      _name = State(initialValue: item.name)
      _quantity = State(initialValue: item.quantity)
      _selectedArea = State(initialValue: item.area)
      _selectedSpot = State(initialValue: item.spot)
      _hasExpiration = State(initialValue: item.expiresAt != nil)
      _expiresAt = State(initialValue: item.expiresAt ?? .now)
      _memo = State(initialValue: item.memo ?? "")
    }
  }

  var body: some View {
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
      .sheet(isPresented: $showingAreaPicker) {
        AreaPickerSheet(areas: areas, selectedArea: $selectedArea, selectedSpot: $selectedSpot)
      }
      .sheet(isPresented: $showingSpotPicker) {
        SpotPickerSheet(area: selectedArea, selectedSpot: $selectedSpot, selectedArea: $selectedArea)
      }
      .onAppear {
        if name.isEmpty {
          focusedField = .name
        }
      }
    }
  }

  private var basicInfoCard: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text("이름")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.textPrimary)
        TextField("예: AA 건전지", text: $name)
          .font(.system(size: 17))
          .foregroundStyle(AppColor.textPrimary)
          .focused($focusedField, equals: .name)
      }
      .padding(16)
      Divider().padding(.leading, 16)
      quantityRow
    }
    .appEditorCard()
  }

  private var quantityRow: some View {
    HStack {
      Text("수량")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(AppColor.textPrimary)
      Spacer()
      Button {
        quantity = max(1, quantity - 1)
      } label: {
        Image(systemName: "minus")
          .font(.system(size: 13, weight: .bold))
          .frame(width: 34, height: 34)
      }
      .buttonStyle(.plain)
      .foregroundStyle(quantity > 1 ? AppColor.accent : AppColor.textFaint)
      .disabled(quantity <= 1)

      Text("\(quantity)")
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(AppColor.textPrimary)
        .monospacedDigit()
        .frame(minWidth: 34)

      Button {
        quantity += 1
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

  private var locationCard: some View {
    VStack(spacing: 0) {
      AppEditorSelectionRow(
        title: "장소",
        value: selectedArea?.name ?? "장소 선택",
        isPlaceholder: selectedArea == nil,
        action: { showingAreaPicker = true }
      )
      Divider().padding(.leading, 16)
      AppEditorSelectionRow(
        title: "세부위치",
        value: selectedSpot?.name ?? "선택 안 함",
        isPlaceholder: selectedSpot == nil,
        action: { showingSpotPicker = true }
      )
    }
    .appEditorCard()
  }

  private var optionCard: some View {
    VStack(spacing: 0) {
      Toggle(isOn: $hasExpiration) {
        Text("유통기한")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(AppColor.textPrimary)
      }
      .tint(AppColor.accent)
      .padding(.horizontal, 16)
      .frame(height: 58)

      if hasExpiration {
        Divider().padding(.leading, 16)
        DatePicker("날짜", selection: $expiresAt, displayedComponents: .date)
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
        TextField("선택 입력", text: $memo, axis: .vertical)
          .font(.system(size: 16))
          .foregroundStyle(AppColor.textPrimary)
          .lineLimit(2...5)
          .focused($focusedField, equals: .memo)
      }
      .padding(16)
    }
    .appEditorCard()
  }

  private var title: String {
    switch mode {
    case .create: "물건 추가"
    case .edit: "물건 편집"
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

  private var trimmedMemo: String? {
    let value = memo.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  private var canSave: Bool {
    !trimmedName.isEmpty && selectedArea != nil && quantity > 0
  }

  private func save() {
    guard canSave else { return }
    let area = selectedSpot?.area ?? selectedArea

    switch mode {
    case .create:
      modelContext.insert(
        Item(
          name: trimmedName,
          quantity: quantity,
          memo: trimmedMemo,
          expiresAt: hasExpiration ? expiresAt : nil,
          area: area,
          spot: selectedSpot
        )
      )
    case let .edit(item):
      item.name = trimmedName
      item.normalizedName = Item.normalize(trimmedName)
      item.quantity = quantity
      item.area = area
      item.spot = selectedSpot
      item.expiresAt = hasExpiration ? expiresAt : nil
      item.memo = trimmedMemo
      item.updatedAt = .now
    }

    onSaved?()
    dismiss()
  }
}

struct ItemEditorRoute: Identifiable {
  let id = UUID()
  let mode: ItemEditorView.Mode
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
