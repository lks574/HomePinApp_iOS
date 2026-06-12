import SwiftData
import SwiftUI

@main
struct HomePinAppApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(for: Item.self)
  }
}
