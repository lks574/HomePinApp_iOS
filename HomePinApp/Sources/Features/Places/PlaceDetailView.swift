import SwiftData
import SwiftUI

/// 장소 상세 — 수납공간(Spot)별 물건 목록 + 직속 물건.
struct PlaceDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var editorRoute: ItemEditorRoute?
  @State private var placeEditorRoute: PlaceEditorRoute?
  @State private var spotEditorRoute: SpotEditorRoute?
  @State private var showingDeleteConfirm = false
  @State private var pendingSpotDelete: Spot?
  @State private var pendingItemDelete: Item?
  let area: Area

  /// 이 장소의 물건·세부위치를 `@Query` 로 직접 관찰한다(관계 배열 직접 읽기는
  /// insert 직후 in-memory 갱신이 보장되지 않아 추가분이 바로 반영되지 않는다).
  @Query private var items: [Item]
  @Query private var spots: [Spot]

  init(area: Area) {
    self.area = area
    let areaID = area.id
    _items = Query(
      filter: #Predicate<Item> { $0.area?.id == areaID },
      sort: \Item.createdAt
    )
    _spots = Query(
      filter: #Predicate<Spot> { $0.area?.id == areaID },
      sort: \Spot.sortOrder
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        backButton
        headerRow
          .padding(.bottom, 20)
        ForEach(spots) { spot in
          spotCard(title: spot.name, items: items(in: spot), spot: spot)
        }
        if !unassignedItems.isEmpty {
          spotCard(title: String(localized: "No Spot"), items: unassignedItems, spot: nil)
        }
      }
      .padding(20)
    }
    .background(AppColor.screenBackground)
    .hideNavBar()
    .sheet(item: $editorRoute) { route in
      ItemEditorView(mode: route.mode)
    }
    .sheet(item: $placeEditorRoute) { route in
      PlaceEditorView(mode: route.mode)
    }
    .sheet(item: $spotEditorRoute) { route in
      SpotEditorView(mode: route.mode)
    }
    .confirmationDialog(
      Text("place.delete.title.\(area.name)"),
      isPresented: $showingDeleteConfirm
    ) {
      Button("Delete", role: .destructive) { deletePlace() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("place.delete.message.\(spots.count)")
    }
    .confirmationDialog(
      Text("spot.delete.title.\(pendingSpotDelete?.name ?? "")"),
      isPresented: spotDeleteConfirmationBinding,
      presenting: pendingSpotDelete
    ) { spot in
      Button("Delete", role: .destructive) { deleteSpot(spot) }
      Button("Cancel", role: .cancel) {}
    } message: { spot in
      Text("spot.delete.message.\(items(in: spot).count)")
    }
    .confirmationDialog(
      "Delete this item?",
      isPresented: itemDeleteConfirmationBinding,
      titleVisibility: .visible,
      presenting: pendingItemDelete
    ) { item in
      Button("Delete", role: .destructive) { deleteItem(item) }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var spotDeleteConfirmationBinding: Binding<Bool> {
    Binding(
      get: { pendingSpotDelete != nil },
      set: { if !$0 { pendingSpotDelete = nil } }
    )
  }

  private var itemDeleteConfirmationBinding: Binding<Bool> {
    Binding(
      get: { pendingItemDelete != nil },
      set: { if !$0 { pendingItemDelete = nil } }
    )
  }

  private func deleteSpot(_ spot: Spot) {
    modelContext.delete(spot)
    pendingSpotDelete = nil
  }

  private func deleteItem(_ item: Item) {
    modelContext.delete(item)
    pendingItemDelete = nil
  }

  private var backButton: some View {
    Button(action: { dismiss() }) {
      HStack(spacing: 4) {
        Image(systemName: "chevron.left").font(.appRowLabel)
        Text("Places").font(.system(size: 16, weight: .semibold))
      }
      .foregroundStyle(AppColor.accent)
    }
    .buttonStyle(.plain)
    .padding(.bottom, 16)
  }

  private var headerRow: some View {
    HStack(spacing: 14) {
      AppInitialBadge(text: area.name, size: 54, fontSize: 22, radius: 16)
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: area.name)
          .font(.system(size: 30, weight: .heavy))
          .foregroundStyle(AppColor.textPrimary)
        Text("place.detail.summary.\(items.count).\(spots.count)")
          .font(.appFootnote)
          .foregroundStyle(AppColor.textTertiary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8) {
        Menu {
          Button {
            spotEditorRoute = SpotEditorRoute(mode: .create(area: area))
          } label: {
            Label("Add Spot", systemImage: "plus.square.on.square")
          }
          Button {
            placeEditorRoute = PlaceEditorRoute(mode: .edit(area))
          } label: {
            Label("Rename Place", systemImage: "pencil")
          }
          Button(role: .destructive) {
            showingDeleteConfirm = true
          } label: {
            Label("Delete Place", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppColor.textSecondary)
            .frame(width: 36, height: 36)
            .background(AppColor.card, in: Circle())
        }
        AppPrimaryButton(title: "Add Item", systemImage: "plus") {
          editorRoute = ItemEditorRoute(mode: .create(area: area))
        }
      }
    }
  }

  private func deletePlace() {
    modelContext.delete(area)
    dismiss()
  }

  private func items(in spot: Spot) -> [Item] {
    items.filter { $0.spot?.id == spot.id }
  }

  private var unassignedItems: [Item] {
    items.filter { $0.spot == nil }
  }

  private func spotCard(title: String, items: [Item], spot: Spot?) -> some View {
    VStack(spacing: 0) {
      HStack {
        Text(verbatim: title).font(.system(size: 15, weight: .bold)).foregroundStyle(AppColor.textPrimary)
        Spacer()
        Text("count.items.\(items.count)").font(.appCaptionStrong).foregroundStyle(AppColor.textFaint)
        if let spot {
          Menu {
            Button {
              spotEditorRoute = SpotEditorRoute(mode: .edit(spot))
            } label: {
              Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
              pendingSpotDelete = spot
            } label: {
              Label("Delete", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis")
              .font(.appRowLabel)
              .foregroundStyle(AppColor.textFaint)
              .frame(width: 28, height: 28)
          }
          .buttonStyle(.plain)
        }
        Button {
          editorRoute = ItemEditorRoute(mode: .create(area: area, spot: spot))
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppColor.accent)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 10)

      ForEach(items) { item in
        Button {
          editorRoute = ItemEditorRoute(mode: .edit(item))
        } label: {
          HStack(spacing: 10) {
            Circle().fill(AppColor.itemDot).frame(width: 6, height: 6)
            Text(verbatim: item.name).font(.appItemBody).foregroundStyle(AppColor.textPrimary)
            Spacer()
            if item.quantity > 1 {
              Text("count.items.\(item.quantity)")
                .font(.appCaptionStrong)
                .foregroundStyle(AppColor.textMuted)
            }
            Image(systemName: "chevron.right").font(.appTag).foregroundStyle(AppColor.textFaint)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 11)
          .overlay(alignment: .top) { Divider().padding(.leading, 16) }
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button(role: .destructive) {
            pendingItemDelete = item
          } label: {
            Label("Mark Used Up", systemImage: "checkmark.circle")
          }
        }
      }
    }
    .appCard()
    .padding(.bottom, 14)
  }
}
