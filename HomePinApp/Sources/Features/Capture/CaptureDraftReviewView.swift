import SwiftData
import SwiftUI

/// screen-09 — 자연어 파싱 결과 확인 드래프트 화면. [[Capture]] 가 소유하는 push 화면.
/// 파서가 뽑은 다건 물건을 항목별로 확인/수정/삭제하고, 신규 vs 기존 매칭을 시각 구분하며,
/// 구역이 빈 항목은 채워야 저장한다. 저장 시 다건 일괄 insert + 신규 위치/분류/태그 생성을
/// `AddDraftResolver` 에 위임하고 시트를 닫는다.
struct CaptureDraftReviewView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Area.sortOrder) private var areas: [Area]

  /// 확인/수정 대상 드래프트. 부모(CaptureSheet)가 파싱 결과로 채워 넘긴다.
  @State private var drafts: [AddDraft]
  /// 저장 완료 시 시트를 닫는다.
  private let onSaved: () -> Void

  @State private var pickerTarget: PickerTarget?

  init(drafts: [AddDraft], onSaved: @escaping () -> Void) {
    _drafts = State(initialValue: drafts)
    self.onSaved = onSaved
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        header
        ForEach(drafts) { draft in
          draftCard(draft)
        }
      }
      .padding(20)
    }
    .appEditorSaveBar(title: saveTitle, isEnabled: canSaveAll, action: saveAll)
    .background(AppColor.screenBackground)
    .navigationTitle("Confirm and Add")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $pickerTarget) { target in
      pickerSheet(for: target)
    }
  }

  // MARK: - 헤더

  private var header: some View {
    Text("This is what AI sorted out. Check it, edit if needed, and add. \"New\" items will be created this time.")
      .font(.appFootnote)
      .foregroundStyle(AppColor.textMuted)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - 항목 카드

  private func draftCard(_ draft: AddDraft) -> some View {
    VStack(spacing: 0) {
      nameRow(draft)
      Divider().padding(.leading, 16)
      quantityRow(draft)
      Divider().padding(.leading, 16)
      areaRow(draft)
      Divider().padding(.leading, 16)
      spotRow(draft)
      if draft.categoryMatch != nil || !draft.tagMatches.isEmpty {
        Divider().padding(.leading, 16)
        classificationRow(draft)
      }
    }
    .appCard(radius: 18)
  }

  private func nameRow(_ draft: AddDraft) -> some View {
    HStack(spacing: 10) {
      TextField("Item name", text: bindingName(draft))
        .font(.appFieldText)
        .foregroundStyle(AppColor.textPrimary)
      Spacer(minLength: 8)
      Button(role: .destructive) {
        remove(draft)
      } label: {
        Image(systemName: "trash")
          .font(.appBadge)
          .foregroundStyle(.red)
          .frame(width: 34, height: 34)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .frame(height: 58)
  }

  private func quantityRow(_ draft: AddDraft) -> some View {
    HStack {
      Text("Quantity").font(.appRowLabel).foregroundStyle(AppColor.textPrimary)
      Spacer()
      Button {
        draft.quantity = max(1, draft.quantity - 1)
      } label: {
        Image(systemName: "minus").font(.appBadge).frame(width: 34, height: 34)
      }
      .buttonStyle(.plain)
      .foregroundStyle(draft.quantity > 1 ? AppColor.accent : AppColor.textFaint)
      .disabled(draft.quantity <= 1)

      Text("\(draft.quantity)")
        .font(.appValueStrong).foregroundStyle(AppColor.textPrimary)
        .monospacedDigit().frame(minWidth: 34)

      Button {
        draft.quantity += 1
      } label: {
        Image(systemName: "plus").font(.appBadge).frame(width: 34, height: 34)
      }
      .buttonStyle(.plain)
      .foregroundStyle(AppColor.accent)
    }
    .padding(.horizontal, 16)
    .frame(height: 58)
  }

  private func areaRow(_ draft: AddDraft) -> some View {
    matchRow(
      title: "Place",
      match: draft.areaMatch,
      placeholder: "Select place",
      isRequiredEmpty: !draft.areaMatch.hasValue,
    ) {
      pickerTarget = .area(draft)
    }
  }

  private func spotRow(_ draft: AddDraft) -> some View {
    matchRow(
      title: "Spot",
      match: draft.spotMatch,
      placeholder: "None",
      isRequiredEmpty: false,
    ) {
      pickerTarget = .spot(draft)
    }
  }

  private func classificationRow(_ draft: AddDraft) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      if let category = draft.categoryMatch {
        HStack(spacing: 6) {
          Text("Category").font(.appCaptionStrong).foregroundStyle(AppColor.textTertiary)
          matchChip(name: matchName(category, fallback: ""), isNew: category.isNew)
        }
      }
      if !draft.tagMatches.isEmpty {
        HStack(alignment: .top, spacing: 6) {
          Text("Tags").font(.appCaptionStrong).foregroundStyle(AppColor.textTertiary)
            .padding(.top, 3)
          FlowLayout(spacing: 6) {
            ForEach(draft.tagMatches) { tag in
              matchChip(name: matchName(tag, fallback: ""), isNew: tag.isNew)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
  }

  // MARK: - 매칭 행/칩 공용

  private func matchRow<Model>(
    title: LocalizedStringKey,
    match: NameMatch<Model>?,
    placeholder: LocalizedStringKey,
    isRequiredEmpty: Bool,
    action: @escaping () -> Void,
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Text(title).font(.appRowLabel).foregroundStyle(AppColor.textPrimary)
        Spacer()
        if let name = matchDisplayName(match) {
          matchChip(name: name, isNew: match?.isNew ?? false)
        } else {
          Text(placeholder)
            .font(.appRowLabel)
            .foregroundStyle(isRequiredEmpty ? AppColor.accent : AppColor.textMuted)
        }
        Image(systemName: "chevron.right").font(.appTag).foregroundStyle(AppColor.textFaint)
      }
      .padding(.horizontal, 16)
      .frame(height: 58)
    }
    .buttonStyle(.plain)
  }

  private func matchChip(name: String, isNew: Bool) -> some View {
    HStack(spacing: 4) {
      if isNew {
        Text("New").font(.appTag).foregroundStyle(AppColor.chipSoonText)
      }
      Text(verbatim: name).font(.appTag).foregroundStyle(isNew ? AppColor.chipSoonText : AppColor.chipHaveText)
    }
    .padding(.horizontal, 10)
    .frame(height: 26)
    .background(
      isNew ? AppColor.chipSoonBackground : AppColor.chipHaveBackground,
      in: Capsule(),
    )
  }

  // MARK: - 피커 시트

  @ViewBuilder
  private func pickerSheet(for target: PickerTarget) -> some View {
    switch target {
    case let .area(draft):
      AreaPickerSheet(
        areas: areas,
        selectedArea: bindingArea(draft),
        selectedSpot: bindingSpot(draft),
      )
    case let .spot(draft):
      SpotPickerSheet(
        area: existingArea(draft),
        selectedSpot: bindingSpot(draft),
        selectedArea: bindingArea(draft),
      )
    }
  }

  // MARK: - 바인딩(매칭 ↔ 기존 엔티티 선택)

  private func bindingName(_ draft: AddDraft) -> Binding<String> {
    Binding(get: { draft.name }, set: { draft.name = $0 })
  }

  /// 장소 선택 바인딩. 기존 Area 선택 시 `.existing`, 해제 시 신규 빈 매칭으로 되돌린다.
  private func bindingArea(_ draft: AddDraft) -> Binding<Area?> {
    Binding(
      get: { existingArea(draft) },
      set: { newValue in
        if let newValue {
          draft.areaMatch = .existing(newValue)
        } else {
          draft.areaMatch = .new("")
        }
      },
    )
  }

  private func bindingSpot(_ draft: AddDraft) -> Binding<Spot?> {
    Binding(
      get: {
        if case let .existing(spot)? = draft.spotMatch { return spot }
        return nil
      },
      set: { newValue in
        if let newValue {
          draft.spotMatch = .existing(newValue)
          if let area = newValue.area { draft.areaMatch = .existing(area) }
        } else {
          draft.spotMatch = nil
        }
      },
    )
  }

  private func existingArea(_ draft: AddDraft) -> Area? {
    if case let .existing(area) = draft.areaMatch { return area }
    return nil
  }

  // MARK: - 표시 이름

  private func matchDisplayName<Model>(_ match: NameMatch<Model>?) -> String? {
    guard let match else { return nil }
    let name = matchName(match, fallback: "")
    return name.isEmpty ? nil : name
  }

  private func matchName<Model>(_ match: NameMatch<Model>, fallback: String) -> String {
    switch match {
    case let .existing(model):
      (model as? NameMatchable)?.name ?? fallback
    case let .new(name):
      name
    }
  }

  // MARK: - 저장/삭제

  private var saveTitle: LocalizedStringKey {
    drafts.count > 1 ? "draft.addCount.\(drafts.count)" : "Add"
  }

  private var canSaveAll: Bool {
    !drafts.isEmpty && drafts.allSatisfy(\.canSave)
  }

  private func saveAll() {
    guard canSaveAll else { return }
    AddDraftResolver.save(drafts, into: modelContext)
    onSaved()
  }

  private func remove(_ draft: AddDraft) {
    drafts.removeAll { $0.id == draft.id }
  }
}

/// 어떤 드래프트의 어떤 위치 필드를 고르는 중인지. 시트 라우팅용.
private enum PickerTarget: Identifiable {
  case area(AddDraft)
  case spot(AddDraft)

  var id: String {
    switch self {
    case let .area(draft): "area-\(draft.id)"
    case let .spot(draft): "spot-\(draft.id)"
    }
  }
}
