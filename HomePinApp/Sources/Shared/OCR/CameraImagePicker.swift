import SwiftUI

#if os(iOS)
import UIKit

/// 카메라 즉석 촬영용 `UIImagePickerController` 래퍼. 요리책·메모를 그 자리에서 찍어 OCR 에 넘긴다.
/// (사진 라이브러리는 SwiftUI 네이티브 `PhotosPicker` 를 쓰므로 여기엔 카메라 소스만 둔다.)
///
/// 카메라 권한(`NSCameraUsageDescription`)은 `UIImagePickerController` 가 시스템 시트로 직접
/// 요청·안내하므로 별도 권한 흐름을 두지 않는다. 거부되면 시스템이 설정 안내를 띄우고 시트는
/// 비고, 사용자는 닫고 텍스트 입력을 계속 쓸 수 있다(폴백 보장).
struct CameraImagePicker: UIViewControllerRepresentable {
  /// 촬영 완료 시 이미지를 전달한다. 취소면 호출되지 않는다.
  let onCapture: (UIImage) -> Void
  @Environment(\.dismiss) private var dismiss

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onCapture: onCapture, onFinish: { dismiss() })
  }

  /// `UIImagePickerControllerDelegate` 콜백은 메인 큐 보장이 약해 `@MainActor` 타입 안에서
  /// 만들면 런타임 격리 트랩으로 크래시날 수 있다. Coordinator 를 nonisolated 타입으로 분리하고,
  /// 콜백 안에서 `MainActor` 작업만 명시적으로 hop 해 안전하게 처리한다.
  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let onCapture: (UIImage) -> Void
    private let onFinish: () -> Void

    init(onCapture: @escaping (UIImage) -> Void, onFinish: @escaping () -> Void) {
      self.onCapture = onCapture
      self.onFinish = onFinish
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any],
    ) {
      let image = info[.originalImage] as? UIImage
      let capture = onCapture
      let finish = onFinish
      Task { @MainActor in
        if let image {
          capture(image)
        }
        finish()
      }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      let finish = onFinish
      Task { @MainActor in finish() }
    }
  }
}
#endif

extension View {
  /// 카메라 즉석 촬영 시트를 띄운다(촬영 완료 시 이미지 전달). iOS 에서만 카메라 picker 를
  /// 풀스크린으로 띄우고, macOS 에서는 카메라 진입점이 없으므로 no-op 이다(호출 측이 카메라
  /// 버튼 자체를 `cameraAvailable` 로 숨기므로 macOS 에서 트리거되지 않는다).
  @ViewBuilder
  func cameraCaptureCover(
    isPresented: Binding<Bool>,
    onCapture: @escaping (PlatformImage) -> Void,
  ) -> some View {
    #if os(iOS)
    fullScreenCover(isPresented: isPresented) {
      CameraImagePicker(onCapture: onCapture)
        .ignoresSafeArea()
    }
    #else
    self
    #endif
  }
}
