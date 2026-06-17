import CloudKit
import Foundation
import Observation

enum CloudSyncPreference {
  static let storageKey = "cloudSync.isEnabled"
  static let containerIdentifier = "iCloud.com.sro.homepinapp"
}

@MainActor
@Observable
final class CloudSyncStatusModel {
  enum State: Equatable {
    case idle
    case checking
    case available
    case unavailable(String)

    var title: String {
      switch self {
      case .idle: "Not checked"
      case .checking: "Checking..."
      case .available: "Available"
      case let .unavailable(reason): reason
      }
    }
  }

  private(set) var state: State = .idle

  func refresh() {
    state = .checking
    Task {
      do {
        let status = try await CKContainer(identifier: CloudSyncPreference.containerIdentifier).accountStatus()
        state = Self.state(from: status)
      } catch {
        state = .unavailable(error.localizedDescription)
      }
    }
  }

  private static func state(from status: CKAccountStatus) -> State {
    switch status {
    case .available:
      .available
    case .noAccount:
      .unavailable("No iCloud account")
    case .restricted:
      .unavailable("iCloud restricted")
    case .couldNotDetermine:
      .unavailable("Could not determine")
    case .temporarilyUnavailable:
      .unavailable("Temporarily unavailable")
    @unknown default:
      .unavailable("Unknown status")
    }
  }
}
