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

인텐트는 앱을 열지 않는다. SwiftData 에 직접 `Item` 을 insert 하고
`IntentResult & ProvidesDialog` 로 사후 확인 dialog 를 돌려준다. 위치가 애매하면 파서가
비워 두므로 area=nil("미정리함")으로 안전 저장한다(합법). `AddItemIntent`(`Features/Intents/`).

**다건 추가(2026-06-22 추가)**: 입력을 단건 `parse` 대신 **`parse(multiline:)`**(쉼표·줄바꿈
분절, 공백은 분절 안 함 → 다어절 이름 보존)으로 처리해 "우유, 계란, 빵" 을 한 번에 N건
처리한다(분절 없으면 1건 — 단건/다건 통합). 각 건은 단건과 동일한 규칙·불변식
(이름·수량·위치, `spot?.area ?? area`, `normalizedName` 자동)을 쓴다. dialog 는 1건이면
"{name} {qty}개 추가됨 ({위치})", N건이면 "{N}개 추가됨: a, b, c". **음성 한계**: Siri
받아쓰기가 쉼표를 항상 넣어주지는 않아, 음성으로 한 문장 다건은 best-effort(타이핑/일시정지
시 분절)이고 안정적 분절은 follow-up 검증 대상.

**기존 재고 자동 병합(2026-06-22 추가)**: 같은 `normalizedName` 기존 Item 이 있으면 새로
만들지 않고 **수량을 가산**한다(예: 기존 우유 2 + "우유" → 우유 3). 같은 키가 여럿이면
최근 수정(`updatedAt`) 대표 하나에만 가산하고, 위치(area/spot)는 기존 Item 을 유지한다
(칩 area 로 안 덮음). 같은 문장 내 동일 이름 중복도 한 대표에 누적된다. `ItemBulkAddModel.
bulkInsert` 의 합치기 규칙과 동일하되, 캡처 시트는 **사용자 토글**(차단 없는 경고 후 선택),
Siri 는 **UI 가 없어 자동 병합**으로 차이를 둔다. dialog 의 수량은 병합 후 최종 재고를
보여준다(가산분이 아니라 합계). 한계: 병합은 **이름 기준**이라, 같은 이름이 여러 위치에
있으면 의도한 위치가 아닌 최근 수정 대표에 가산될 수 있다(위치 인지 병합은 후속).

### B. 프로세스당 단일 공유 컨테이너 (앱 + App Intents 공용)

`AppModelContainer` 에서 스키마(`models`)는 단일 소스로 공유하고, **컨테이너는 프로세스당
단 하나**만 만들어 앱과 App Intents 가 같은 인스턴스를 쓴다.

- **`shared()`** — 프로세스당 단일 공유 컨테이너. 최초 1회 `makeShared()` 로 만들고 캐시한다.
  앱·인텐트 모두 이걸 쓴다.
- **`make()`** — 앱 시작 경로. `shared()` + (DEBUG) 시드 주입. 동작·회귀 0.
- **`makeShared()`** — 실제 빌더. CloudSync 분기 + 로컬 fallback + DEBUG 파괴 리셋/
  `fatalError`. CloudKit 실패 시 토글 자동 OFF(`disableAfterStartupFailure`) 후 로컬 fallback.

인텐트(`AddItemIntent.perform()`)는 `AppModelContainer.shared().mainContext` 를 쓴다.
`perform()` 을 `@MainActor` 로 두어 `mainContext`(메인 액터 컨텍스트) 접근을 정합시킨다.

  > **수정(2026-06-22)**: 최초 구현은 인텐트가 **자체 컨테이너**(`makeForIntent()`)를 따로
  > 만들었는데, 앱 실행 중 Siri 가 인텐트를 **같은 프로세스**에서 돌리면 같은 store 파일에
  > `ModelContainer` 가 둘 생겨 첫 `fetch(FetchDescriptor<Area>())` 에서 **트랩(EXC_BREAKPOINT)
  > 크래시**했다. Apple 권장대로 **프로세스당 단일 공유 컨테이너**(`shared()`)를 앱·인텐트가
  > 함께 쓰도록 바꿔 해소했다. 별도 throwing 경로(`makeForIntent()`)와 그에 딸린
  > `storageUnavailable` 에러 케이스는 제거. (앞선 1차 시도였던 "인텐트 전용 CloudKit→로컬
  > fallback throwing 경로" 도 이 단일 컨테이너 방식으로 대체됐다.)

> **잔여(알려진 tradeoff)**: 인텐트가 앱이 안 떠 있는 **별도 프로세스**에서 처음 `shared()`
> 를 만들 때, CloudSync 토글 ON + CloudKit 실패면 `makeShared()` 의 `disableAfterStartupFailure`
> 로 토글이 무음 OFF 될 수 있다(이전 "토글 무변경" 원칙의 부분 후퇴). 다만 앱이 보통 먼저
> 떠 컨테이너를 캐시하므로 실제 발생 여지는 작다. 실기기 검증 항목.

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
