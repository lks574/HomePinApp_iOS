---
aliases: [App Intents 물건 추가, AddItemIntent, Siri 물건 추가, HomePinShortcuts]
tags: [decision, decision/architecture]
created: 2026-06-22
updated: 2026-06-22
status: accepted
---

# 2026-06-22 App Intents 물건 추가 도입

Siri / App Intents 로 앱을 열지 않고 물건을 추가하는 첫 외부 진입점(screen-24)의
구조·격리·범위를 확정한다. 외부 의존성·계정·entitlement·`Project.swift` 변경 없음.

## 맥락

물건 추가의 마찰을 더 줄이기 위해 화면 밖(Siri·Spotlight·Shortcuts)에서 호출 가능한
진입점이 필요했다. 규칙 기반 파서(`ItemQuickAddParser`)와 SwiftData 직결 쓰기 불변식은
이미 캡처 경로에 있다. App Intents 의 `perform()` 은 앱과 **별도 프로세스**에서 실행될
수 있고, SwiftData `ModelContext` 는 `Sendable` 이 아니다 — 격리 경계 처리가 핵심이다.

## 결정

### A. 무UI 직접 insert + 결과 dialog

인텐트는 앱을 열지 않는다. SwiftData 에 직접 `Item` 하나를 insert 하고
`IntentResult & ProvidesDialog` 로 "Added {name} x{qty} ({위치 or 미정리함})" 사후
확인 dialog 를 돌려준다. 위치가 애매하면 파서가 비워 두므로 area=nil("미정리함")으로
안전 저장한다(합법). `AddItemIntent`(`Features/Intents/`).

### B. 컨테이너 공유 seam + 인텐트 전용 throwing·무부작용 경로

`AppModelContainer` 에서 스키마(`models`)는 단일 소스로 공유하되 진입점별로 경로를 나눈다.

- **`make()`** — 앱 시작 경로. `makeShared()` + (DEBUG) 시드 주입. 동작·회귀 0.
- **`makeShared()`** — UI 있는 시작 흐름 전용. CloudSync 분기 + 로컬 fallback + DEBUG
  파괴 리셋/`fatalError`. CloudKit 실패 시 사용자 토글을 자동 OFF
  (`disableAfterStartupFailure`) 하고 로컬로 fallback 한다(의도된 시작 동작, 그대로 유지).
- **`makeForIntent() throws`** — App Intents 전용. 같은 스키마·같은 CloudSync 토글을
  읽되, 실패를 **`throw` 로 돌려주는 무부작용 경로**다. CloudKit 컨테이너 생성 실패 시
  사용자 영구 설정(`CloudSyncPreference`)을 **건드리지 않고**(자동 OFF 안 함) throw 하고,
  로컬 경로도 실패 시 `fatalError`·DEBUG 파괴 리셋 없이 throw 한다.

인텐트는 `makeForIntent()` 를 `try` 로 호출해 실패 시 `storageUnavailable` dialog 로
graceful 실패한다(인텐트 프로세스 crash 없음). **인텐트 경로는 CloudKit 실패 시 사용자
iCloud Sync 토글을 건드리지 않는다** — UI 없는 Siri 호출이 사용자 동기화 설정을 무음으로
끄지 않게 하기 위함이며, 토글 OFF 판단은 다음 정식 앱 시작(`makeShared()`)에 위임한다.

### C. AppShortcuts free-text

`HomePinShortcuts: AppShortcutsProvider` 에 `AddItemIntent` 등록. 단일 free-text
`@Parameter`(무엇을 추가할지)를 받아 파서에 위임한다. 한국어·영어 발화 phrase 를
`\(.applicationName)` 포함해 등록하고, 파라미터 미제공 시 `requestValueDialog`
follow-up 으로 받는다. v1 은 정적 phrase 라 `updateAppShortcutParameters()` 불필요.

### D. 범위 — 인텐트 1개

"물건 추가" 하나로 한정한다. 검색·조회·다건·레시피·Spotlight·딥링크·AppEntity
picker 는 후속(구현 안 함).

## 격리 (perform() 처리)

`perform()` 을 `@MainActor` 로 표시해 `makeForIntent().mainContext` 접근을 메인 액터
컨텍스트로 정합시킨다. `ModelContext` 가 `Sendable` 이 아니므로 명시적 액터 hop 보다
이 방식이 단순하고 격리 트랩(`@MainActor` 타입 안 시스템 콜백)을 피한다. fetch·parse·
insert·save 가 모두 같은 메인 액터 컨텍스트에서 일어난다.

## 쓰기 불변식 (캡처와 동일)

- `Item(name:)` init 이 `normalizedName` 을 자동으로 채운다(수동 normalize 불필요).
- 위치는 `spot?.area ?? area`(spot 의 area 우선)로 일관시킨다. area=nil 합법.
- 규칙 기반 `ItemQuickAddParser` 재사용(FoundationModels 물건 파서 부활 금지).
  파서·`Item` 모델·`AppRouter` 는 무변경.

## 무변경 목록

- `Project.swift` / Info.plist — `NSSiriUsageDescription` 은 legacy SiriKit 전용,
  순수 App Intents 에 불필요. 소스 glob 이 신규 `.swift` 를 자동 포함한다.
- `AppRouter` — 딥링크·네비게이션 변경 없음(UI 없는 진입점).
- `ItemQuickAddParser`·`Item` 모델 — 그대로 재사용.

## 결과

- iOS(`HomePinApp`)·macOS(`HomePinApp-macOS`) 빌드 green, 동시성 경고 0,
  `'catch' unreachable` 경고 해소(인텐트가 throwing `makeForIntent()` 호출).
- 신규: `AddItemIntent`, `HomePinShortcuts`, `AppModelContainer.makeShared()`·
  `makeForIntent() throws`(인텐트 전용 무부작용 경로).
- 잔여(실기기 검증 follow-up):
  - Siri 발화·follow-up prompt·결과 dialog 자연스러움 검증, 다건/검색/Spotlight 후속 인텐트.
  - 실행 중 Siri 추가 후 앱의 `@Query` 갱신 시점 — 인텐트는 별도 컨테이너에 쓰므로
    실행 중인 앱 컨텍스트에 즉시 반영되지 않을 수 있다. 실기기에서 동일 스토어 변경
    감지/갱신 시점을 확인한다(reviewer finding 3).
  - 파서 로케일(한/영 발화 phrase 처리) 동작 확인.

## 연결

- 모델: [[Item]] (인텐트 쓰기 경로)
- 화면/진입점: [[Capture]] (같은 파서·불변식 공유)
- 결정: [[2026-06-18-area-생략-캡처-허용-및-멀티-추가]] (area=nil 합법 근거),
  [[2026-06-15-NL-추가-파서-FoundationModels]] (규칙 기반 재사용·LLM 파서 부활 금지),
  [[2026-06-12-swiftdata-마이그레이션-방침]] (컨테이너 팩토리 단일 소스)
