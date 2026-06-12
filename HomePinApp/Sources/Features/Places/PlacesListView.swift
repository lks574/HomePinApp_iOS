import SwiftData
import SwiftUI

/// 장소(=Area) 목록. 2열 그리드, 장소별 개수·미리보기. 탭하면 상세로.
struct PlacesListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Area.sortOrder) private var areas: [Area]
  @Query private var spaces: [Space]

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
  ]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          header
          Text("\(areas.count)곳 · \(totalItemCount)개 보관 중")
            .font(.system(size: 14))
            .foregroundStyle(AppColor.textTertiary)
            .padding(.bottom, 22)

          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(areas) { area in
              NavigationLink(value: area) {
                PlaceCard(area: area)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: Area.self) { PlaceDetailView(area: $0) }
    }
  }

  private var header: some View {
    HStack(alignment: .bottom) {
      Text("장소")
        .font(.system(size: 34, weight: .heavy))
        .foregroundStyle(AppColor.textPrimary)
      Spacer()
      Button(action: addPlace) {
        HStack(spacing: 6) {
          Image(systemName: "plus").font(.system(size: 13, weight: .bold))
          Text("장소 추가").font(.system(size: 14, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(AppColor.accent, in: Capsule())
      }
      .buttonStyle(.plain)
    }
    .padding(.bottom, 4)
  }

  private var totalItemCount: Int {
    areas.reduce(0) { $0 + areaItemCount($1) }
  }

  private func addPlace() {
    let area = Area(name: "새 장소", sortOrder: areas.count, space: spaces.first)
    modelContext.insert(area)
  }
}

/// 한 장소(Area)의 물건 수 = 직속 + 하위 수납공간(Spot)의 물건.
func areaItemCount(_ area: Area) -> Int {
  area.items.count + area.spots.reduce(0) { $0 + $1.items.count }
}

private struct PlaceCard: View {
  let area: Area

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(String(area.name.prefix(1)))
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(AppColor.badgeText)
          .frame(width: 42, height: 42)
          .background(AppColor.badgeBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        Spacer()
        Text("\(areaItemCount(area))")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(AppColor.textFaint)
      }
      .padding(.bottom, 22)

      Text(area.name)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(AppColor.textPrimary)
      Text(preview)
        .font(.system(size: 12.5))
        .foregroundStyle(AppColor.textMuted)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .appCard()
  }

  private var preview: String {
    let names = (area.items + area.spots.flatMap(\.items)).map(\.name)
    return names.prefix(4).joined(separator: " · ")
  }
}
