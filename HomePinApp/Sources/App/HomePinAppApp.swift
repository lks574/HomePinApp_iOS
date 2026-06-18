import SwiftData
import SwiftUI

@main
struct HomePinAppApp: App {
  #if os(iOS)
  @UIApplicationDelegateAdaptor(CloudSharingAppDelegate.self) private var cloudSharingAppDelegate
  #endif

  let modelContainer = AppModelContainer.make()

  var body: some Scene {
    WindowGroup {
      AppRootView()
    }
    .modelContainer(modelContainer)
  }
}
