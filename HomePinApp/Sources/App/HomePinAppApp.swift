import SwiftData
import SwiftUI

@main
struct HomePinAppApp: App {
  let modelContainer = AppModelContainer.make()

  var body: some Scene {
    WindowGroup {
      AppRootView()
    }
    .modelContainer(modelContainer)
  }
}
