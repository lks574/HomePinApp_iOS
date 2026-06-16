import SwiftData
import SwiftUI

/// 장보기 목록 — 수동 추가 + 체크 시 재고 반영 + 삭제. View ↔ SwiftData 직결
/// (`@Query` 읽기, `modelContext` 쓰기). 미완료 항목을 위에, 완료 항목을 아래에 둔다.
/// 홈의 요약 섹션(`HomeView.shoppingSection`)에서 `ShoppingDestination` push 로 진입한다.
struct ShoppingListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Item.name) private var items: [Item]
  @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var shoppingItems: [ShoppingItem]
  @State private var newItemName = ""
  @State private var stockRoute: ShoppingStockRoute?
  @FocusState private var addFieldFocused: Bool

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        addRow
        if shoppingItems.isEmpty {
          emptyState
        } else {
          if !pending.isEmpty {
            section(title: "To Buy", items: pending)
          }
          if !done.isEmpty {
            section(title: "Done", items: done)
          }
        }
      }
      .padding(20)
    }
    .background(AppColor.screenBackground)
    .navigationTitle(Text("Shopping List"))
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $stockRoute) { route in
      ItemEditorView(mode: .create(initialName: route.shoppingItem.name), onSaved: {
        route.shoppingItem.isChecked = true
      }, onSavedItem: { item in
        route.shoppingItem.sourceIngredient?.item = item
      })
    }
  }

  // MARK: 추가

  private var addRow: some View {
    HStack(spacing: 10) {
      TextField("Add something to buy", text: $newItemName)
        .font(.appFieldText)
        .focused($addFieldFocused)
        .submitLabel(.done)
        .onSubmit(addItem)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppColor.fieldBackground)
        )
      AppPrimaryButton(title: "Add", systemImage: "plus", isEnabled: canAdd, action: addItem)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 6) {
      Text("Nothing to buy yet.")
        .font(.appRowLabel).foregroundStyle(AppColor.textSecondary)
      Text("Add items you need to pick up.")
        .font(.appFootnote).foregroundStyle(AppColor.textMuted)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  // MARK: 섹션

  private func section(title: LocalizedStringKey, items: [ShoppingItem]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      AppSectionTitle(title: title, uppercase: true)
      VStack(spacing: 0) {
        ForEach(items) { item in
          row(item)
        }
      }
      .appCard()
    }
  }

  private func row(_ item: ShoppingItem) -> some View {
    HStack(spacing: 12) {
      Button {
        toggle(item)
      } label: {
        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22))
          .foregroundStyle(item.isChecked ? AppColor.accent : AppColor.textFaint)
      }
      .buttonStyle(.plain)
      Text(verbatim: item.name)
        .font(.appItemBody)
        .foregroundStyle(item.isChecked ? AppColor.textMuted : AppColor.textPrimary)
        .strikethrough(item.isChecked, color: AppColor.textMuted)
      Spacer()
      Button(role: .destructive) {
        modelContext.delete(item)
      } label: {
        Image(systemName: "trash").font(.appTag).foregroundStyle(AppColor.textFaint)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .overlay(alignment: .top) { Divider().padding(.leading, 16) }
  }

  // MARK: 파생 / 로직

  private var pending: [ShoppingItem] { shoppingItems.filter { !$0.isChecked } }

  private var done: [ShoppingItem] { shoppingItems.filter(\.isChecked) }

  private var canAdd: Bool {
    !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func addItem() {
    let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }
    modelContext.insert(ShoppingItem(name: name))
    newItemName = ""
    addFieldFocused = true
  }

  private func toggle(_ shoppingItem: ShoppingItem) {
    if shoppingItem.isChecked {
      shoppingItem.isChecked = false
      return
    }
    if let item = matchingItem(for: shoppingItem) {
      item.quantity += max(1, shoppingItem.quantity ?? 1)
      item.updatedAt = .now
      shoppingItem.sourceIngredient?.item = item
      shoppingItem.isChecked = true
    } else {
      stockRoute = ShoppingStockRoute(shoppingItem: shoppingItem)
    }
  }

  private func matchingItem(for shoppingItem: ShoppingItem) -> Item? {
    items.first { item in
      item.normalizedName == shoppingItem.normalizedName
    }
  }
}

private struct ShoppingStockRoute: Identifiable {
  let id = UUID()
  let shoppingItem: ShoppingItem
}
