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
              subtitle: areaSubtitle(area),
              isSelected: selectedArea?.id == area.id
            ) {
              select(area)
            }
          }
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .navigationTitle("Select Place")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
    }
  }

  /// "<n> items · <m> spots" — 수량은 현지화 plural, 이름은 없음(전부 UI 라벨).
  private func areaSubtitle(_ area: Area) -> String {
    let items = String(localized: "picker.itemCount.\(area.itemCount)")
    let spots = String(localized: "picker.spotCount.\(area.spots.count)")
    return "\(items) · \(spots)"
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
            title: String(localized: "None"),
            subtitle: noneSubtitle,
            isSelected: selectedSpot == nil
          ) {
            selectedSpot = nil
            dismiss()
          }

          ForEach(sortedSpots) { spot in
            PickerRow(
              title: spot.name,
              subtitle: spot.area?.name ?? String(localized: "No place"),
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
      .navigationTitle("Select Spot")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
    }
  }

  private var sortedSpots: [Spot] {
    (area?.spots ?? []).sorted { $0.sortOrder < $1.sortOrder }
  }

  /// "선택 안 함" 행 부제: 장소 미지정이면 안내, 장소가 있으면 "<장소>에 직접 보관".
  private var noneSubtitle: String {
    guard let name = area?.name else {
      return String(localized: "Place only")
    }
    return String(localized: "spot.storeDirectly.\(name)")
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
          Text(verbatim: title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(AppColor.textPrimary)
          Text(verbatim: subtitle)
            .font(.appFootnote)
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
