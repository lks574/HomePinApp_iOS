import SwiftUI

extension View {
  /// 에디터 하단 고정 저장 바 — 전체폭 기본 버튼 + 반투명 배경. 추가/편집 시트 공용.
  func appEditorSaveBar(title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
    safeAreaInset(edge: .bottom, spacing: 0) {
      AppFullWidthPrimaryButton(title: title, isEnabled: isEnabled, action: action)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.regularMaterial)
    }
  }
}

/// 단일 "이름" 입력 카드 — 이름 하나만 받는 에디터 공용(장소·세부위치).
/// 표시 즉시 자동 포커스하고, 키보드 done 으로 `onSubmit` 을 호출한다.
struct AppEditorNameCard: View {
  var placeholder: String
  @Binding var text: String
  var onSubmit: () -> Void
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("이름")
        .font(.appRowLabel)
        .foregroundStyle(AppColor.textPrimary)
      TextField(placeholder, text: $text)
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
        .focused($focused)
        .submitLabel(.done)
        .onSubmit(onSubmit)
    }
    .padding(16)
    .appCard(radius: 18)
    .onAppear { focused = true }
  }
}
