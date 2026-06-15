import SwiftData
import SwiftUI

/// 장소(=Area) 목록. 2열 그리드, 장소별 개수·미리보기. 탭하면 상세로.
struct PlacesListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Area.sortOrder) private var areas: [Area]

  @State private var editorRoute: PlaceEditorRoute?
  @State private var pendingDelete: Area?

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
                placeCard(area)
              }
              .buttonStyle(.plain)
              .contextMenu {
                Button {
                  editorRoute = PlaceEditorRoute(mode: .edit(area))
                } label: {
                  Label("이름 수정", systemImage: "pencil")
                }
                Button(role: .destructive) {
                  pendingDelete = area
                } label: {
                  Label("삭제", systemImage: "trash")
                }
              }
            }
          }
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: Area.self) { PlaceDetailView(area: $0) }
      .sheet(item: $editorRoute) { route in
        PlaceEditorView(mode: route.mode)
      }
      .confirmationDialog(
        "‘\(pendingDelete?.name ?? "")’ 장소를 삭제할까요?",
        isPresented: deleteConfirmationBinding,
        presenting: pendingDelete
      ) { area in
        Button("삭제", role: .destructive) { delete(area) }
        Button("취소", role: .cancel) {}
      } message: { area in
        Text("수납공간 \(area.spots.count)곳도 함께 삭제됩니다. 보관 중인 물건은 삭제되지 않고 위치만 해제됩니다.")
      }
    }
  }

  private var header: some View {
    HStack(alignment: .bottom) {
      Text("장소")
        .font(.system(size: 34, weight: .heavy))
        .foregroundStyle(AppColor.textPrimary)
      Spacer()
      AppPrimaryButton(title: "장소 추가", systemImage: "plus") {
        editorRoute = PlaceEditorRoute(mode: .create)
      }
    }
    .padding(.bottom, 4)
  }

  private var totalItemCount: Int {
    areas.reduce(0) { $0 + $1.itemCount }
  }

  private var deleteConfirmationBinding: Binding<Bool> {
    Binding(
      get: { pendingDelete != nil },
      set: { if !$0 { pendingDelete = nil } }
    )
  }

  private func delete(_ area: Area) {
    modelContext.delete(area)
    pendingDelete = nil
  }

  private func placeCard(_ area: Area) -> some View {
    let preview = (area.items + area.spots.flatMap(\.items)).map(\.name).prefix(4).joined(separator: " · ")
    return VStack(alignment: .leading, spacing: 0) {
      HStack {
        AppInitialBadge(text: area.name)
        Spacer()
        Text("\(area.itemCount)")
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
}
