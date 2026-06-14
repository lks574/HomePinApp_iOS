import SwiftUI

struct AppSectionTitle: View {
  let title: String
  var uppercase = false

  var body: some View {
    Text(uppercase ? title.uppercased() : title)
      .font(.system(size: 13, weight: .bold))
      .foregroundStyle(AppColor.textTertiary)
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct AppSearchBar: View {
  let placeholder: String
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
    .font(.system(size: 16))
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

struct AppPrimaryButton: View {
  let title: String
  var systemImage: String?
  var isEnabled = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 13, weight: .bold))
        }
        Text(title)
      }
      .font(.system(size: 14, weight: .bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .frame(height: 36)
      .background(isEnabled ? AppColor.accent : AppColor.textMuted, in: Capsule())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }
}

struct AppFullWidthPrimaryButton: View {
  let title: String
  var isEnabled = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
          isEnabled ? AppColor.accent : AppColor.textMuted,
          in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }
}

struct AppFilterChip: View {
  let title: String
  var isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(isSelected ? .white : AppColor.textSecondary)
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(isSelected ? AppColor.accent : AppColor.card, in: Capsule())
    }
    .buttonStyle(.plain)
  }
}

struct AppOutlinedChip: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(Color(hex: 0x6F4A38))
      .padding(.horizontal, 15)
      .padding(.vertical, 8)
      .overlay(Capsule().strokeBorder(Color(hex: 0xE0D3C6)))
  }
}

struct AppInitialBadge: View {
  let text: String
  var size: CGFloat = 42
  var fontSize: CGFloat = 17
  var radius: CGFloat = 13

  var body: some View {
    Text(String(text.prefix(1)))
      .font(.system(size: fontSize, weight: .bold))
      .foregroundStyle(AppColor.badgeText)
      .frame(width: size, height: size)
      .background(AppColor.badgeBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
  }
}

enum AppIngredientChipState {
  case have
  case soon
  case missing
}

struct AppIngredientChip: View {
  let name: String
  let state: AppIngredientChipState

  var body: some View {
    Text(state == .missing ? "\(name) 부족" : name)
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(textColor)
      .padding(.horizontal, 11)
      .padding(.vertical, 5)
      .background(background, in: Capsule())
      .overlay {
        if state == .missing {
          Capsule().strokeBorder(AppColor.chipMissingBorder, style: StrokeStyle(lineWidth: 1, dash: [3]))
        }
      }
  }

  private var textColor: Color {
    switch state {
    case .have: AppColor.chipHaveText
    case .soon: AppColor.chipSoonText
    case .missing: AppColor.chipMissingText
    }
  }

  private var background: Color {
    switch state {
    case .have: AppColor.chipHaveBackground
    case .soon: AppColor.chipSoonBackground
    case .missing: .clear
    }
  }
}

struct AppStatusPill: View {
  let title: String
  var style: Style = .neutral

  enum Style {
    case accent
    case ready
    case neutral
  }

  var body: some View {
    Text(title)
      .font(.system(size: 13, weight: .bold))
      .foregroundStyle(foreground)
      .padding(.horizontal, 11)
      .padding(.vertical, 5)
      .background(background, in: Capsule())
  }

  private var foreground: Color {
    switch style {
    case .accent: .white
    case .ready: AppColor.chipReadyText
    case .neutral: AppColor.textSecondary
    }
  }

  private var background: Color {
    switch style {
    case .accent: AppColor.accent
    case .ready: AppColor.chipReadyBackground
    case .neutral: AppColor.chipHaveBackground
    }
  }
}
