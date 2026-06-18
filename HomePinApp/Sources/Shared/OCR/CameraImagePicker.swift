#if os(iOS)
import SwiftUI
import UIKit

/// 카메라 촬영 래퍼. `UIImagePickerController(.camera)` 를 SwiftUI 로 감싸 영수증 한 장을 찍는다.
///
/// Coordinator 는 **nonisolated NSObject** 로 분리하고, delegate 콜백 안에서만
/// `Task { @MainActor in }` 으로 hop 한다. `@MainActor` 타입 안에 시스템 콜백 클로저를 두면
/// 런타임 격리 트랩으로 크래시하므로 의도적으로 분리한다(프로젝트에 기록된 함정).
///
/// 카메라 이미지 자체는 저장하지 않는다 — 호출부가 받아 OCR 후 버린다.
struct CameraImagePicker: UIViewControllerRepresentable {
  /// 촬영 완료(이미지) 또는 취소(nil) 시 호출. MainActor 에서 호출된다.
  let onResult: (UIImage?) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onResult: onResult)
  }

  /// nonisolated NSObject delegate. 시스템이 임의 스레드/격리 없이 콜백하므로 여기서 MainActor 로 hop 한다.
  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let onResult: (UIImage?) -> Void

    init(onResult: @escaping (UIImage?) -> Void) {
      self.onResult = onResult
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      let image = info[.originalImage] as? UIImage
      let result = onResult
      Task { @MainActor in result(image) }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      let result = onResult
      Task { @MainActor in result(nil) }
    }
  }
}

extension UIImagePickerController {
  /// 이 기기에서 카메라 촬영이 가능한지(시뮬레이터는 false → 호출부가 카메라 버튼을 숨긴다).
  static var cameraAvailable: Bool {
    isSourceTypeAvailable(.camera)
  }
}
#endif
