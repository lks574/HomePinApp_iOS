#if canImport(Vision)
import CoreGraphics
import Foundation
import Vision

/// 영수증 이미지 → 텍스트 줄(line) 추출 엔진. Vision `VNRecognizeTextRequest` 로 글자만 읽는다.
///
/// **추출만** 한다 — 품목/비품목 분류·칩 적재·SwiftData 는 모른다(`ReceiptLineFilter`·`CaptureSheet`
/// 가 도메인 측에서 한다). 영수증 이미지는 영속화하지 않는다(메모리에서만 인식하고 버린다).
/// FoundationModels 를 쓰지 않는다(확정) — 규칙 필터로 충분하고 온디바이스 비용/표류를 피한다.
///
/// 동시성: `@MainActor` 가 아니다(`Sendable`). 호출 측(`ReceiptScanViewModel`)이 단일 인식 Task
/// 안에서 `recognize(in:)` 를 호출하고, 결과 텍스트만 MainActor 로 가져간다 — STT/OCR VM 패턴.
struct ReceiptTextRecognizer: Sendable {
  enum RecognizeError: Error {
    case requestFailed
  }

  /// 이미지에서 인식한 텍스트 줄들을 위→아래 순서로 반환한다(빈 줄 제외).
  /// `.accurate` + 언어 교정 + ko/en 인식. 호출은 비-MainActor 컨텍스트에서 한다.
  func recognize(in image: CGImage) throws -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["ko-KR", "en-US"]

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
      try handler.perform([request])
    } catch {
      throw RecognizeError.requestFailed
    }

    let observations = request.results ?? []
    return observations
      .compactMap { $0.topCandidates(1).first?.string }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
#endif
