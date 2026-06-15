import SwiftUI

struct AreaPickerSheet: View {
  @Environment(\.dismiss) private var dismiss

  let areas: [Area]
  @Binding var selectedArea: Area?
  @Binding var selectedSpot: Spot?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          ForEach(areas) { area in
            PickerRow(
              title: area.name,
              subtitle: "\(area.itemCount)개 · 세부위치 \(area.spots.count)곳",
              isSelected: selectedArea?.id == area.id
            ) {
              select(area)
            }
          }
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .navigationTitle("장소 선택")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("닫기") { dismiss() }
        }
      }
    }
  }

  private func select(_ area: Area) {
    selectedArea = area
    if selectedSpot?.area?.id != area.id {
      selectedSpot = nil
    }
    dismiss()
  }
}

struct SpotPickerSheet: View {
  @Environment(\.dismiss) private var dismiss

  let area: Area?
  @Binding var selectedSpot: Spot?
  @Binding var selectedArea: Area?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          PickerRow(
            title: "선택 안 함",
            subtitle: area == nil ? "장소만 지정" : "\(area?.name ?? "")에 직접 보관",
            isSelected: selectedSpot == nil
          ) {
            selectedSpot = nil
            dismiss()
          }

          ForEach(sortedSpots) { spot in
            PickerRow(
              title: spot.name,
              subtitle: spot.area?.name ?? "장소 없음",
              isSelected: selectedSpot?.id == spot.id
            ) {
              selectedSpot = spot
              selectedArea = spot.area
              dismiss()
            }
          }
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .navigationTitle("세부위치 선택")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("닫기") { dismiss() }
        }
      }
    }
  }

  private var sortedSpots: [Spot] {
    (area?.spots ?? []).sorted { $0.sortOrder < $1.sortOrder }
  }
}

private struct PickerRow: View {
  let title: String
  let subtitle: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(AppColor.textPrimary)
          Text(subtitle)
            .font(.system(size: 13))
            .foregroundStyle(AppColor.textMuted)
        }
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(isSelected ? AppColor.accent : AppColor.textFaint)
      }
      .padding(16)
      .appCard(radius: 16)
    }
    .buttonStyle(.plain)
  }
}
