import SwiftUI

/// 검색 바(카드형/필드형). 현재는 placeholder 표시 전용(실제 검색은 후속 screen-04).
struct AppSearchBar: View {
  let placeholder: LocalizedStringKey
  var style: Style = .card

  enum Style {
    case card
    case field
  }

  var body: some View {
    HStack(spacing: style.iconSpacing) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(style.foreground)
      Text(placeholder)
        .foregroundStyle(style.foreground)
      Spacer()
    }
    .font(.appItemBody)
    .padding(.horizontal, style.horizontalPadding)
    .frame(height: style.height)
    .background(background)
  }

  @ViewBuilder
  private var background: some View {
    switch style {
    case .card:
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(AppColor.card)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    case .field:
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .fill(AppColor.fieldBackground)
    }
  }
}

private extension AppSearchBar.Style {
  var foreground: Color {
    switch self {
    case .card: AppColor.textMuted
    case .field: AppColor.textTertiary
    }
  }

  var height: CGFloat {
    switch self {
    case .card: 48
    case .field: 44
    }
  }

  var horizontalPadding: CGFloat {
    switch self {
    case .card: 15
    case .field: 14
    }
  }

  var iconSpacing: CGFloat {
    switch self {
    case .card: 10
    case .field: 9
    }
  }
}
