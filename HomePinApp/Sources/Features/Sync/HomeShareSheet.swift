#if os(iOS)
import CloudKit
import SwiftUI
import UIKit

struct HomeShareSheet: UIViewControllerRepresentable {
  let presentation: HomeSharePresentation

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIViewController(context: Context) -> UICloudSharingController {
    let controller = UICloudSharingController(
      share: presentation.share,
      container: presentation.container
    )
    controller.availablePermissions = [.allowPrivate, .allowReadWrite]
    controller.delegate = context.coordinator
    return controller
  }

  func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

  final class Coordinator: NSObject, UICloudSharingControllerDelegate {
    func cloudSharingController(
      _ csc: UICloudSharingController,
      failedToSaveShareWithError error: Error
    ) {
      print("CloudKit share save failed: \(error)")
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
      "HomePin Home"
    }

    func itemType(for csc: UICloudSharingController) -> String? {
      "Home data"
    }
  }
}
#endif
