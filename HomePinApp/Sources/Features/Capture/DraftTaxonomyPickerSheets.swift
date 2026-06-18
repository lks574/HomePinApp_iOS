import SwiftData
import SwiftUI

/// screen-09 — 확인 드래프트(`AddDraft`) 전용 분류 인라인 편집 시트.
///
/// `ItemCategoryPickerSheet`(실제 SwiftData 엔티티 바인딩 + 시트 내부 insert)와 달리,
/// 여기서는 **insert 를 일절 하지 않는다**. 자유 입력은 `AddDraftResolver.match`/`newMatch`
/// 로 정규화 매칭만 해 `NameMatch`(`.existing`/`.new`) 로 만들어 드래프트에 바인딩한다.
/// 실제 생성·연결은 저장 시 `AddDraftResolver.save` 가 전담한다(도메인 경계 유지).
struct DraftCategoryPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \ItemCategory.sortOrder) private var categories: [ItemCategory]

  let draft: AddDraft

  @State private var freeText = ""

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          noneRow

          ForEach(categories) { category in
            TaxonomyPickerRow(
              title: category.name,
              subtitle: subtitle(category),
              isSelected: isSelected(category),
            ) {
              draft.categoryMatch = .existing(category)
              dismiss()
            }
          }

          freeInputRow(
            placeholder: String(localized: "New category"),
            title: String(localized: "Add Category"),
            text: $freeText,
            action: applyFreeText,
          )
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .navigationTitle("Select Category")
      .compactNavTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
    }
  }

  private var noneRow: some View {
    TaxonomyPickerRow(
      title: String(localized: "Uncategorized"),
      subtitle: String(localized: "No category"),
      isSelected: draft.categoryMatch == nil,
    ) {
      draft.categoryMatch = nil
      dismiss()
    }
  }

  private func subtitle(_ category: ItemCategory) -> String {
    (category.items ?? []).isEmpty
      ? String(localized: "No items")
      : String(localized: "picker.itemCount.\((category.items ?? []).count)")
  }

  private func isSelected(_ category: ItemCategory) -> Bool {
    if case let .existing(selected) = draft.categoryMatch { return selected.id == category.id }
    return false
  }

  /// 자유 입력을 정규화 매칭해 `.existing`/`.new` 로 드래프트에 반영한다(insert 없음).
  private func applyFreeText() {
    let trimmed = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    draft.categoryMatch = AddDraftResolver.match(trimmed, in: categories)
    freeText = ""
    dismiss()
  }
}

/// screen-09 — 확인 드래프트(`AddDraft`) 전용 태그 인라인 편집 시트(다중 선택).
///
/// `ItemTagPickerSheet` 와 달리 insert 하지 않는다. 후보 토글과 자유 입력 추가 모두
/// `NameMatch` 로만 다루고, 같은 정규화 키 중복 추가를 막는다. 생성·연결은 저장 시
/// `AddDraftResolver.save` 가 전담한다.
struct DraftTagPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \Tag.name) private var tags: [Tag]

  let draft: AddDraft

  @State private var freeText = ""

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          ForEach(tags) { tag in
            TaxonomyPickerRow(
              title: tag.name,
              subtitle: subtitle(tag),
              isSelected: isSelected(tag),
            ) {
              toggle(tag)
            }
          }

          freeInputRow(
            placeholder: String(localized: "New tag"),
            title: String(localized: "Add Tag"),
            text: $freeText,
            action: applyFreeText,
          )
        }
        .padding(20)
      }
      .background(AppColor.screenBackground)
      .navigationTitle("Select Tags")
      .compactNavTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private func subtitle(_ tag: Tag) -> String {
    (tag.items ?? []).isEmpty
      ? String(localized: "No items")
      : String(localized: "picker.itemCount.\((tag.items ?? []).count)")
  }

  private func isSelected(_ tag: Tag) -> Bool {
    draft.tagMatches.contains { matched in
      if case let .existing(model) = matched { return model.id == tag.id }
      return false
    }
  }

  /// 기존 후보 토글: 이미 선택돼 있으면 해제, 아니면 `.existing` 으로 추가한다.
  private func toggle(_ tag: Tag) {
    if let index = draft.tagMatches.firstIndex(where: { matched in
      if case let .existing(model) = matched { return model.id == tag.id }
      return false
    }) {
      draft.tagMatches.remove(at: index)
    } else {
      draft.tagMatches.append(.existing(tag))
    }
  }

  /// 자유 입력을 정규화 매칭해 추가한다. 같은 정규화 키가 이미 있으면 중복 추가하지 않는다.
  private func applyFreeText() {
    let trimmed = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard let match: NameMatch<Tag> = AddDraftResolver.match(trimmed, in: tags) else { return }
    let key = Item.normalize(trimmed)
    let alreadyPresent = draft.tagMatches.contains { Item.normalize(tagMatchName($0)) == key }
    if !alreadyPresent {
      draft.tagMatches.append(match)
    }
    freeText = ""
  }

  private func tagMatchName(_ match: NameMatch<Tag>) -> String {
    switch match {
    case let .existing(tag): tag.name
    case let .new(name): name
    }
  }
}

/// 드래프트 시트 공용 선택 행. `ItemTaxonomyPickerSheets` 의 행과 동일한 시각이지만
/// 그 파일의 private 컴포넌트와 분리해 드래프트 시트 안에서 자급한다(엔티티 결합 없음).
private struct TaxonomyPickerRow: View {
  let title: String
  let subtitle: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(verbatim: title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(AppColor.textPrimary)
          Text(verbatim: subtitle)
            .font(.appFootnote)
            .foregroundStyle(AppColor.textMuted)
        }
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(isSelected ? AppColor.accent : AppColor.textFaint)
      }
      .padding(16)
      .appCard(radius: 16)
    }
    .buttonStyle(.plain)
  }
}

@MainActor
private func freeInputRow(
  placeholder: String,
  title: String,
  text: Binding<String>,
  action: @escaping () -> Void,
) -> some View {
  HStack(spacing: 10) {
    TextField(placeholder, text: text)
      .font(.appItemBody)
      .plainTextInput()
    Button(title, action: action)
      .font(.appRowLabel)
      .foregroundStyle(AppColor.accent)
      .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }
  .padding(16)
  .appCard(radius: 16)
}
