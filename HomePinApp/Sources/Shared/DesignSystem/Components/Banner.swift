import SwiftUI

/// 유통기한 임박 아이템 배너 — accent 그라데이션 + D-day 캡슐. 홈·레시피 공용.
/// `headline` 은 호출부가 구성한다(홈: 이름 나열, 레시피: "…, 오늘 다 써볼까요?").
struct AppExpiringItemsBanner: View {
  let items: [Item]
  let headline: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("expiring.count.\(items.count)")
        .font(.appSectionLabel)
        .foregroundStyle(AppColor.onAccentSubtle)
      Text(verbatim: headline)
        .font(.system(size: 18, weight: .heavy))
        .foregroundStyle(.white)
      HStack(spacing: 6) {
        ForEach(items.prefix(3)) { item in
          Text(verbatim: "\(item.name) \(item.dDayLabel)")
            .font(.appTag)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.22), in: Capsule())
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(colors: [AppColor.accent, AppColor.accentDark], startPoint: .topLeading, endPoint: .bottomTrailing),
      in: RoundedRectangle(cornerRadius: 20, style: .continuous)
    )
  }
}
