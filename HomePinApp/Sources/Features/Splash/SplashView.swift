import SwiftUI

/// 최초 화면(스플래시). 앱 시작 동안 보여주는 정적 화면.
/// 다음 단계 분기는 `AppModel.start()` 가 담당하고, 이 뷰는 표시만 한다.
struct SplashView: View {
  var body: some View {
    ZStack {
      Color(.systemBackground)
        .ignoresSafeArea()
      VStack(spacing: 16) {
        Image(systemName: "house.fill")
          .font(.system(size: 64))
          .foregroundStyle(.tint)
        Text("HomePin")
          .font(.largeTitle.bold())
        ProgressView()
          .padding(.top, 8)
      }
    }
  }
}

#Preview {
  SplashView()
}
