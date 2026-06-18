#if canImport(Vision)
import CoreGraphics
import Foundation
import os

/// 영수증 스캔 화면의 UI 상태 소유자. 이미지(CGImage) → OCR → 규칙 필터 → 품목 라인까지를
/// 비-MainActor 에서 수행하고, 결과(텍스트)만 MainActor 로 가져온다(STT/기존 OCR VM 패턴).
///
/// 단일 인식 Task 를 소유하고, 새 인식 시작·취소 시 cancel 한다 — 고아 Task 가 다음 인식으로
/// 새지 않는다. 영수증 이미지는 보관하지 않는다(인식 입력으로만 쓰고 버린다).
@MainActor
@Observable
final class ReceiptScanViewModel {
  enum State: Equatable {
    case idle
    case recognizing
    /// 품목 라인 추출 성공(빈 배열 아님).
    case recognized(lines: [String])
    /// 인식은 됐지만 품목 라인이 0건.
    case empty
    /// OCR 자체 실패(이미지 변환·Vision 오류).
    case failed
  }

  private(set) var state: State = .idle

  private let recognizer = ReceiptTextRecognizer()
  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "ReceiptScanViewModel")

  /// 현재 인식 Task. 동시에 둘 이상 두지 않는다.
  private var recognizeTask: Task<Void, Never>?

  /// 이미지에서 품목 라인을 인식한다. 이전 Task 는 취소하고 새로 연다.
  /// 결과 라인은 `state` 의 `.recognized`/`.empty`/`.failed` 로 노출한다.
  func recognize(_ image: CGImage) {
    cancel()
    state = .recognizing
    let recognizer = recognizer
    recognizeTask = Task { [weak self] in
      let outcome: State = await Self.run(recognizer: recognizer, image: image)
      guard !Task.isCancelled else { return }
      if outcome == .failed {
        self?.logger.error("영수증 OCR 인식 실패")
      }
      self?.state = outcome
    }
  }

  /// 인식 Task 를 취소하고 상태를 idle 로 되돌린다(시트 닫기·재시도 직전).
  func cancel() {
    recognizeTask?.cancel()
    recognizeTask = nil
    if state == .recognizing { state = .idle }
  }

  /// 이미지 로드/변환이 OCR 전에 실패했을 때(데이터 디코드 실패 등) 호출한다.
  func markFailed() {
    cancel()
    state = .failed
  }

  /// 비-MainActor 에서 OCR + 규칙 필터를 수행한다. 텍스트(값 타입)만 반환한다.
  private static func run(recognizer: ReceiptTextRecognizer, image: CGImage) async -> State {
    await Task.detached(priority: .userInitiated) {
      do {
        let rawLines = try recognizer.recognize(in: image)
        let itemLines = ReceiptLineFilter.itemLines(from: rawLines)
        return itemLines.isEmpty ? .empty : .recognized(lines: itemLines)
      } catch {
        return .failed
      }
    }.value
  }
}
#endif
