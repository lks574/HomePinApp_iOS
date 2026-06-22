import Foundation
import SwiftData

/// 앱 전역 SwiftData 컨테이너 팩토리.
///
/// - 스키마(모델 목록)와 설정을 한 곳에서 관리한다 → 마이그레이션 도입 시 이 파일만 수정.
/// - **개발 단계(DEBUG)**: 스키마 불일치 등으로 생성 실패하면 스토어를 지우고 재생성한다(파괴적 리셋).
/// - **릴리스**: 자동 삭제하지 않는다. 1.0 부터 `VersionedSchema` + `SchemaMigrationPlan` 을
///   여기 `migrationPlan:` 으로 연결한다.
///
/// 컨테이너 구성은 세 경로로 나뉜다.
/// - `make()`: 앱 시작 경로. `makeShared()` 위에 (DEBUG) 시드 주입을 더한다.
/// - `makeShared()`: 스키마 + CloudSync 분기 컨테이너(시드·DEBUG 리셋 포함, 시드 주입 없음).
///   CloudKit 실패 시 사용자 토글을 자동 OFF(`disableAfterStartupFailure`) 하고 로컬로
///   fallback 하는 **UI 있는 시작 흐름 전용** 경로다.
/// - `makeForIntent()`: App Intents 등 **앱 외부 진입점** 전용. 실패를 `throw` 로 돌려주는
///   무부작용 경로 — CloudKit 실패 시 사용자 영구 설정(`CloudSyncPreference`)을 건드리지
///   않고 그냥 throw 한다(인텐트는 graceful dialog 로 안내, 토글은 다음 정식 앱 시작이 판단).
///   스키마는 단일 소스(`models`)를 공유한다.
///
/// 결정: `docs/wiki/Decision/2026-06-12-swiftdata-마이그레이션-방침.md`,
///       `docs/wiki/Decision/2026-06-22-App-Intents-물건추가-도입.md`
enum AppModelContainer {
  /// 스키마에 등록할 모델. 새 `@Model` 추가 시 여기에 등록한다.
  static let models: [any PersistentModel.Type] = [
    Space.self, Area.self, Spot.self, Item.self, ItemCategory.self, Tag.self,
    Recipe.self, RecipeIngredient.self, ShoppingItem.self,
  ]

  /// 앱 시작 경로 — 공유 컨테이너 + (DEBUG) 시드 주입.
  @MainActor
  static func make() -> ModelContainer {
    let container = makeShared()
    populateSeedIfNeeded(container)
    return container
  }

  /// 공유 컨테이너 구성 — 스키마 + CloudSync 분기(+ 로컬 fallback, DEBUG 파괴 리셋).
  /// 시드를 주입하지 않으므로 앱 외부 진입점(App Intents)이 동일 스토어를 그대로 재사용한다.
  /// 앱 시작 경로(`make()`)와 같은 CloudSync 설정을 쓰되, 시드·시작 부수효과만 분리한다.
  @MainActor
  static func makeShared() -> ModelContainer {
    let schema = Schema(models)
    let isCloudSyncEnabled = UserDefaults.standard.bool(forKey: CloudSyncPreference.storageKey)
    if isCloudSyncEnabled {
      do {
        let container = try makeContainer(
          schema: schema,
          cloudKitDatabase: .private(CloudSyncPreference.containerIdentifier)
        )
        CloudSyncPreference.clearFallbackReason()
        return container
      } catch {
        CloudSyncPreference.disableAfterStartupFailure(error)
      }
    }

    return makeLocalContainer(schema: schema)
  }

  /// App Intents 전용 — 실패를 `throw` 로 돌려주는 무부작용 컨테이너 경로.
  ///
  /// `makeShared()` 와 같은 스키마·CloudSync 토글을 읽지만, 실패 시 사용자 영구 설정을
  /// 바꾸거나(`disableAfterStartupFailure`) `fatalError` 로 프로세스를 죽이지 않는다.
  /// - CloudSync ON 인데 CloudKit 컨테이너 생성 실패 → 토글 무변경, throw(인텐트가 dialog 로 안내).
  /// - CloudSync OFF → 로컬 컨테이너 생성, 실패 시 throw(DEBUG 파괴 리셋 없음).
  @MainActor
  static func makeForIntent() throws -> ModelContainer {
    let schema = Schema(models)
    let isCloudSyncEnabled = UserDefaults.standard.bool(forKey: CloudSyncPreference.storageKey)
    if isCloudSyncEnabled {
      return try makeContainer(
        schema: schema,
        cloudKitDatabase: .private(CloudSyncPreference.containerIdentifier)
      )
    }
    return try makeContainer(schema: schema, cloudKitDatabase: .none)
  }

  private static func makeContainer(
    schema: Schema,
    cloudKitDatabase: ModelConfiguration.CloudKitDatabase
  ) throws -> ModelContainer {
    let configuration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: cloudKitDatabase
    )
    return try ModelContainer(for: schema, configurations: configuration)
  }

  private static func makeLocalContainer(schema: Schema) -> ModelContainer {
    let configuration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: false,
      cloudKitDatabase: .none
    )
    do {
      return try makeContainer(schema: schema, cloudKitDatabase: .none)
    } catch {
      #if DEBUG
      // 개발 단계 파괴적 리셋: 스토어를 지우고 한 번 더 시도한다.
      eraseStore(at: configuration.url)
      do {
        return try ModelContainer(for: schema, configurations: configuration)
      } catch {
        fatalError("ModelContainer 재생성 실패: \(error)")
      }
      #else
      fatalError("ModelContainer 생성 실패: \(error)")
      #endif
    }
  }

  @MainActor
  private static func populateSeedIfNeeded(_ container: ModelContainer) {
    #if DEBUG
    // 개발 중 빈 스토어면 시드 주입.
    SeedData.populateIfEmpty(container.mainContext)
    #endif
  }

  #if DEBUG
  private static func eraseStore(at url: URL) {
    let fileManager = FileManager.default
    // SQLite 본체와 동행 파일(-wal, -shm) 을 함께 제거한다.
    for suffix in ["", "-wal", "-shm"] {
      try? fileManager.removeItem(atPath: url.path + suffix)
    }
  }
  #endif
}
