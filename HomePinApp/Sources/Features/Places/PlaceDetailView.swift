import SwiftData
import SwiftUI

/// 장소 상세 — 수납공간(Spot)별 물건 목록 + 직속 물건.
struct PlaceDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var editorRoute: ItemEditorRoute?
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
  }

  private var backButton: some View {
    Button(action: { dismiss() }) {
      HStack(spacing: 4) {
        Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
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
        Text("\(areaItemCount(area))개 · 수납공간 \(area.spots.count)곳")
          .font(.system(size: 13))
          .foregroundStyle(AppColor.textTertiary)
      }
      Spacer()
      AppPrimaryButton(title: "물건 추가", systemImage: "plus") {
        editorRoute = ItemEditorRoute(mode: .create(area: area))
      }
    }
  }

  private var sortedSpots: [Spot] {
    area.spots.sorted { $0.sortOrder < $1.sortOrder }
  }

  private func spotCard(title: String, items: [Item], spot: Spot?) -> some View {
    VStack(spacing: 0) {
      HStack {
        Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(AppColor.textPrimary)
        Spacer()
        Text("\(items.count)개").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppColor.textFaint)
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
            Circle().fill(Color(hex: 0xE0CDBF)).frame(width: 6, height: 6)
            Text(item.name).font(.system(size: 16)).foregroundStyle(AppColor.textPrimary)
            Spacer()
            if item.quantity > 1 {
              Text("\(item.quantity)개")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(AppColor.textMuted)
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColor.textFaint)
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
