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
        let container = CKContainer(identifier: CloudSyncPreference.containerIdentifier)
        let results = try await container.accept([cloudKitShareMetadata])
        if case let .failure(error) = results[cloudKitShareMetadata] {
          print("CloudKit share accept failed: \(error)")
        }
      } catch {
        print("CloudKit share accept failed: \(error)")
      }
    }
  }
}
#endif
