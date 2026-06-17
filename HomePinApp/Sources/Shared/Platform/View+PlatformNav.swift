import SwiftUI

extension View {
  /// 내비게이션 타이틀을 인라인(컴팩트) 표시로 둔다.
  ///
  /// `navigationBarTitleDisplayMode(.inline)` 은 iOS 전용 API 라 macOS 에서 컴파일되지
  /// 않는다. 화면마다 `#if os(iOS)` 를 흩뿌리는 대신 여기서 한 번 분기한다 — iOS 는 인라인
  /// 표시, macOS 는 네비게이션 바 개념이 달라 no-op 이다(타이틀은 윈도우/툴바가 처리).
  @ViewBuilder
  func compactNavTitle() -> some View {
    #if os(iOS)
    navigationBarTitleDisplayMode(.inline)
    #else
    self
    #endif
  }
}
