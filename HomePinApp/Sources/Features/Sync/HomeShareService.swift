import CloudKit
import Foundation
import SwiftData

struct HomeSharePresentation: Identifiable {
  let id = UUID()
  let share: CKShare
  let container: CKContainer
}

struct HomeShareImportResult {
  let summary: ImportSummary
  let updatedAt: Date?

  var message: String {
    if let updatedAt {
      return String(localized: "Imported shared home data updated at \(updatedAt.formatted(date: .abbreviated, time: .shortened)). \(summary.headline)")
    }
    return summary.headline
  }
}

@MainActor
enum HomeShareService {
  enum ShareError: LocalizedError {
    case acceptedShareNotFound
    case missingSharedRootRecord
    case missingSharedPayload
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case missingSavedRecord(CKRecord.ID)
    case savedRecordFailed(CKRecord.ID, Error)
    case savedRecordTypeMismatch(CKRecord.ID)
    case savedRecordMissing(CKRecord.ID)

    var errorDescription: String? {
      switch self {
      case .acceptedShareNotFound:
        "No accepted shared home data was found. Accept a HomePin sharing invitation first."
      case .missingSharedRootRecord:
        "CloudKit did not provide the shared home record."
      case .missingSharedPayload:
        "The shared home data is missing or cannot be read."
      case let .unsupportedSchemaVersion(found, supported):
        "This shared home data uses schema version \(found), but this app supports up to \(supported)."
      case let .missingSavedRecord(recordID):
        "CloudKit did not return saved record \(recordID.recordName)."
      case let .savedRecordFailed(recordID, error):
        "CloudKit failed to save \(recordID.recordName): \(error.localizedDescription)"
      case let .savedRecordTypeMismatch(recordID):
        "CloudKit returned an unexpected record type for \(recordID.recordName)."
      case let .savedRecordMissing(recordID):
        "CloudKit did not save \(recordID.recordName)."
      }
    }
  }

  private static let zoneName = "HomePinFamilyHome"
  private static let rootRecordName = "homepin-home-root"
  private static let rootRecordType = "HomePinSharedHome"
  private static let shareRecordNameKey = "cloudSync.homeShareRecordName"
  static let acceptedRootRecordNameKey = "cloudSync.acceptedHomeShareRootRecordName"
  static let acceptedRootZoneNameKey = "cloudSync.acceptedHomeShareRootZoneName"
  static let acceptedRootOwnerNameKey = "cloudSync.acceptedHomeShareRootOwnerName"
  static let acceptedAtKey = "cloudSync.acceptedHomeShareAt"
  static let lastImportedAtKey = "cloudSync.lastImportedHomeShareAt"

  static func prepareShare(from modelContext: ModelContext) async throws -> HomeSharePresentation {
    let container = CKContainer(identifier: CloudSyncPreference.containerIdentifier)
    let database = container.privateCloudDatabase
    let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

    try await ensureZone(zoneID, in: database)
    let rootRecordID = CKRecord.ID(recordName: rootRecordName, zoneID: zoneID)
    let rootRecord = try await fetchRecord(rootRecordID, recordType: rootRecordType, in: database)
    try update(rootRecord, from: modelContext)

    if let existingShare = try await fetchExistingShare(in: database, zoneID: zoneID) {
      let result = try await database.modifyRecords(
        saving: [rootRecord],
        deleting: [],
        savePolicy: .changedKeys,
        atomically: true
      )
      _ = try savedRecord(rootRecord.recordID, from: result.saveResults)
      return HomeSharePresentation(share: existingShare, container: container)
    }

    let share = CKShare(rootRecord: rootRecord)
    configure(share)
    let result = try await database.modifyRecords(
      saving: [rootRecord, share],
      deleting: [],
      savePolicy: .changedKeys,
      atomically: true
    )
    _ = try savedRecord(rootRecord.recordID, from: result.saveResults)
    let savedShare = try savedShare(share.recordID, from: result.saveResults)
    UserDefaults.standard.set(savedShare.recordID.recordName, forKey: shareRecordNameKey)
    return HomeSharePresentation(share: savedShare, container: container)
  }

  static func acceptShare(_ metadata: CKShare.Metadata) async throws {
    let container = CKContainer(identifier: metadata.containerIdentifier)
    let results = try await container.accept([metadata])
    if case let .failure(error) = results[metadata] {
      throw error
    }

    guard let rootRecordID = metadata.hierarchicalRootRecordID else {
      throw ShareError.missingSharedRootRecord
    }
    saveAcceptedRootRecordID(rootRecordID)
  }

  static func importAcceptedShare(into modelContext: ModelContext) async throws -> HomeShareImportResult {
    guard let rootRecordID = acceptedRootRecordID() else {
      throw ShareError.acceptedShareNotFound
    }

    let container = CKContainer(identifier: CloudSyncPreference.containerIdentifier)
    let records = try await fetchRecords([rootRecordID], in: container.sharedCloudDatabase)
    guard case let .success(record) = records[rootRecordID] else {
      if case let .failure(error) = records[rootRecordID] {
        throw error
      }
      throw ShareError.missingSharedRootRecord
    }

    let result = try importRecord(record, into: modelContext)
    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastImportedAtKey)
    return result
  }

  private static func ensureZone(_ zoneID: CKRecordZone.ID, in database: CKDatabase) async throws {
    let zones = try await database.recordZones(for: [zoneID])
    if case .success = zones[zoneID] {
      return
    }
    if case let .failure(error) = zones[zoneID], !isUnknownItem(error) {
      throw error
    }
    _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
  }

  private static func fetchRecord(
    _ recordID: CKRecord.ID,
    recordType: CKRecord.RecordType,
    in database: CKDatabase
  ) async throws -> CKRecord {
    let records = try await fetchRecords([recordID], in: database)
    if case let .success(record) = records[recordID] {
      return record
    }
    if case let .failure(error) = records[recordID], !isUnknownItem(error) {
      throw error
    }
    return CKRecord(recordType: recordType, recordID: recordID)
  }

  private static func update(_ record: CKRecord, from modelContext: ModelContext) throws {
    var bundle = try BackupArchive.makeBundle(from: modelContext)
    bundle.items = bundle.items.map {
      var item = $0
      item.photoFile = nil
      return item
    }
    let data = try BackupCodec.makeEncoder().encode(bundle)
    record["schemaVersion"] = BackupBundle.currentSchemaVersion as NSNumber
    record["updatedAt"] = Date() as NSDate
    record["spaceCount"] = bundle.spaces.count as NSNumber
    record["areaCount"] = bundle.areas.count as NSNumber
    record["itemCount"] = bundle.items.count as NSNumber
    record["recipeCount"] = bundle.recipes.count as NSNumber
    record["dataJSON"] = data as NSData
  }

  private static func importRecord(_ record: CKRecord, into modelContext: ModelContext) throws -> HomeShareImportResult {
    guard let data = data(from: record["dataJSON"]) else {
      throw ShareError.missingSharedPayload
    }
    let bundle = try BackupCodec.makeDecoder().decode(BackupBundle.self, from: data)
    guard bundle.schemaVersion <= BackupBundle.currentSchemaVersion else {
      throw ShareError.unsupportedSchemaVersion(
        found: bundle.schemaVersion,
        supported: BackupBundle.currentSchemaVersion
      )
    }

    let engine = BackupUpsertEngine(modelContext: modelContext)
    let summary = try engine.apply(bundle)
    let updatedAt = record["updatedAt"] as? Date
    return HomeShareImportResult(summary: summary, updatedAt: updatedAt)
  }

  private static func data(from value: CKRecordValue?) -> Data? {
    if let data = value as? Data {
      return data
    }
    if let nsData = value as? NSData {
      return Data(referencing: nsData)
    }
    return nil
  }

  private static func fetchExistingShare(in database: CKDatabase, zoneID: CKRecordZone.ID) async throws -> CKShare? {
    guard let recordName = UserDefaults.standard.string(forKey: shareRecordNameKey) else {
      return nil
    }
    let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
    let records = try await fetchRecords([recordID], in: database)
    guard case let .success(record) = records[recordID] else {
      if case let .failure(error) = records[recordID], !isUnknownItem(error) {
        throw error
      }
      UserDefaults.standard.removeObject(forKey: shareRecordNameKey)
      return nil
    }
    guard let share = record as? CKShare else {
      UserDefaults.standard.removeObject(forKey: shareRecordNameKey)
      return nil
    }
    return share
  }

  private static func configure(_ share: CKShare) {
    share.publicPermission = .none
    share[CKShare.SystemFieldKey.title] = "HomePin Home" as NSString
    share[CKShare.SystemFieldKey.shareType] = "com.sro.homepinapp.home" as NSString
  }

  private static func fetchRecords(
    _ recordIDs: [CKRecord.ID],
    in database: CKDatabase
  ) async throws -> [CKRecord.ID: Result<CKRecord, Error>] {
    try await withCheckedThrowingContinuation { continuation in
      database.fetch(withRecordIDs: recordIDs) { result in
        continuation.resume(with: result)
      }
    }
  }

  private static func saveAcceptedRootRecordID(_ recordID: CKRecord.ID) {
    UserDefaults.standard.set(recordID.recordName, forKey: acceptedRootRecordNameKey)
    UserDefaults.standard.set(recordID.zoneID.zoneName, forKey: acceptedRootZoneNameKey)
    UserDefaults.standard.set(recordID.zoneID.ownerName, forKey: acceptedRootOwnerNameKey)
    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: acceptedAtKey)
  }

  private static func acceptedRootRecordID() -> CKRecord.ID? {
    guard
      let recordName = UserDefaults.standard.string(forKey: acceptedRootRecordNameKey),
      let zoneName = UserDefaults.standard.string(forKey: acceptedRootZoneNameKey),
      let ownerName = UserDefaults.standard.string(forKey: acceptedRootOwnerNameKey)
    else {
      return nil
    }
    let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
    return CKRecord.ID(recordName: recordName, zoneID: zoneID)
  }

  private static func savedRecord(
    _ recordID: CKRecord.ID,
    from saveResults: [CKRecord.ID: Result<CKRecord, Error>]
  ) throws -> CKRecord {
    guard let result = saveResults[recordID] else {
      throw ShareError.savedRecordMissing(recordID)
    }
    switch result {
    case let .success(record):
      return record
    case let .failure(error):
      throw ShareError.savedRecordFailed(recordID, error)
    }
  }

  private static func savedShare(
    _ recordID: CKRecord.ID,
    from saveResults: [CKRecord.ID: Result<CKRecord, Error>]
  ) throws -> CKShare {
    guard let result = saveResults[recordID] else {
      throw ShareError.missingSavedRecord(recordID)
    }
    switch result {
    case let .success(record):
      guard let share = record as? CKShare else {
        throw ShareError.savedRecordTypeMismatch(recordID)
      }
      return share
    case let .failure(error):
      throw ShareError.savedRecordFailed(recordID, error)
    }
  }

  private static func isUnknownItem(_ error: Error) -> Bool {
    guard let cloudKitError = error as? CKError else {
      return false
    }
    return cloudKitError.code == .unknownItem
  }
}
