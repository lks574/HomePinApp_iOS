import Foundation

/// RFC4180 최소 자체 구현 CSV 파서/직렬화(외부 의존성 없음).
///
/// 지원: 따옴표 필드, 필드 내 콤마/개행, `""` 이스케이프, CRLF/LF.
/// 첫 행은 헤더로 본다. 빈 줄(끝의 개행)은 무시한다.
enum CSV {
  /// 파싱 결과 — 헤더와 행(헤더→값 딕셔너리).
  struct Table {
    var header: [String]
    var rows: [[String: String]]
  }

  // MARK: - Parse

  /// CSV 문자열을 행 배열(필드 배열)로 파싱한다.
  static func parseRows(_ text: String) -> [[String]] {
    var rows: [[String]] = []
    var field = ""
    var record: [String] = []
    var inQuotes = false
    var iterator = text.makeIterator()
    var pending: Character?

    func nextChar() -> Character? {
      if let p = pending { pending = nil; return p }
      return iterator.next()
    }

    while let char = nextChar() {
      if inQuotes {
        if char == "\"" {
          if let following = nextChar() {
            if following == "\"" {
              field.append("\"") // 이스케이프된 따옴표
            } else {
              inQuotes = false
              pending = following
            }
          } else {
            inQuotes = false
          }
        } else {
          field.append(char)
        }
      } else {
        switch char {
        case "\"":
          inQuotes = true
        case ",":
          record.append(field)
          field = ""
        case "\n":
          record.append(field)
          rows.append(record)
          field = ""
          record = []
        case "\r":
          // CRLF: 다음 \n 은 개행 처리에서 흡수. 단독 \r 도 개행으로 본다.
          if let following = nextChar(), following != "\n" {
            pending = following
          }
          record.append(field)
          rows.append(record)
          field = ""
          record = []
        default:
          field.append(char)
        }
      }
    }

    // 마지막 필드/행(끝에 개행이 없을 때).
    if !field.isEmpty || !record.isEmpty {
      record.append(field)
      rows.append(record)
    }

    // 완전히 빈 행 제거(필드 1개이고 비어 있음).
    return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
  }

  /// 헤더가 있는 테이블로 파싱한다(첫 행=헤더).
  static func parseTable(_ text: String) -> Table {
    let rows = parseRows(text)
    guard let header = rows.first else { return Table(header: [], rows: []) }
    let dataRows = rows.dropFirst().map { values -> [String: String] in
      var dict: [String: String] = [:]
      for (index, key) in header.enumerated() {
        dict[key] = index < values.count ? values[index] : ""
      }
      return dict
    }
    return Table(header: header, rows: Array(dataRows))
  }

  // MARK: - Serialize

  /// 헤더 + 행을 RFC4180 CSV 문자열로 직렬화한다(LF 개행).
  static func serialize(header: [String], rows: [[String]]) -> String {
    var lines = [header.map(escapeField).joined(separator: ",")]
    for row in rows {
      lines.append(row.map(escapeField).joined(separator: ","))
    }
    return lines.joined(separator: "\n") + "\n"
  }

  /// 콤마/따옴표/개행이 있으면 따옴표로 감싸고 내부 따옴표를 `""` 로 이스케이프한다.
  static func escapeField(_ value: String) -> String {
    guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
      return value
    }
    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}
