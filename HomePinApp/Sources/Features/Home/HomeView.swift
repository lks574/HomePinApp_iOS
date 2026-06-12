import SwiftData
import SwiftUI

/// 홈 대시보드 — 검색 + 임박 유통기한 + 장소 바로가기 + 최근 추가.
struct HomeView: View {
  @Query(sort: \Area.sortOrder) private var areas: [Area]
  @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text("HomePin")
            .font(.system(size: 34, weight: .heavy))
            .foregroundStyle(AppColor.textPrimary)
            .padding(.bottom, 14)

          searchBar.padding(.bottom, 22)

          if !expiringItems.isEmpty {
            expiringCard.padding(.bottom, 26)
          }

          sectionTitle("장소 바로가기")
          placeShortcuts.padding(.bottom, 26)

          sectionTitle("최근 추가")
          recentList
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .toolbar(.hidden, for: .navigationBar)
    }
  }

  private var expiringItems: [Item] {
    items.filter(\.isExpiringSoon)
      .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
  }

  private var recentItems: [Item] { Array(items.prefix(5)) }

  private func sectionTitle(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 13, weight: .bold))
      .foregroundStyle(AppColor.textTertiary)
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var searchBar: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass").foregroundStyle(AppColor.textMuted)
      Text("무엇을 찾으세요?").foregroundStyle(AppColor.textMuted)
      Spacer()
    }
    .font(.system(size: 16))
    .padding(.horizontal, 15).frame(height: 48)
    .appCard(radius: 14)
  }

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
            Text(String(area.name.prefix(1)))
              .font(.system(size: 17, weight: .bold))
              .foregroundStyle(AppColor.badgeText)
              .frame(width: 50, height: 50)
              .background(AppColor.badgeBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(area.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppColor.textSecondary)
          }
        }
      }
    }
  }

  private var recentList: some View {
    VStack(spacing: 0) {
      ForEach(recentItems) { item in
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 2) {
            Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(AppColor.textPrimary)
            if !item.locationPath.isEmpty {
              Text(item.locationPath).font(.system(size: 12.5)).foregroundStyle(AppColor.textMuted)
            }
          }
          Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay(alignment: .top) { Divider().padding(.leading, 16) }
      }
    }
    .appCard()
  }
}
