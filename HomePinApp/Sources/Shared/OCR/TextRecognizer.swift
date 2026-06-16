import CoreImage
import Foundation
import os
import UIKit
import Vision

/// 온디바이스 텍스트 인식기(이미지 → 텍스트). 사진 라이브러리·카메라에서 고른 정지 이미지를
/// Apple Vision(`VNRecognizeTextRequest`)으로 인식해 줄바꿈을 보존한 한 덩어리 텍스트로 돌려준다.
/// 서버/네트워크를 쓰지 않는다(서버리스 원칙).
///
/// Vision 을 고른 이유: `recognitionLanguages`(한국어+영어)·`.accurate`·`usesLanguageCorrection`
/// 을 직접 제어할 수 있고, 라이브 스캐너(`DataScannerViewController`)와 달리 "고른 한 장에서
/// 텍스트를 뽑는다" 는 이번 용례에 그대로 맞는다.
///
/// `@MainActor` 가 아니다. Vision 추론은 무겁고 동기적이라 호출 측이 `Task.detached` 등으로
/// 배경에서 돌린 뒤 결과 문자열만 MainActor 로 가져가게 한다. 상태를 들지 않는 값 타입이라
/// `Sendable` 이다.
struct TextRecognizer: Sendable {
  /// 인식 언어 우선순위. 한국어 레시피·영어 레시피 모두 커버한다.
  private static let recognitionLanguages = ["ko-KR", "en-US"]

  private let logger = Logger(subsystem: "com.sro.homepinappios", category: "TextRecognizer")

  /// 이미지에서 텍스트를 인식한다. 인식 결과가 없으면 빈 문자열을 돌려준다(실패와 구분은
  /// throw 로 한다 — 잘못된 이미지/Vision 오류만 throw).
  ///
  /// 비-MainActor 에서 동기 추론한다. 호출 측이 배경 컨텍스트에서 await 로 부른다.
  func recognizeText(in image: UIImage) throws -> String {
    guard let cgImage = image.cgImage ?? ciBackedCGImage(from: image) else {
      throw TextRecognitionError.invalidImage
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = Self.recognitionLanguages

    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgImageOrientation(from: image), options: [:])
    do {
      try handler.perform([request])
    } catch {
      logger.error("텍스트 인식 실패: \(error.localizedDescription, privacy: .public)")
      throw TextRecognitionError.recognitionFailed
    }

    let observations = request.results ?? []
    // 각 관찰의 최상위 후보를 줄 단위로 모은다. Vision 은 위→아래 순서를 보장하지 않으므로
    // 박스 세로 위치(정규화 좌표, 원점 좌하단)로 정렬해 읽기 순서를 복원한다.
    let lines = observations
      .compactMap { observation -> (top: CGFloat, text: String)? in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let trimmed = candidate.string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return (top: observation.boundingBox.maxY, text: trimmed)
      }
      .sorted { $0.top > $1.top }
      .map(\.text)

    return lines.joined(separator: "\n")
  }

  /// `cgImage` 가 비어 있는(`CIImage` 백킹) 사진 라이브러리 이미지 대비. CIContext 로 한 번 굽는다.
  private func ciBackedCGImage(from image: UIImage) -> CGImage? {
    guard let ciImage = image.ciImage else { return nil }
    return CIContext().createCGImage(ciImage, from: ciImage.extent)
  }

  /// `UIImage.imageOrientation` 을 Vision 이 이해하는 `CGImagePropertyOrientation` 으로 옮긴다.
  /// 카메라 사진은 회전 메타데이터를 가질 수 있어 그대로 두면 인식 정확도가 떨어진다.
  private func cgImageOrientation(from image: UIImage) -> CGImagePropertyOrientation {
    switch image.imageOrientation {
    case .up: .up
    case .down: .down
    case .left: .left
    case .right: .right
    case .upMirrored: .upMirrored
    case .downMirrored: .downMirrored
    case .leftMirrored: .leftMirrored
    case .rightMirrored: .rightMirrored
    @unknown default: .up
    }
  }
}

/// 텍스트 인식 실패 사유. 호출 측은 현지화한 안내로 바꿔 보여준다.
enum TextRecognitionError: Error {
  /// 이미지를 `CGImage` 로 변환할 수 없음(손상·미지원 포맷).
  case invalidImage
  /// Vision 요청 수행 실패.
  case recognitionFailed
}
