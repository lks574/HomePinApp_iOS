import SwiftData
import SwiftUI

/// 장소(=Area) 목록. 2열 그리드, 장소별 개수·미리보기. 탭하면 상세로.
struct PlacesListView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AppRouter.self) private var router
  @Query(sort: \Area.sortOrder) private var areas: [Area]

  @State private var editorRoute: PlaceEditorRoute?
  @State private var pendingDelete: Area?

  /// 장소 탭의 네비게이션 경로는 라우터가 소유한다(탭 전환·홈 바로가기에서 push).
  private var placesPath: Binding<[Area]> {
    Binding(get: { router.placesPath }, set: { router.placesPath = $0 })
  }

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
  ]

  var body: some View {
    NavigationStack(path: placesPath) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          header
          Text("places.summary.\(areas.count).\(totalItemCount)")
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
                  Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) {
                  pendingDelete = area
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            }
          }
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .hideNavBar()
      .navigationDestination(for: Area.self) { PlaceDetailView(area: $0) }
      .sheet(item: $editorRoute) { route in
        PlaceEditorView(mode: route.mode)
      }
      .confirmationDialog(
        Text("place.delete.title.\(pendingDelete?.name ?? "")"),
        isPresented: deleteConfirmationBinding,
        presenting: pendingDelete
      ) { area in
        Button("Delete", role: .destructive) { delete(area) }
        Button("Cancel", role: .cancel) {}
      } message: { area in
        Text("place.delete.message.\((area.spots ?? []).count)")
      }
    }
  }

  private var header: some View {
    HStack(alignment: .bottom) {
      Text("Places")
        .font(.appScreenTitle)
        .foregroundStyle(AppColor.textPrimary)
      Spacer()
      AppPrimaryButton(title: "Add Place", systemImage: "plus") {
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
    let preview = ((area.items ?? []) + (area.spots ?? []).flatMap { $0.items ?? [] }).map(\.name).prefix(4).joined(separator: " · ")
    return VStack(alignment: .leading, spacing: 0) {
      HStack {
        AppInitialBadge(text: area.name)
        Spacer()
        Text("\(area.itemCount)")
          .font(.appBadge)
          .foregroundStyle(AppColor.textFaint)
      }
      .padding(.bottom, 22)

      Text(verbatim: area.name)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(AppColor.textPrimary)
      Text(verbatim: preview)
        .font(.appCaption)
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
