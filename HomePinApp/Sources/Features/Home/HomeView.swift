import SwiftData
import SwiftUI

/// 홈 대시보드 — 임박 유통기한 + 장보기 요약 + 장소 바로가기 + 최근 추가.
struct HomeView: View {
  @Environment(AppRouter.self) private var router
  @Query(sort: \Area.sortOrder) private var areas: [Area]
  @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
  @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var shoppingItems: [ShoppingItem]
  @State private var editorRoute: ItemEditorRoute?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text("HomePin")
            .font(.appScreenTitle)
            .foregroundStyle(AppColor.textPrimary)
            .padding(.bottom, 22)

          if !expiringItems.isEmpty {
            Button {
              if let item = expiringItems.first {
                editorRoute = ItemEditorRoute(mode: .edit(item))
              }
            } label: {
              AppExpiringItemsBanner(
                items: expiringItems,
                headline: expiringItems.prefix(3).map(\.name).joined(separator: " · ")
              )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 26)
          }

          shoppingSection.padding(.bottom, 26)

          AppSectionTitle(title: "Quick Places")
          placeShortcuts.padding(.bottom, 26)

          AppSectionTitle(title: "Recently Added")
          recentList
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .hideNavBar()
      .navigationDestination(for: ShoppingDestination.self) { _ in
        ShoppingListView()
      }
      .sheet(item: $editorRoute) { route in
        ItemEditorView(mode: route.mode)
      }
    }
  }

  private var expiringItems: [Item] { items.expiringSoonByExpiry }

  private var recentItems: [Item] { Array(items.prefix(5)) }

  // MARK: 장보기 (요약 + 진입점)

  /// 미완료 장보기 항목(살 것). 홈에는 요약·상위 몇 개만 보여주고 전체는 목록 화면에서.
  private var pendingShopping: [ShoppingItem] { shoppingItems.filter { !$0.isChecked } }

  /// 장보기 요약 섹션 — 미완료 개수 + 상위 3개 미리보기, 전체 목록으로 push.
  private var shoppingSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        AppSectionTitle(title: "Shopping List")
        Spacer()
        if !pendingShopping.isEmpty {
          Text("shopping.toBuyCount.\(pendingShopping.count)")
            .font(.appCaptionStrong).foregroundStyle(AppColor.textMuted)
        }
      }
      NavigationLink(value: ShoppingDestination.list) {
        VStack(spacing: 0) {
          if pendingShopping.isEmpty {
            HStack(spacing: 12) {
              Image(systemName: "cart").font(.appTag).foregroundStyle(AppColor.textFaint)
              Text("Nothing to buy. Tap to add.")
                .font(.appItemBody).foregroundStyle(AppColor.textMuted)
              Spacer()
              Image(systemName: "chevron.right").font(.appTag).foregroundStyle(AppColor.textFaint)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
          } else {
            ForEach(pendingShopping.prefix(3)) { item in
              HStack(spacing: 12) {
                Image(systemName: "circle").font(.appTag).foregroundStyle(AppColor.textFaint)
                Text(verbatim: item.name).font(.appItemBody).foregroundStyle(AppColor.textPrimary)
                Spacer()
              }
              .padding(.horizontal, 16).padding(.vertical, 12)
              .overlay(alignment: .top) { Divider().padding(.leading, 16) }
            }
          }
        }
        .appCard()
      }
      .buttonStyle(.plain)
    }
  }

  private var placeShortcuts: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(areas) { area in
          Button {
            router.openPlace(area)
          } label: {
            VStack(spacing: 6) {
              AppInitialBadge(text: area.name, size: 50, radius: 14)
              Text(verbatim: area.name).font(.appCaptionStrong).foregroundStyle(AppColor.textSecondary)
            }
          }
          .buttonStyle(.plain)
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
              Text(verbatim: item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(AppColor.textPrimary)
              if !item.locationPath.isEmpty {
                Text(verbatim: item.locationPath).font(.appCaption).foregroundStyle(AppColor.textMuted)
              }
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.appTag)
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

/// 홈 → 장보기 목록 push 목적지. 단일 케이스라도 `navigationDestination(for:)` 의
/// 값 기반 라우팅을 위해 `Hashable` 타입으로 둔다.
enum ShoppingDestination: Hashable {
  case list
}
