import SwiftData
import SwiftUI

/// 장소(=Area) 목록. (스텁 — Task 4 에서 그리드·미리보기로 확장)
struct PlacesListView: View {
  @Query(sort: \Area.sortOrder) private var areas: [Area]

  var body: some View {
    NavigationStack {
      List(areas) { area in
        Text(area.name)
      }
      .navigationTitle("장소")
    }
  }
}
