import Foundation
import SwiftData
import UniformTypeIdentifiers

/// 데이터 백업/가져오기·CSV 화면의 얇은 `@Observable` 모델.
///
/// 정당화(`CLAUDE.md` 상태 관리 두 조건 모두 충족):
/// 1. 비영속 UI 상태 — 파일 선택/진행/결과 표시 상태.
/// 2. 다단계 쓰기 오케스트레이션 — 백업 2-pass upsert·CSV 다단계 import(레시피→재료 순서).
///
/// 실제 영속 쓰기는 `BackupArchive`·`CSVImporter`(둘 다 `@MainActor`)에 위임한다.
@MainActor
@Observable
final class DataTransferModel {
  /// 진행/결과 상태(화면 표시용).
  var status: DataTransferStatus = .idle

  /// export 할 백업 패키지 문서(fileExporter 전달용).
  var backupDocument: BackupDocument?
  /// 백업 export 제안 파일명(확장자 제외).
  var backupExportBaseName = "HomePin-backup"
  /// 백업 export 시트 표시 여부.
  var isExportingBackup = false
  /// 백업 import 시트 표시 여부.
  var isImportingBackup = false

  /// CSV 종류 — 어떤 importer 를 돌릴지, 어떤 템플릿을 줄지 구분.
  enum CSVKind: String, CaseIterable, Identifiable {
    case items
    case recipes
    case recipeIngredients

    var id: String { rawValue }
  }

  /// 현재 import/export 중인 CSV 종류(시트 컨텍스트).
  var activeCSVKind: CSVKind?
  /// CSV import 시트 표시 여부.
  var isImportingCSV = false
  /// CSV 템플릿 export 문서.
  var csvDocument: CSVDocument?
  /// CSV 템플릿 export 시 제안 파일명.
  var csvExportFileName = CSVSchema.itemsFileName
  var isExportingCSV = false

  // MARK: - 백업 export

  /// 전체 데이터를 패키지로 써서 fileExporter 를 띄울 준비를 한다.
  func prepareBackupExport(modelContext: ModelContext) {
    status = .working(String(localized: "Preparing backup…"))
    do {
      let payload = try BackupArchive.makeExportPayload(from: modelContext)
      backupExportBaseName = payload.fileBaseName
      backupDocument = BackupDocument(payload: payload)
      isExportingBackup = true
      status = .idle
    } catch {
      status = .failure(error.localizedDescription)
    }
  }

  /// 백업 export 시 제안 파일명(베이스 이름, 확장자 제외 — 시스템이 contentType 으로 붙임).
  func backupExportFileName() -> String {
    backupExportBaseName
  }

  /// fileExporter 완료 콜백 처리.
  func handleBackupExportResult(_ result: Result<URL, Error>) {
    isExportingBackup = false
    backupDocument = nil
    switch result {
    case let .success(url):
      status = .success(String(localized: "Backup saved to \(url.lastPathComponent)."))
    case let .failure(error):
      status = .failure(error.localizedDescription)
    }
  }

  // MARK: - 백업 import

  func handleBackupImportResult(_ result: Result<[URL], Error>, modelContext: ModelContext) {
    isImportingBackup = false
    switch result {
    case let .success(urls):
      guard let url = urls.first else { return }
      runBackupImport(from: url, modelContext: modelContext)
    case let .failure(error):
      status = .failure(error.localizedDescription)
    }
  }

  private func runBackupImport(from url: URL, modelContext: ModelContext) {
    status = .working(String(localized: "Importing backup…"))
    do {
      let summary = try BackupArchive.import(from: url, into: modelContext)
      status = .success(summary.headline)
    } catch {
      status = .failure(error.localizedDescription)
    }
  }

  // MARK: - CSV export (템플릿)

  func prepareCSVTemplateExport(_ kind: CSVKind) {
    let (fileName, content) = Self.csvTemplate(for: kind)
    csvDocument = CSVDocument(text: content)
    // fileExporter 의 defaultFilename 은 확장자를 contentType 으로 붙이므로 베이스만.
    csvExportFileName = (fileName as NSString).deletingPathExtension
    activeCSVKind = kind
    isExportingCSV = true
  }

  func handleCSVExportResult(_ result: Result<URL, Error>) {
    isExportingCSV = false
    csvDocument = nil
    switch result {
    case .success:
      status = .success(String(localized: "CSV template saved."))
    case let .failure(error):
      status = .failure(error.localizedDescription)
    }
  }

  // MARK: - CSV import

  func beginCSVImport(_ kind: CSVKind) {
    activeCSVKind = kind
    isImportingCSV = true
  }

  func handleCSVImportResult(_ result: Result<[URL], Error>, modelContext: ModelContext) {
    isImportingCSV = false
    guard let kind = activeCSVKind else { return }
    switch result {
    case let .success(urls):
      guard let url = urls.first else { return }
      runCSVImport(kind, from: url, modelContext: modelContext)
    case let .failure(error):
      status = .failure(error.localizedDescription)
    }
  }

  private func runCSVImport(_ kind: CSVKind, from url: URL, modelContext: ModelContext) {
    status = .working(String(localized: "Importing CSV…"))
    let needsScope = url.startAccessingSecurityScopedResource()
    defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
    do {
      let content = try String(contentsOf: url, encoding: .utf8)
      let importer = CSVImporter(modelContext: modelContext)
      let summary: ImportSummary = switch kind {
      case .items: try importer.importItems(content)
      case .recipes: try importer.importRecipes(content)
      case .recipeIngredients: try importer.importRecipeIngredients(content)
      }
      status = .success(summary.headline)
    } catch {
      status = .failure(error.localizedDescription)
    }
  }

  // MARK: - 템플릿 매핑

  static func csvTemplate(for kind: CSVKind) -> (fileName: String, content: String) {
    switch kind {
    case .items:
      (CSVSchema.itemsFileName, CSVSchema.itemsTemplate())
    case .recipes:
      (CSVSchema.recipesFileName, CSVSchema.recipesTemplate())
    case .recipeIngredients:
      (CSVSchema.recipeIngredientsFileName, CSVSchema.recipeIngredientsTemplate())
    }
  }
}

/// 백업 패키지 UTType(`com.sro.homepinappios.backup`, exported, directory 기반).
extension UTType {
  static var homePinBackup: UTType {
    UTType(exportedAs: "com.sro.homepinappios.backup")
  }
}
