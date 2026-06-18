#if os(iOS)
import CloudKit
import UIKit

final class CloudSharingAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
  ) {
    Task {
      do {
        try await HomeShareService.acceptShare(cloudKitShareMetadata)
      } catch {
        print("CloudKit share accept failed: \(error)")
      }
    }
  }
}
#endif
