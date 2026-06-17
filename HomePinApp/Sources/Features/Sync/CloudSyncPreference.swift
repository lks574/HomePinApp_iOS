import CloudKit
import Foundation
import Observation

enum CloudSyncPreference {
  static let storageKey = "cloudSync.isEnabled"
  static let fallbackReasonKey = "cloudSync.fallbackReason"
  static let containerIdentifier = "iCloud.com.sro.homepinapp"

  static func clearFallbackReason() {
    UserDefaults.standard.removeObject(forKey: fallbackReasonKey)
  }

  static func disableAfterStartupFailure(_ error: Error) {
    UserDefaults.standard.set(false, forKey: storageKey)
    UserDefaults.standard.set(
      "iCloud Sync could not start. HomePin is using local storage on this device.",
      forKey: fallbackReasonKey
    )
    #if DEBUG
    print("CloudKit startup fallback: \(error)")
    #endif
  }
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
      await checkAvailability()
    }
  }

  @discardableResult
  func checkAvailability() async -> Bool {
    state = .checking
    do {
      let status = try await CKContainer(identifier: CloudSyncPreference.containerIdentifier).accountStatus()
      state = Self.state(from: status)
    } catch {
      state = .unavailable(error.localizedDescription)
    }
    return state.isAvailable
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

private extension CloudSyncStatusModel.State {
  var isAvailable: Bool {
    self == .available
  }
}
