import SwiftData
import SwiftUI

/// 홈 대시보드 — 검색 + 임박 유통기한 + 장소 바로가기 + 최근 추가.
struct HomeView: View {
  @Query(sort: \Area.sortOrder) private var areas: [Area]
  @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
  @State private var editorRoute: ItemEditorRoute?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text("HomePin")
            .font(.system(size: 34, weight: .heavy))
            .foregroundStyle(AppColor.textPrimary)
            .padding(.bottom, 14)

          AppSearchBar(placeholder: "무엇을 찾으세요?")
            .padding(.bottom, 22)

          if !expiringItems.isEmpty {
            expiringCard.padding(.bottom, 26)
          }

          AppSectionTitle(title: "장소 바로가기")
          placeShortcuts.padding(.bottom, 26)

          AppSectionTitle(title: "최근 추가")
          recentList
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .toolbar(.hidden, for: .navigationBar)
      .sheet(item: $editorRoute) { route in
        ItemEditorView(mode: route.mode)
      }
    }
  }

  private var expiringItems: [Item] {
    items.filter(\.isExpiringSoon)
      .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
  }

  private var recentItems: [Item] { Array(items.prefix(5)) }

  private var expiringCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("유통기한 임박 \(expiringItems.count)가지")
        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: 0xF6DDD0))
      Text(expiringItems.prefix(3).map(\.name).joined(separator: " · "))
        .font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
      HStack(spacing: 6) {
        ForEach(expiringItems.prefix(3)) { item in
          Text("\(item.name) D-\(max(item.daysUntilExpiry ?? 0, 0))")
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.white.opacity(0.22), in: Capsule())
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(colors: [AppColor.accent, AppColor.accentDark], startPoint: .topLeading, endPoint: .bottomTrailing),
      in: RoundedRectangle(cornerRadius: 20, style: .continuous)
    )
  }

  private var placeShortcuts: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(areas) { area in
          VStack(spacing: 6) {
            AppInitialBadge(text: area.name, size: 50, radius: 14)
            Text(area.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppColor.textSecondary)
          }
        }
      }
    }
  }

  private var recentList: some View {
    VStack(spacing: 0) {
      ForEach(recentItems) { item in
        Button {
          editorRoute = ItemEditorRoute(mode: .edit(item))
        } label: {
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
              Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(AppColor.textPrimary)
              if !item.locationPath.isEmpty {
                Text(item.locationPath).font(.system(size: 12.5)).foregroundStyle(AppColor.textMuted)
              }
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(AppColor.textFaint)
          }
          .padding(.horizontal, 16).padding(.vertical, 12)
          .overlay(alignment: .top) { Divider().padding(.leading, 16) }
        }
        .buttonStyle(.plain)
      }
    }
    .appCard()
  }
}
