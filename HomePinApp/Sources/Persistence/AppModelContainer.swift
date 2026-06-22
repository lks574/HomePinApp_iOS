import Foundation
import SwiftData

/// 앱 전역 SwiftData 컨테이너 팩토리.
///
/// - 스키마(모델 목록)와 설정을 한 곳에서 관리한다 → 마이그레이션 도입 시 이 파일만 수정.
/// - **개발 단계(DEBUG)**: 스키마 불일치 등으로 생성 실패하면 스토어를 지우고 재생성한다(파괴적 리셋).
/// - **릴리스**: 자동 삭제하지 않는다. 1.0 부터 `VersionedSchema` + `SchemaMigrationPlan` 을
///   여기 `migrationPlan:` 으로 연결한다.
///
/// 컨테이너는 **프로세스당 단 하나**(`shared()` 가 캐시)이며 앱과 App Intents 가 같은
/// 인스턴스를 공유한다. 같은 store 파일에 ModelContainer 를 둘 이상 만들면 SwiftData
/// fetch 가 트랩(크래시)하기 때문이다 — 앱 실행 중 Siri 인텐트가 같은 프로세스에서 별도
/// 컨테이너를 만들면 죽던 원인이라, 인텐트도 새로 만들지 않고 `shared()` 를 재사용한다.
///
/// - `shared()`: 프로세스당 단일 공유 컨테이너(앱·App Intents 공용, 최초 1회 `makeShared()`).
/// - `make()`: 앱 시작 경로. `shared()` 위에 (DEBUG) 시드 주입을 더한다.
/// - `makeShared()`: 실제 빌더 — 스키마 + CloudSync 분기(+ 로컬 fallback, DEBUG 파괴 리셋).
///   CloudKit 실패 시 사용자 토글을 자동 OFF(`disableAfterStartupFailure`) 하고 로컬로
///   fallback 한다. 스키마는 단일 소스(`models`)를 공유한다.
///
/// 결정: `docs/wiki/Decision/2026-06-12-swiftdata-마이그레이션-방침.md`,
///       `docs/wiki/Decision/2026-06-22-App-Intents-물건추가-도입.md`
enum AppModelContainer {
  /// 스키마에 등록할 모델. 새 `@Model` 추가 시 여기에 등록한다.
  static let models: [any PersistentModel.Type] = [
    Space.self, Area.self, Spot.self, Item.self, ItemCategory.self, Tag.self,
    Recipe.self, RecipeIngredient.self, ShoppingItem.self,
  ]

  /// 프로세스당 단일 공유 컨테이너 캐시. 앱과 App Intents 가 같은 인스턴스를 쓰게 한다.
  @MainActor private static var cachedContainer: ModelContainer?

  /// 프로세스당 단일 공유 컨테이너. 최초 1회 `makeShared()` 로 만들고 캐시한다. 앱·인텐트
  /// 모두 이걸 쓴다(같은 store 에 컨테이너를 둘 만들면 fetch 가 트랩하므로 반드시 공유).
  @MainActor
  static func shared() -> ModelContainer {
    if let cachedContainer { return cachedContainer }
    let container = makeShared()
    cachedContainer = container
    return container
  }

  /// 앱 시작 경로 — 공유 컨테이너 + (DEBUG) 시드 주입.
  @MainActor
  static func make() -> ModelContainer {
    let container = shared()
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
