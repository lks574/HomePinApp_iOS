import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 데이터 백업/가져오기 · CSV 대량 입력 화면. SettingsView 데이터 섹션에서 진입한다.
///
/// 시스템 modal(`fileExporter`/`fileImporter`)로 파일을 주고받고, 결과 요약을
/// 화면에 표시한다. 오케스트레이션·상태는 `DataTransferModel` 이 갖는다.
struct DataTransferView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var model = DataTransferModel()

  var body: some View {
    List {
      backupSection
      csvSection
      statusSection
    }
    .navigationTitle("Backup & Import")
    .navigationBarTitleDisplayMode(.inline)
    // 파일 모달은 각각 별도 뷰(배경 앵커)에 하나씩 붙인다. 한 뷰에 여러 개를 쌓으면
    // SwiftUI 가 일부만 표시하고 나머지를 조용히 무시한다(백업/CSV 가림 버그 방지).
    .background(backupExportAnchor)
    .background(backupImportAnchor)
    .background(csvExportAnchor)
    .background(csvImportAnchor)
  }

  // MARK: - 파일 모달 앵커 (가림 방지용 분리 뷰)

  private var backupExportAnchor: some View {
    Color.clear.fileExporter(
      isPresented: $model.isExportingBackup,
      document: model.backupDocument,
      contentType: .homePinBackup,
      defaultFilename: model.backupExportFileName(),
    ) { result in
      model.handleBackupExportResult(result)
    }
  }

  private var backupImportAnchor: some View {
    Color.clear.fileImporter(
      isPresented: $model.isImportingBackup,
      allowedContentTypes: [.homePinBackup],
    ) { result in
      model.handleBackupImportResult(result.map { [$0] }, modelContext: modelContext)
    }
  }

  private var csvExportAnchor: some View {
    Color.clear.fileExporter(
      isPresented: $model.isExportingCSV,
      document: model.csvDocument,
      contentType: .commaSeparatedText,
      defaultFilename: model.csvExportFileName,
    ) { result in
      model.handleCSVExportResult(result)
    }
  }

  private var csvImportAnchor: some View {
    Color.clear.fileImporter(
      isPresented: $model.isImportingCSV,
      allowedContentTypes: [.commaSeparatedText, .text, .plainText],
    ) { result in
      model.handleCSVImportResult(result.map { [$0] }, modelContext: modelContext)
    }
  }

  // MARK: - 전체 백업

  private var backupSection: some View {
    Section {
      Button {
        model.prepareBackupExport(modelContext: modelContext)
      } label: {
        Label("Export Backup", systemImage: "square.and.arrow.up")
      }
      Button {
        model.isImportingBackup = true
      } label: {
        Label("Import Backup", systemImage: "square.and.arrow.down")
      }
    } header: {
      Text("Full Backup")
    } footer: {
      Text("Export all data as a backup package, or import one to merge by id.")
    }
  }

  // MARK: - CSV 대량 입력

  private var csvSection: some View {
    Section {
      ForEach(DataTransferModel.CSVKind.allCases) { kind in
        csvRow(for: kind)
      }
    } header: {
      Text("CSV Bulk Import")
    } footer: {
      Text("Import items or recipes from CSV. Tap the template to see the columns.")
    }
  }

  private func csvRow(for kind: DataTransferModel.CSVKind) -> some View {
    HStack {
      Text(csvTitle(kind))
      Spacer()
      Button("Template") {
        model.prepareCSVTemplateExport(kind)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      Button("Import") {
        model.beginCSVImport(kind)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
    }
  }

  private func csvTitle(_ kind: DataTransferModel.CSVKind) -> LocalizedStringKey {
    switch kind {
    case .items: "Items"
    case .recipes: "Recipes"
    case .recipeIngredients: "Recipe ingredients"
    }
  }

  // MARK: - 상태/결과

  @ViewBuilder
  private var statusSection: some View {
    switch model.status {
    case .idle:
      EmptyView()
    case let .working(message):
      Section {
        HStack(spacing: 12) {
          ProgressView()
          Text(verbatim: message)
        }
      }
    case let .success(message):
      Section {
        Label { Text(verbatim: message) } icon: {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
      }
    case let .failure(message):
      Section {
        Label { Text(verbatim: message) } icon: {
          Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
      }
    }
  }
}
