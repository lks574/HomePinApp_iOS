import SwiftData
import SwiftUI

/// 장보기 목록 — 수동 추가 + 체크 시 재고 반영 + 삭제. View ↔ SwiftData 직결
/// (`@Query` 읽기, `modelContext` 쓰기). 미완료 항목을 위에, 완료 항목을 아래에 둔다.
/// 홈의 요약 섹션(`HomeView.shoppingSection`)에서 `ShoppingDestination` push 로 진입한다.
struct ShoppingListView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AdService.self) private var adService
  @Query(sort: \Item.name) private var items: [Item]
  @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var shoppingItems: [ShoppingItem]
  @State private var newItemName = ""
  @State private var stockRoute: ShoppingStockRoute?
  /// 이번 화면 표시(세션) 동안 사용자가 새로 완료(체크)한 항목 수. 화면 재진입 시 0 으로
  /// 리셋된다(`onAppear`). 세션 완료 전면 트리거의 임계(≥1) 판정에 쓰는 비영속 로컬 상태.
  @State private var newlyCompletedThisSession = 0
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
    .compactNavTitle()
    .sheet(item: $stockRoute) { route in
      ItemEditorView(mode: .create(initialName: route.shoppingItem.name), onSaved: {
        // 신규 재고 항목을 만들어 재고에 반영했으므로 가산 완료로 표시한다(재체크 이중 가산 방지).
        route.shoppingItem.isChecked = true
        route.shoppingItem.stockCredited = true
        newlyCompletedThisSession += 1
      }, onSavedItem: { item in
        route.shoppingItem.sourceIngredient?.item = item
      })
    }
    .onAppear { newlyCompletedThisSession = 0 }
    .onDisappear {
      // 장보기 "세션 완료" 암묵 트리거: 이번 세션에 신규 완료(체크)가 1개 이상 있었고
      // 화면을 벗어날 때만 전면 광고를 적격 시도한다(0개 완료 후 단순 이탈은 트리거 금지).
      // best-effort — 미로드/캡 미통과면 AdService 가 조용히 skip 한다.
      guard newlyCompletedThisSession >= 1 else { return }
      adService.showInterstitialIfEligible(trigger: .shoppingSessionCompleted)
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
      // 체크 해제는 재고를 차감하지 않고 장보기 상태만 되돌린다(의도된 비대칭). 단,
      // 이미 가산됐다는 사실(`stockCredited`)은 유지해 재체크 시 이중 가산을 막는다.
      shoppingItem.isChecked = false
      return
    }
    // 이미 한 번 재고에 반영된 항목은 재체크 시 가산하지 않고 상태만 되돌린다.
    if shoppingItem.stockCredited {
      shoppingItem.isChecked = true
      newlyCompletedThisSession += 1
      return
    }
    if let item = matchingItem(for: shoppingItem) {
      item.quantity += max(1, shoppingItem.quantity ?? 1)
      item.updatedAt = .now
      shoppingItem.sourceIngredient?.item = item
      shoppingItem.isChecked = true
      shoppingItem.stockCredited = true
      newlyCompletedThisSession += 1
    } else {
      // 재고 항목 생성 시트로 진입. 실제 완료 카운트는 시트의 onSaved 에서 가산한다.
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
