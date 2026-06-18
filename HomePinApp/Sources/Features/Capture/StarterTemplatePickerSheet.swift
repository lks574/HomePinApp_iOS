import SwiftUI

/// 스타터 템플릿 선택 시트. 정적 템플릿 목록에서 하나를 고른다.
/// 선택 결과는 자체 프리뷰가 아니라 호출부의 칩 staging UI(`CaptureSheet` bulk 모드)로 합류한다.
/// 추천(매칭) 템플릿이 있으면 위에 강조하고, 항상 전체 목록도 직접 고를 수 있게 둔다.
struct StarterTemplatePickerSheet: View {
  @Environment(\.dismiss) private var dismiss

  /// 새 Area 이름 매칭으로 추천된 템플릿(없으면 nil — 전체 목록만 보여준다).
  let suggested: StarterTemplate?
  /// 사용자가 템플릿을 고르면 호출된다. 시트는 호출 후 닫는다.
  let onSelect: (StarterTemplate) -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if let suggested {
            section(title: "Suggested for this place") {
              templateRow(suggested, isSuggested: true)
            }
          }
          section(title: suggested == nil ? "Choose a starter set" : "All starter sets") {
            ForEach(otherTemplates) { template in
              templateRow(template, isSuggested: false)
            }
          }
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .navigationTitle("Starter Templates")
      .compactNavTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
      }
    }
  }

  /// 추천을 뺀 나머지 템플릿(추천이 없으면 전체).
  private var otherTemplates: [StarterTemplate] {
    StarterTemplate.all.filter { $0.kind != suggested?.kind }
  }

  private func section(
    title: LocalizedStringKey,
    @ViewBuilder rows: () -> some View
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.appSectionLabel).foregroundStyle(AppColor.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
      VStack(spacing: 10) { rows() }
    }
  }

  private func templateRow(_ template: StarterTemplate, isSuggested: Bool) -> some View {
    Button {
      onSelect(template)
      dismiss()
    } label: {
      HStack(spacing: 12) {
        AppInitialBadge(text: template.displayName, size: 44, radius: 12)
        VStack(alignment: .leading, spacing: 3) {
          Text(verbatim: template.displayName)
            .font(.appItemBody).foregroundStyle(AppColor.textPrimary)
          Text(verbatim: previewNames(template))
            .font(.appCaption).foregroundStyle(AppColor.textMuted)
            .lineLimit(1)
        }
        Spacer()
        Text("count.items.\(template.items.count)")
          .font(.appCaptionStrong).foregroundStyle(AppColor.textMuted)
        Image(systemName: "chevron.right").font(.appTag).foregroundStyle(AppColor.textFaint)
      }
      .padding(.horizontal, 16).padding(.vertical, 12)
      .appCard()
    }
    .buttonStyle(.plain)
  }

  /// 품목 미리보기(앞 몇 개를 점으로 잇는다). 사용자 표시용이라 verbatim.
  private func previewNames(_ template: StarterTemplate) -> String {
    template.items.prefix(4).map(\.name).joined(separator: " · ")
  }
}
