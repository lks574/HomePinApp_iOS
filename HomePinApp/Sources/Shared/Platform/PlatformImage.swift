import CoreImage
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 플랫폼별 이미지 타입 추상화. iOS 는 `UIImage`, macOS 는 `NSImage` 를 가리킨다.
///
/// 사진 라이브러리·카메라·파일에서 받은 정지 이미지를 Vision OCR 로 넘기거나 SwiftUI 로
/// 표시하는 경로에서, 호출 측이 플랫폼 분기를 직접 들지 않도록 단일 타입과 헬퍼로 모은다.
/// Vision 자체는 cross-platform 이라 `CGImage`+orientation 만 일관되게 뽑아 주면 된다.
#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

extension PlatformImage {
  /// 원본 데이터에서 플랫폼 이미지를 만든다. 손상·미지원 포맷이면 nil.
  static func from(data: Data) -> PlatformImage? {
    PlatformImage(data: data)
  }

  /// Vision 이 요구하는 `CGImage` 로 변환한다. `CGImage` 백킹이 없으면(예: CIImage 백킹
  /// 사진 라이브러리 이미지) `CIContext` 로 한 번 굽는다. 변환 불가면 nil.
  var platformCGImage: CGImage? {
    #if os(macOS)
    if let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) {
      return cgImage
    }
    return ciBackedCGImage
    #else
    return cgImage ?? ciBackedCGImage
    #endif
  }

  /// Vision 에 넘길 이미지 회전 메타데이터. iOS 카메라 사진은 `imageOrientation` 을 가질 수
  /// 있어 그대로 옮긴다. macOS `NSImage` 는 `cgImage(forProposedRect:...)` 가 이미 올바른
  /// 방향으로 렌더한 비트맵을 돌려주므로 항상 `.up` 이다.
  var platformCGImageOrientation: CGImagePropertyOrientation {
    #if os(macOS)
    return .up
    #else
    switch imageOrientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
    #endif
  }

  /// `CGImage` 가 비어 있는(`CIImage` 백킹) 이미지 대비. `CIContext` 로 한 번 굽는다.
  private var ciBackedCGImage: CGImage? {
    #if os(macOS)
    guard let tiff = tiffRepresentation, let ciImage = CIImage(data: tiff) else { return nil }
    #else
    guard let ciImage else { return nil }
    #endif
    return CIContext().createCGImage(ciImage, from: ciImage.extent)
  }
}

extension Image {
  /// 플랫폼 이미지를 SwiftUI `Image` 로 감싼다(사용처에서 분기 없이 표시).
  init(platformImage: PlatformImage) {
    #if os(macOS)
    self.init(nsImage: platformImage)
    #else
    self.init(uiImage: platformImage)
    #endif
  }
}
