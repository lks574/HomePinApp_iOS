import Foundation
import SwiftData

/// 앱 전역 SwiftData 컨테이너 팩토리.
///
/// - 스키마(모델 목록)와 설정을 한 곳에서 관리한다 → 마이그레이션 도입 시 이 파일만 수정.
/// - **개발 단계(DEBUG)**: 스키마 불일치 등으로 생성 실패하면 스토어를 지우고 재생성한다(파괴적 리셋).
/// - **릴리스**: 자동 삭제하지 않는다. 1.0 부터 `VersionedSchema` + `SchemaMigrationPlan` 을
///   여기 `migrationPlan:` 으로 연결한다.
///
/// 결정: `docs/wiki/Decision/2026-06-12-swiftdata-마이그레이션-방침.md`
enum AppModelContainer {
  /// 스키마에 등록할 모델. 새 `@Model` 추가 시 여기에 등록한다.
  static let models: [any PersistentModel.Type] = [
    Space.self, Area.self, Spot.self, Item.self, ItemCategory.self, Tag.self,
    Recipe.self, RecipeIngredient.self,
  ]

  static func make() -> ModelContainer {
    let schema = Schema(models)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
      return try ModelContainer(for: schema, configurations: configuration)
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
