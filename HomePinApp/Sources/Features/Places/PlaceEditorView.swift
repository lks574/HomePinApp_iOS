import SwiftData
import SwiftUI

/// 장소(Area) 추가/편집 공용 에디터.
/// 저장 전 draft 는 SwiftData 에 넣지 않고 화면 로컬 `@State` 로만 보관한다.
struct PlaceEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(AppRouter.self) private var router
  @Query(sort: \Area.sortOrder) private var areas: [Area]
  @Query(sort: \Space.sortOrder) private var spaces: [Space]

  private let mode: Mode

  @State private var name: String
  /// 새 구역을 만든 직후 "이 구역을 템플릿으로 채울까요?" 후속 제안 시트의 대상 구역.
  /// nil 이면 제안을 띄우지 않는다(거절·편집 모드).
  @State private var templatePromptArea: Area?
  /// 템플릿 제안을 수락해 CaptureSheet 를 템플릿 모드로 띄울 때의 대상 구역.
  /// `@Model` 은 Identifiable 이 아니라 `.sheet(item:)` 에 직접 못 써 Identifiable 래퍼로 감싼다.
  @State private var fillTemplateArea: TemplateFillTarget?
  /// `.create` 에서 Area 를 이미 insert 했는지 1회성 가드. 제안 다이얼로그를 backdrop 탭으로
  /// 닫아 dismiss 가 안 불린 채 에디터가 남아도, Add 재탭 시 같은 이름 Area 가 또 insert 되는 것을 막는다.
  @State private var didCreateArea = false

  enum Mode {
    case create
    case edit(Area)
  }

  init(mode: Mode) {
    self.mode = mode
    switch mode {
    case .create:
      _name = State(initialValue: "")
    case let .edit(area):
      _name = State(initialValue: area.name)
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          AppEditorNameCard(placeholder: "e.g. Kitchen, Bedroom, Balcony", text: $name, onSubmit: save)
        }
        .padding(20)
      }
      .appEditorSaveBar(title: saveTitle, isEnabled: canSave, action: save)
      .background(AppColor.screenBackground)
      .navigationTitle(title)
      .compactNavTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
      .confirmationDialog(
        Text("place.template.prompt.\(templatePromptArea?.name ?? "")"),
        isPresented: templatePromptBinding,
        titleVisibility: .visible
      ) {
        Button("Fill with a template") { acceptTemplatePrompt() }
        Button("Not now", role: .cancel) { declineTemplatePrompt() }
      }
      .sheet(item: $fillTemplateArea, onDismiss: { dismiss() }) { target in
        // 수락 시: 만든 구역을 세션 Area 로 주입한 채 매칭 템플릿 칩 staging 을 연다.
        // 시트가 닫히면(추가했든 안 했든) 에디터도 함께 닫는다.
        CaptureSheet(initialMode: .starterTemplate(area: target.area))
          .environment(router)
      }
    }
  }

  private var title: LocalizedStringKey {
    switch mode {
    case .create: "Add Place"
    case .edit: "Edit Place"
    }
  }

  private var saveTitle: LocalizedStringKey {
    switch mode {
    case .create: "Add"
    case .edit: "Save"
    }
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSave: Bool {
    // 이미 한 번 생성했으면(다이얼로그 backdrop 닫힘 등으로 에디터가 남아도) 재생성 비활성화.
    !trimmedName.isEmpty && !didCreateArea
  }

  private func save() {
    guard canSave else { return }

    switch mode {
    case .create:
      let area = Area(
        name: trimmedName,
        sortOrder: areas.count,
        space: spaces.first
      )
      modelContext.insert(area)
      didCreateArea = true
      // 새 구역을 만든 직후 템플릿 채우기를 제안한다(거절 가능). 제안 dismiss 가 닫기를 책임진다.
      templatePromptArea = area
      return
    case let .edit(area):
      area.name = trimmedName
      area.updatedAt = .now
    }

    dismiss()
  }

  /// 템플릿 제안 다이얼로그 표시 바인딩. 닫으면 대상을 비운다.
  private var templatePromptBinding: Binding<Bool> {
    Binding(
      get: { templatePromptArea != nil },
      set: { if !$0 { templatePromptArea = nil } }
    )
  }

  /// "템플릿으로 채우기" 수락 — 만든 구역을 세션 Area 로 한 CaptureSheet 템플릿 모드를 연다.
  private func acceptTemplatePrompt() {
    guard let area = templatePromptArea else { return }
    templatePromptArea = nil
    fillTemplateArea = TemplateFillTarget(area: area)
  }

  /// "지금 안 함" 거절 — 제안만 닫고 에디터도 닫는다(구역은 이미 저장됨).
  private func declineTemplatePrompt() {
    templatePromptArea = nil
    dismiss()
  }
}

/// `.sheet(item:)` 용 Identifiable 래퍼. `@Model` 은 Identifiable 이 아니라 직접 못 쓴다.
private struct TemplateFillTarget: Identifiable {
  let id = UUID()
  let area: Area
}

struct PlaceEditorRoute: Identifiable {
  let id = UUID()
  let mode: PlaceEditorView.Mode
}
