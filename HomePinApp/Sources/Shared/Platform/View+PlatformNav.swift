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

  /// 내비게이션 바를 숨긴다(커스텀 헤더를 직접 그리는 화면용).
  ///
  /// `.toolbar(.hidden, for: .navigationBar)` 의 `.navigationBar` 배치는 macOS 에서
  /// 미가용이라 컴파일되지 않는다. iOS 만 내비게이션 바를 숨기고, macOS 는 내비게이션 바
  /// 개념이 달라 no-op 이다(타이틀·도구는 윈도우/툴바가 처리).
  @ViewBuilder
  func hideNavBar() -> some View {
    #if os(iOS)
    toolbar(.hidden, for: .navigationBar)
    #else
    self
    #endif
  }

  /// 자동 대문자화를 끈 평문 텍스트 입력으로 둔다(태그·소문자 식별자 입력용).
  ///
  /// `textInputAutocapitalization(_:)` 은 iOS 전용이다. macOS 텍스트 필드는 소프트
  /// 키보드 자동 대문자화가 없어 no-op 이다.
  @ViewBuilder
  func plainTextInput() -> some View {
    #if os(iOS)
    textInputAutocapitalization(.never)
    #else
    self
    #endif
  }

  /// 숫자 입력 소프트 키보드를 지정한다(`decimal` 이면 소수점 패드).
  ///
  /// `keyboardType(_:)` 은 iOS 전용 소프트 키보드 API 다. macOS 는 하드웨어 키보드라
  /// no-op 이다(숫자 입력 검증은 입력 바인딩 측에서 그대로 처리).
  @ViewBuilder
  func numericKeyboard(decimal: Bool = false) -> some View {
    #if os(iOS)
    keyboardType(decimal ? .decimalPad : .numberPad)
    #else
    self
    #endif
  }
}
