---
aliases: [architecture, 아키텍처]
tags: [doc/code, architecture]
created: 2026-06-12
updated: 2026-06-12
status: draft
---

# 아키텍처

## 기반 스택 (확정)

| 항목 | 결정 |
| --- | --- |
| UI | SwiftUI |
| 대상 | iOS 기기, 최소 **iOS 26.5** |
| 언어 | **Swift 6.2** (Swift 6 언어 모드, strict concurrency) |
| 영속화 | **SwiftData** (`@Model`, `ModelContainer`, `@Query`) — 서버 없이 기기 내부 저장 |
| 프로젝트 구성 | **Tuist** (`Project.swift` manifest, mise 로 설치) |

- iOS 26.5 / Swift 6.2 최소 사양이라 최신 SwiftUI · Observation(`@Observable`) ·
  SwiftData API 를 제약 없이 사용한다. 하위 호환 우회 코드는 두지 않는다.
- 동시성은 Swift 6 strict concurrency 를 기준으로 한다 — `Sendable`, actor 격리,
  `async`/`await`. 경고를 억지로 끄거나 우회하지 않는다.

### SwiftData 매크로 적극 사용

- 모델 선언: `@Model`
- 프로퍼티/관계 커스터마이즈: `@Attribute`(`.unique`/`.externalStorage`/
  `.preserveValueOnDeletion`/`originalName:` 등), `@Relationship`(`deleteRule`/
  `inverse`), `@Transient`
- 쿼리/제약/인덱스: `#Predicate`, `#Index`, `#Unique`, `#Expression`
- 읽기·주입(매크로 아님, SwiftUI 프로퍼티 래퍼): `@Query`, `@Environment(\.modelContext)`
- 수동 보일러플레이트(문자열 fetch, 수기 인덱스/유니크 관리)보다 매크로 선언을
  기본값으로 한다.

## 상태 관리 (확정)

**기본은 `View ↔ SwiftData` 직결.** 서버가 없어 저장소가 단일 진실 소스다.

- **읽기**: View 가 `@Query` 로 `@Model` 직접 관찰.
- **쓰기**: View 가 `@Environment(\.modelContext)` 로 직접 insert/delete 하거나
  `@Model` 프로퍼티 변경(autosave).
- 단순 목록·상세·간단 편집은 별도 모델/계층 없이 직결로 처리한다.

**얇은 `@Observable` 모델은 아래 두 경우에만** 해당 화면에 둔다(기본값은 안 둠).

1. 비영속 UI 상태 — draft, 다단계 폼/wizard, 선택/검색어 등 SwiftData 에 넣지 않는
   화면 로컬 상태.
2. 다단계 쓰기 규칙(불변식) — 여러 `@Model` 에 걸친 트랜잭션·파생 쓰기. 단순
   cascade 는 `@Relationship(deleteRule:)` 로 처리하고 모델을 만들지 않는다.

> [!note] 이 결정은 구 프로젝트(HomePin_iOS)의 "모든 쓰기 service 경유 / D2 supersede
> 가드(@Observable 가 @Model 보유 금지)" 규칙을 **대체**한다. 로컬 SwiftData 직결이라
> 영속화 전용 service 계층은 두지 않는다.

### 데이터 모델 / 마이그레이션

- 위치·물건 데이터 모델(Space/Area/Spot/Item/Category/Tag)은 위키 결정 노트
  `docs/wiki/Decision/2026-06-12-위치-물건-데이터모델.md` 참고.
- 마이그레이션 방침은 `docs/wiki/Decision/2026-06-12-swiftdata-마이그레이션-방침.md`:
  **개발 단계는 파괴적 리셋**(`VersionedSchema` 없이, `DEBUG` 에서 스키마 불일치 시
  스토어 자동 삭제·재생성), **첫 릴리스 때 `SchemaV1` 동결 + `SchemaMigrationPlan`
  도입**. `ModelContainer` 생성은 단일 팩토리(`AppModelContainer`)에 모은다. 변경은
  가산적 우선, 이름 변경은 `@Attribute(originalName:)`.

### 테스트 정책

테스트는 개발 초기에 작성하지 않고 후반 테스트 단계에서 작성한다. 상세는 `CLAUDE.md`
"테스트 정책" 을 단일 기준으로 한다.

## 프로젝트 구성 / 폴더 (초기 확정)

Tuist 단일 앱 타깃(`Project.swift`). 번들 ID `com.sro.homepinappios`. 소스는
`HomePinApp/Sources/` 아래.

```text
Project.swift            # Tuist manifest (단일 소스; .xcodeproj/.xcworkspace 는 생성물, git 무시)
mise.toml                # tuist 4.192.3 핀
HomePinApp/
  Sources/App/           # @main App, AppModel(앱 단계), AppRootView(셸)
  Sources/Models/        # SwiftData @Model 6종
  Sources/Persistence/   # AppModelContainer (스키마·DEBUG 리셋)
  Sources/Features/      # 화면당 폴더 (Splash, Home, …) — feature-first
  Sources/Shared/        # (생기면) 공용 컴포넌트/확장
  Resources/             # Assets.xcassets
```

- 생성: `tuist generate`. 빌드: `xcodebuild -workspace HomePinApp.xcworkspace -scheme HomePinApp ...`.
- 테스트 타깃은 후반 테스트 단계에서 추가한다(`CLAUDE.md` "테스트 정책").

## 네비게이션 (확정)

상세: `docs/wiki/Decision/2026-06-12-네비게이션-UI구조.md`.

- **루트 단계 전환**: `AppModel.Phase`(`splash` → `home`)을 `AppRootView` 가 스위치.
  스플래시는 분기지점(`AppModel.start()`).
- **탭바 5-슬롯**: 홈 / 장소 / [중앙 🎤 NL 추가] / 레시피 / 설정. 중앙은 목적지가
  아니라 입력 시트(modal).
- **화면 내부 push 는 각 탭의 `NavigationStack`** (장소→장소상세→물건상세 등). typed
  `Route`/Router 전역화는 도입하지 않음(탭별 스택으로 충분).
- **위치 2레벨 UI ↔ 3레벨 모델**: `Space` 숨김(단일 기본), UI "장소"=`Area`,
  "수납공간"=`Spot`.

## 미확정 (정해지면 작성)

> [!note] 작성 예정

- 의존성 / side-effect — 알림·파일 등 비영속 외부 작업의 service 경계
  (영속화는 SwiftData 직결이라 별도 service 불필요)
- 금지 패턴 — 도입하지 않을 안티패턴
