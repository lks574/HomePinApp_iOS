import SwiftData
import SwiftUI

@main
struct HomePinAppApp: App {
  #if os(iOS)
  @UIApplicationDelegateAdaptor(CloudSharingAppDelegate.self) private var cloudSharingAppDelegate
  #endif

  let modelContainer = AppModelContainer.make()

  init() {
    // Firebase(Analytics·Crashlytics·RemoteConfig)를 가능한 한 이르게 구성한다.
    // GoogleService-Info.plist 가 없으면 내부에서 skip 한다(앱은 정상 진행).
    FirebaseBootstrap.configureIfAvailable()
  }

  var body: some Scene {
    WindowGroup {
      AppRootView()
    }
    .modelContainer(modelContainer)
  }
}
