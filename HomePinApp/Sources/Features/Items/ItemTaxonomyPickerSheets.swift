import SwiftData
import SwiftUI

struct ItemCategoryPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let categories: [ItemCategory]
  @Binding var selectedCategory: ItemCategory?

  @State private var newCategoryName = ""

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          TaxonomyPickerRow(
            title: String(localized: "Uncategorized"),
            subtitle: String(localized: "No category"),
            isSelected: selectedCategory == nil
          ) {
            selectedCategory = nil
            dismiss()
          }

          ForEach(categories) { category in
            TaxonomyPickerRow(
              title: category.name,
              subtitle: (category.items ?? []).isEmpty
                ? String(localized: "No items")
                : String(localized: "picker.itemCount.\((category.items ?? []).count)"),
              isSelected: selectedCategory?.id == category.id
            ) {
              selectedCategory = category
              dismiss()
            }
          }

          createRow(
            placeholder: String(localized: "New category"),
            title: String(localized: "Add Category"),
            text: $newCategoryName,
            action: createCategory
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

  private var trimmedNewCategoryName: String {
    newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func createCategory() {
    let name = trimmedNewCategoryName
    guard !name.isEmpty else { return }
    if let existing = categories.first(where: { Item.normalize($0.name) == Item.normalize(name) }) {
      selectedCategory = existing
      dismiss()
      return
    }
    let nextSortOrder = (categories.map(\.sortOrder).max() ?? 0) + 1
    let category = ItemCategory(name: name, sortOrder: nextSortOrder)
    modelContext.insert(category)
    selectedCategory = category
    dismiss()
  }
}

struct ItemTagPickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  let tags: [Tag]
  @Binding var selectedTags: [Tag]

  @State private var newTagName = ""

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          ForEach(tags) { tag in
            TaxonomyPickerRow(
              title: tag.name,
              subtitle: (tag.items ?? []).isEmpty
                ? String(localized: "No items")
                : String(localized: "picker.itemCount.\((tag.items ?? []).count)"),
              isSelected: selectedTags.contains { $0.id == tag.id }
            ) {
              toggle(tag)
            }
          }

          createRow(
            placeholder: String(localized: "New tag"),
            title: String(localized: "Add Tag"),
            text: $newTagName,
            action: createTag
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

  private var trimmedNewTagName: String {
    newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func toggle(_ tag: Tag) {
    if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
      selectedTags.remove(at: index)
    } else {
      selectedTags.append(tag)
    }
  }

  private func createTag() {
    let name = trimmedNewTagName
    guard !name.isEmpty else { return }
    if let existing = tags.first(where: { Item.normalize($0.name) == Item.normalize(name) }) {
      if !selectedTags.contains(where: { $0.id == existing.id }) {
        selectedTags.append(existing)
      }
      newTagName = ""
      return
    }
    let tag = Tag(name: name)
    modelContext.insert(tag)
    selectedTags.append(tag)
    newTagName = ""
  }

  private var clearSelectionButton: some View {
    Button("Clear") {
      selectedTags = []
    }
  }
}

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
private func createRow(
  placeholder: String,
  title: String,
  text: Binding<String>,
  action: @escaping () -> Void
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
