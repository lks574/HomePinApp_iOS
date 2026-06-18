import SwiftUI
import UniformTypeIdentifiers

/// 백업 디렉터리 패키지를 fileExporter 로 내보내기 위한 `FileDocument` 래퍼.
///
/// 디스크 임시 파일을 거치지 않고 메모리 페이로드로 **디렉터리 FileWrapper 를 직접 구성**한다.
/// (URL 기반 `FileWrapper(url:)` 는 fileExporter 쓰기에서 "파일이 이미 존재" 에러·패키지
/// 누락을 일으켜 폐기했다.) 레이아웃: `data.json`.
struct BackupDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.homePinBackup] }
  static var writableContentTypes: [UTType] { [.homePinBackup] }

  /// export 페이로드. import 읽기는 fileImporter(URL 직접 처리)로 하므로 쓰지 않는다.
  var payload: BackupArchive.ExportPayload?

  init(payload: BackupArchive.ExportPayload) {
    self.payload = payload
  }

  init(configuration: ReadConfiguration) throws {
    payload = nil
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    guard let payload else {
      throw CocoaError(.fileWriteUnknown)
    }

    let root = FileWrapper(directoryWithFileWrappers: [:])

    let dataWrapper = FileWrapper(regularFileWithContents: payload.dataJSON)
    dataWrapper.preferredFilename = BackupBundleLayout.dataFileName
    root.addFileWrapper(dataWrapper)

    return root
  }
}

/// CSV 텍스트 파일을 fileExporter 로 내보내기 위한 `FileDocument` 래퍼(템플릿용).
struct CSVDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.commaSeparatedText] }
  static var writableContentTypes: [UTType] { [.commaSeparatedText] }

  var text: String

  init(text: String) {
    self.text = text
  }

  init(configuration: ReadConfiguration) throws {
    if let data = configuration.file.regularFileContents {
      text = String(decoding: data, as: UTF8.self)
    } else {
      text = ""
    }
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}
