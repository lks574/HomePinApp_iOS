import Foundation
import SwiftData

/// 백업 디렉터리 패키지(`.homepinbackup`)의 export/import I/O.
///
/// 외부 의존성 없이 `FileManager` 만으로 처리한다(ZIP 불채택).
/// 패키지 레이아웃: `data.json`(메타+엔티티).
///
/// 결정: `docs/wiki/Decision/2026-06-17-데이터-백업-번들포맷.md`
@MainActor
enum BackupArchive {
  enum ArchiveError: LocalizedError {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case missingDataFile
    case writeFailed(String)

    var errorDescription: String? {
      switch self {
      case let .unsupportedSchemaVersion(found, supported):
        String(localized: "Backup schema v\(found) is newer than supported v\(supported). Update the app to import it.")
      case .missingDataFile:
        String(localized: "The backup is missing its data file (\(BackupBundleLayout.dataFileName)).")
      case let .writeFailed(detail):
        String(localized: "Failed to write the backup: \(detail)")
      }
    }
  }

  // MARK: - Export

  /// 백업 패키지를 fileExporter 로 내보내기 위한 메모리 페이로드.
  /// 임시 파일을 거치지 않고 `BackupDocument` 가 이 데이터로 디렉터리 FileWrapper 를 구성한다.
  struct ExportPayload {
    /// `data.json` 직렬화 결과.
    let dataJSON: Data
    /// 제안 파일명(확장자 제외 — 시스템이 contentType 으로 붙인다).
    let fileBaseName: String
  }

  /// 전체 데이터를 메모리 페이로드로 만든다(디스크 임시 파일 없음).
  static func makeExportPayload(from modelContext: ModelContext) throws -> ExportPayload {
    let bundle = try makeBundle(from: modelContext)
    let dataJSON = try BackupCodec.makeEncoder().encode(bundle)
    return ExportPayload(
      dataJSON: dataJSON,
      fileBaseName: makeFileBaseName(),
    )
  }

  /// 전체 fetch → DTO 번들(메타 포함).
  static func makeBundle(from modelContext: ModelContext) throws -> BackupBundle {
    BackupBundle(
      schemaVersion: BackupBundle.currentSchemaVersion,
      exportedAt: .now,
      spaces: try modelContext.fetch(FetchDescriptor<Space>()).map(BackupCodec.makeDTO),
      areas: try modelContext.fetch(FetchDescriptor<Area>()).map(BackupCodec.makeDTO),
      spots: try modelContext.fetch(FetchDescriptor<Spot>()).map(BackupCodec.makeDTO),
      categories: try modelContext.fetch(FetchDescriptor<ItemCategory>()).map(BackupCodec.makeDTO),
      tags: try modelContext.fetch(FetchDescriptor<Tag>()).map(BackupCodec.makeDTO),
      items: try modelContext.fetch(FetchDescriptor<Item>()).map(BackupCodec.makeDTO),
      recipes: try modelContext.fetch(FetchDescriptor<Recipe>()).map(BackupCodec.makeDTO),
      recipeIngredients: try modelContext.fetch(FetchDescriptor<RecipeIngredient>()).map(BackupCodec.makeDTO),
      shoppingItems: try modelContext.fetch(FetchDescriptor<ShoppingItem>()).map(BackupCodec.makeDTO),
    )
  }

  private static func makeFileBaseName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return "HomePin-\(formatter.string(from: .now))"
  }

  // MARK: - Import

  /// 패키지 URL 을 읽어 decode → schemaVersion 가드 → 2-pass upsert.
  static func `import`(from packageURL: URL, into modelContext: ModelContext) throws -> ImportSummary {
    let needsSecurityScope = packageURL.startAccessingSecurityScopedResource()
    defer { if needsSecurityScope { packageURL.stopAccessingSecurityScopedResource() } }

    let dataURL = packageURL.appendingPathComponent(BackupBundleLayout.dataFileName)
    guard FileManager.default.fileExists(atPath: dataURL.path) else {
      throw ArchiveError.missingDataFile
    }

    let data = try Data(contentsOf: dataURL)
    let bundle = try BackupCodec.makeDecoder().decode(BackupBundle.self, from: data)

    guard bundle.schemaVersion <= BackupBundle.currentSchemaVersion else {
      throw ArchiveError.unsupportedSchemaVersion(
        found: bundle.schemaVersion,
        supported: BackupBundle.currentSchemaVersion,
      )
    }

    let engine = BackupUpsertEngine(modelContext: modelContext)
    let summary = try engine.apply(bundle)

    try modelContext.save()
    return summary
  }
}
