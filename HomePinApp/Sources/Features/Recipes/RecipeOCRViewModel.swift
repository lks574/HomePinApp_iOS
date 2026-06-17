import Foundation
import os

/// 레시피 OCR 입력기의 UI 상태 소유자. 사진 라이브러리·카메라에서 받은 이미지를 비-MainActor
/// `TextRecognizer` 로 인식해, 결과 텍스트를 호출 측(`RecipeCaptureView`)이 입력 필드에 채우게 한다.
/// OCR 은 "텍스트를 얻는 또 하나의 방법" 일 뿐, 파싱·확인·저장은 단계 1 텍스트 경로를 그대로 쓴다.
///
/// 인식 자체는 무거운 동기 추론이라 `SpeechDictationViewModel` 과 같은 결로 **단일 세션 Task** 를
/// 소유하고, 새 인식이 시작되면 이전 Task 를 취소한다(연타·이미지 교체 시 고아 Task 방지).
/// 결과는 `recognizedText` 로 한 번 emit 하고 호출 측이 `onChange` 로 받아 입력 필드에 채운다.
@MainActor
@Observable
final class RecipeOCRViewModel {
  enum State: Equatable {
    case idle
    /// 인식 중(진행 표시).
    case recognizing
    /// 인식 성공(빈 결과 포함은 호출 측에서 안내). 텍스트를 한 번 전달하고 idle 로 돌아간다.
    case recognized
    /// Vision 오류·손상 이미지 등 인식 실패.
    case failed
    /// 인식했지만 텍스트를 한 글자도 찾지 못함(폴백 안내).
    case empty
  }

  private(set) var state: State = .idle

  /// 인식된 텍스트의 일회성 전달 채널. 호출 측이 `onChange` 로 받아 입력 필드에 채운 뒤 비운다.
  private(set) var recognizedText = ""

  private let recognizer = TextRecognizer()
  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "RecipeOCRViewModel")

  /// 현재 인식을 수행하는 단일 Task. 동시에 둘 이상 두지 않는다.
  private var recognizeTask: Task<Void, Never>?

  var isRecognizing: Bool {
    state == .recognizing
  }

  /// 이미지에서 텍스트를 인식한다. 진행 중이던 인식은 취소하고 새로 시작한다.
  /// 인식은 배경(`Task.detached`)에서 수행하고, 결과 문자열만 MainActor 로 가져온다.
  func recognize(_ image: PlatformImage) {
    cancel()
    state = .recognizing

    let recognizer = recognizer
    recognizeTask = Task { [weak self] in
      let result = await Task.detached(priority: .userInitiated) { () -> Result<String, Error> in
        do {
          return .success(try recognizer.recognizeText(in: image))
        } catch {
          return .failure(error)
        }
      }.value

      guard !Task.isCancelled else { return }
      self?.apply(result)
    }
  }

  /// 일회성 전달 채널을 비운다(호출 측이 텍스트를 채운 뒤). 멱등.
  func clearRecognizedText() {
    recognizedText = ""
  }

  /// 진행 중 인식을 취소한다(이미지 교체·화면 종료). 멱등.
  func cancel() {
    recognizeTask?.cancel()
    recognizeTask = nil
    if state == .recognizing {
      state = .idle
    }
  }

  /// 상태와 전달 채널을 초기화한다(화면 종료 시).
  func reset() {
    cancel()
    recognizedText = ""
    state = .idle
  }

  private func apply(_ result: Result<String, Error>) {
    switch result {
    case let .success(text):
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
        state = .empty
        return
      }
      recognizedText = trimmed
      state = .recognized
    case let .failure(error):
      logger.error("레시피 OCR 실패: \(error.localizedDescription, privacy: .public)")
      state = .failed
    }
  }
}
