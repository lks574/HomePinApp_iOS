import SwiftUI

/// 강제 업데이트 차단 화면. 현재 버전이 RemoteConfig 의 강제 하한보다 낮을 때
/// `AppRootView` 가 앱 전체 위에 덮어, 닫을 수 없는 전체 화면으로 사용을 막는다.
/// 유일한 행동은 스토어로 이동하는 "지금 업데이트" 버튼이다(취소·닫기 경로 없음).
struct ForcedUpdateView: View {
  let latestVersion: String?
  let updateURL: URL?

  @Environment(\.openURL) private var openURL

  var body: some View {
    ZStack {
      AppColor.screenBackground.ignoresSafeArea()

      VStack(spacing: 20) {
        Image(systemName: "arrow.up.circle.fill")
          .font(.system(size: 64))
          .foregroundStyle(AppColor.accent)

        Text("Update Required")
          .font(.title2.bold())

        Text("Please update to the latest version to keep using HomePin.")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        if let latestVersion {
          Text("Latest version: \(latestVersion)")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Button {
          if let updateURL {
            openURL(updateURL)
          }
        } label: {
          Text("Update Now")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColor.accent)
        .padding(.top, 8)
      }
      .padding(.horizontal, 32)
      .frame(maxWidth: 420)
    }
    // 시스템 제스처로도 벗어나지 못하게 한다(차단 화면).
    .interactiveDismissDisabled()
  }
}
