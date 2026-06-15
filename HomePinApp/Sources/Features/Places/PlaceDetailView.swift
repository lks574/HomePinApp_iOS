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
  let area: Area

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        backButton
        headerRow
        AppSearchBar(placeholder: "\(area.name)에서 찾기", style: .field)
          .padding(.vertical, 20)
        ForEach(sortedSpots) { spot in
          spotCard(title: spot.name, items: spot.items, spot: spot)
        }
        if !area.items.isEmpty {
          spotCard(title: "수납공간 미지정", items: area.items, spot: nil)
        }
      }
      .padding(20)
    }
    .background(AppColor.screenBackground)
    .toolbar(.hidden, for: .navigationBar)
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
      "‘\(area.name)’ 장소를 삭제할까요?",
      isPresented: $showingDeleteConfirm
    ) {
      Button("삭제", role: .destructive) { deletePlace() }
      Button("취소", role: .cancel) {}
    } message: {
      Text("수납공간 \(area.spots.count)곳도 함께 삭제됩니다. 보관 중인 물건은 삭제되지 않고 위치만 해제됩니다.")
    }
    .confirmationDialog(
      "‘\(pendingSpotDelete?.name ?? "")’ 세부위치를 삭제할까요?",
      isPresented: spotDeleteConfirmationBinding,
      presenting: pendingSpotDelete
    ) { spot in
      Button("삭제", role: .destructive) { deleteSpot(spot) }
      Button("취소", role: .cancel) {}
    } message: { spot in
      Text("보관 중인 물건 \(spot.items.count)개는 삭제되지 않고 ‘수납공간 미지정’ 으로 이동합니다.")
    }
  }

  private var spotDeleteConfirmationBinding: Binding<Bool> {
    Binding(
      get: { pendingSpotDelete != nil },
      set: { if !$0 { pendingSpotDelete = nil } }
    )
  }

  private func deleteSpot(_ spot: Spot) {
    modelContext.delete(spot)
    pendingSpotDelete = nil
  }

  private var backButton: some View {
    Button(action: { dismiss() }) {
      HStack(spacing: 4) {
        Image(systemName: "chevron.left").font(.appRowLabel)
        Text("장소").font(.system(size: 16, weight: .semibold))
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
        Text(area.name)
          .font(.system(size: 30, weight: .heavy))
          .foregroundStyle(AppColor.textPrimary)
        Text("\(area.itemCount)개 · 수납공간 \(area.spots.count)곳")
          .font(.appFootnote)
          .foregroundStyle(AppColor.textTertiary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8) {
        Menu {
          Button {
            spotEditorRoute = SpotEditorRoute(mode: .create(area: area))
          } label: {
            Label("세부위치 추가", systemImage: "plus.square.on.square")
          }
          Button {
            placeEditorRoute = PlaceEditorRoute(mode: .edit(area))
          } label: {
            Label("장소 이름 수정", systemImage: "pencil")
          }
          Button(role: .destructive) {
            showingDeleteConfirm = true
          } label: {
            Label("장소 삭제", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppColor.textSecondary)
            .frame(width: 36, height: 36)
            .background(AppColor.card, in: Circle())
        }
        AppPrimaryButton(title: "물건 추가", systemImage: "plus") {
          editorRoute = ItemEditorRoute(mode: .create(area: area))
        }
      }
    }
  }

  private func deletePlace() {
    modelContext.delete(area)
    dismiss()
  }

  private var sortedSpots: [Spot] {
    area.spots.sorted { $0.sortOrder < $1.sortOrder }
  }

  private func spotCard(title: String, items: [Item], spot: Spot?) -> some View {
    VStack(spacing: 0) {
      HStack {
        Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(AppColor.textPrimary)
        Spacer()
        Text("\(items.count)개").font(.appCaptionStrong).foregroundStyle(AppColor.textFaint)
        if let spot {
          Menu {
            Button {
              spotEditorRoute = SpotEditorRoute(mode: .edit(spot))
            } label: {
              Label("이름 수정", systemImage: "pencil")
            }
            Button(role: .destructive) {
              pendingSpotDelete = spot
            } label: {
              Label("삭제", systemImage: "trash")
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
            Text(item.name).font(.appItemBody).foregroundStyle(AppColor.textPrimary)
            Spacer()
            if item.quantity > 1 {
              Text("\(item.quantity)개")
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
      }
    }
    .appCard()
    .padding(.bottom, 14)
  }
}
