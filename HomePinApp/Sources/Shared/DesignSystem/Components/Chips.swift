import SwiftUI

/// 선택형 필터 칩(선택 시 채움). 레시피 cuisine 등.
struct AppFilterChip: View {
  let title: String
  var isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(verbatim: title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(isSelected ? .white : AppColor.textSecondary)
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(isSelected ? AppColor.accent : AppColor.card, in: Capsule())
    }
    .buttonStyle(.plain)
  }
}

/// 외곽선 칩(비액션 라벨). 레시피 dish 분류 등.
struct AppOutlinedChip: View {
  let title: String

  var body: some View {
    Text(verbatim: title)
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(Color(lightHex: 0x6F4A38, darkHex: 0xC8A48E))
      .padding(.horizontal, 15)
      .padding(.vertical, 8)
      .overlay(Capsule().strokeBorder(Color(lightHex: 0xE0D3C6, darkHex: 0x4C443A)))
  }
}

enum AppIngredientChipState {
  case have
  case soon
  case missing
}

/// 재료 보유 상태 칩(보유/임박/부족). 부족은 점선 외곽선.
struct AppIngredientChip: View {
  let name: String
  let state: AppIngredientChipState

  var body: some View {
    label
      .font(.appSectionLabel)
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

  /// 부족 상태는 "<재료> 부족"(=user data + 현지화 접미)으로 합성한다. 이름 자체는
  /// 사용자 입력이라 현지화 비대상이므로 verbatim 으로 끼워 넣는다.
  private var label: Text {
    if state == .missing {
      Text("ingredient.missing.\(name)")
    } else {
      Text(verbatim: name)
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

/// 상태 표시 알약(강조/완료/중립). 레시피 준비 상태 등.
struct AppStatusPill: View {
  let title: String
  var style: Style = .neutral

  enum Style {
    case accent
    case ready
    case neutral
  }

  var body: some View {
    Text(verbatim: title)
      .font(.appBadge)
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
