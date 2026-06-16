import CoreImage
import Foundation
import os
import UIKit
import Vision

/// 온디바이스 텍스트 인식기(이미지 → 텍스트). 사진 라이브러리·카메라에서 고른 정지 이미지를
/// Apple Vision(`VNRecognizeTextRequest`)으로 인식해 줄바꿈을 보존한 한 덩어리 텍스트로 돌려준다.
/// 서버/네트워크를 쓰지 않는다(서버리스 원칙).
///
/// 인식 후에는 관찰을 사람이 읽는 순서(위→아래, 줄 안에서 좌→우)로 복원한다 — 자세한 알고리즘과
/// 좌표계·한계는 `readingOrderText(from:)` 참고. 표/멀티컬럼도 reading-order 근사로 다룬다.
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
    return Self.readingOrderText(from: observations)
  }

  /// Vision 관찰들을 사람이 읽는 순서(위→아래, 줄 안에서 좌→우)로 복원해 텍스트로 합친다.
  ///
  /// Vision 은 관찰을 reading-order 로 보장하지 않고, 단순히 세로 위치(`maxY`)로만 정렬하면
  /// 표/멀티컬럼 레이아웃에서 **같은 행의 여러 열 셀이 좌우로 뒤섞인다**(열 인터리브). 예를 들어
  /// 네이버 표 레시피(구분|재료|포인트 3열)에서 같은 행의 세 셀은 `maxY` 가 비슷해 정렬이
  /// 흔들리면 "포인트 → 구분 → 재료" 처럼 열이 섞인 채 한 줄씩 끊겨 나온다.
  ///
  /// 그래서 정렬을 두 단계로 한다.
  /// 1. **줄 그룹핑**: 세로로 겹치는 조각을 한 줄로 묶는다(위→아래).
  /// 2. **줄 내 정렬**: 한 줄 안에서 가로 위치(`minX`)로 좌→우 정렬해 공백으로 잇는다.
  ///
  /// 좌표계 주의: Vision `boundingBox` 는 **정규화(0~1)** 이고 **원점이 좌하단**이다. 따라서
  /// `maxY`(또는 `midY`)가 **클수록 화면 위쪽**이라 위→아래는 세로 위치 내림차순이다. 같은 줄
  /// 판정은 절대 픽셀이 아니라 정규화 좌표 기준 세로 겹침으로 한다.
  ///
  /// 한계: 표의 **열(셀 격자) 구조 자체는 복원하지 않는다.** 한 행이 "기본 두부1모… 단단한두부…"
  /// 처럼 좌→우로 연속해 읽히면 충분하다(이후 AI 파서가 행 맥락을 이해). 셀 격자 재구성은 범위 밖.
  private static func readingOrderText(from observations: [VNRecognizedTextObservation]) -> String {
    // 각 관찰의 최상위 후보를 (박스, 텍스트) 조각으로 모은다(빈 텍스트 제외).
    let fragments = observations.compactMap { observation -> Fragment? in
      guard let candidate = observation.topCandidates(1).first else { return nil }
      let trimmed = candidate.string.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { return nil }
      return Fragment(box: observation.boundingBox, text: trimmed)
    }

    let lines = groupIntoLines(fragments)
    return lines
      .map { line in
        // 줄 안에서 가로 위치(minX) 좌→우로 정렬해 공백으로 잇는다.
        line
          .sorted { $0.box.minX < $1.box.minX }
          .map(\.text)
          .joined(separator: " ")
      }
      .joined(separator: "\n")
  }

  /// 조각들을 줄 단위로 묶는다. 세로 위치(midY)로 위→아래 정렬한 뒤 순차 누적한다 —
  /// 다음 조각의 세로 중심이 현재 줄의 세로 중심과 충분히 가까우면 같은 줄에 추가하고,
  /// 아니면 새 줄을 시작한다.
  ///
  /// 같은 줄 임계값은 절대값이 아니라 **현재 줄 대표 조각 높이에 비례**(`Self.sameLineHeightRatio`)
  /// 하게 둔다. 표에서 글자 크기가 섞여도 합리적으로 동작하고, 임계값이 너무 크면 다른 줄이
  /// 합쳐지고 너무 작으면 같은 줄이 쪼개지므로 보수적으로(높이의 절반 수준) 잡는다.
  /// 좌하단 원점이라 midY 가 큰 조각이 화면 위쪽이므로 내림차순 정렬이 위→아래다.
  private static func groupIntoLines(_ fragments: [Fragment]) -> [[Fragment]] {
    let sorted = fragments.sorted { $0.box.midY > $1.box.midY }

    var lines: [[Fragment]] = []
    for fragment in sorted {
      // 현재(가장 최근) 줄의 대표 세로 중심·높이와 비교한다. 줄의 첫 조각을 기준으로 삼는다.
      if
        let anchor = lines.last?.first,
        abs(fragment.box.midY - anchor.box.midY) <= anchor.box.height * sameLineHeightRatio {
        lines[lines.count - 1].append(fragment)
      } else {
        lines.append([fragment])
      }
    }
    return lines
  }

  /// 같은 줄로 묶을 세로 중심 허용 오차 = (줄 기준 조각 높이) × 이 비율. 0.6 은 보수적 기본값.
  private static let sameLineHeightRatio: CGFloat = 0.6

  /// reading-order 정렬에 쓰는 관찰 조각. 정규화 박스(원점 좌하단)와 최상위 후보 텍스트.
  private struct Fragment {
    let box: CGRect
    let text: String
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
