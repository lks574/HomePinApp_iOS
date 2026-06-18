---
aliases: [next-task, 다음 할 일]
tags: [doc/code, tasks]
created: 2026-06-12
updated: 2026-06-18
status: draft
---

# 다음 할 일

UI 우선 1차(시안 C 화면 골격: 5탭·장소·레시피·홈·추가 시트) 완료 후의 다음 후보.
보류 상세는 `docs/follow-ups.md`.

> 최근 완료: **AdMob 광고 수익화 P1(SDK + 동의/ATT 골격, 광고 미표시)** — 첫 외부
> 의존성. `Project.swift` 에 Google Mobile Ads SDK(SPM `13.5.0` `.exact`) + UMP
> (`GoogleUserMessagingPlatform` `3.1.0` `.exact`) 추가, **iOS 타깃에만 링크**(macOS
> `dependencies: []` 유지 → macOS 빌드 green, SDK 미링크). iOS Info.plist 에
> `GADApplicationIdentifier`(Google 테스트 앱 ID)·`SKAdNetworkItems`(50개)·
> `NSUserTrackingUsageDescription`(en/ko 현지화) 추가. 앱 레벨 `PrivacyInfo.xcprivacy`
> iOS 전용 리소스(`Resources-iOS/`, 공유 glob 밖)로 추가. `AdService`
> (`@MainActor @Observable`, `Features/Monetization/`) — iOS 실구현/macOS no-op,
> SDK 타입은 `#if canImport(GoogleMobileAds)` 안에만. 시작 플로우
> `AppModel.start(adService:)` → `AdService.startup()`: ① UMP 동의 → ② ATT →
> ③ `MobileAds.shared.start()` → `.home`(거부해도 비개인화로 진행, 차단 없음, 스플래시
> 최소노출과 병렬). `AppRootView` 가 `AdService` 소유·`.environment` 주입. UMP 완료
> 핸들러 nonisolated 콜백은 `nonisolated static` 헬퍼+`withCheckedContinuation` 으로
> 받아 메인 액터 hop(격리 트랩 회피). iOS·macOS 빌드 둘 다 green, 동시성 경고 0.
> **P2 전면 광고 완료**: 장보기 세션 완료(`shoppingSessionCompleted`) 트리거에서만
> best-effort 표시, 하루 1회+최소 간격 빈도 캡(`UserDefaults`), 사전 로드·닫힘 후
> 재로드, rootVC present, 닫힘 delegate 는 `Task { @MainActor in }` hop. **P3 보상형
> 완료**: opt-in 전용(Settings "개발자 응원하기" 버튼 직접 탭 시에만, 강제 노출 0).
> 테스트 보상형 단위 ID(`.../1712485313`), `presentRewarded()` 사전 로드→present,
> `userDidEarnRewardHandler` 수신 시에만 누적 응원 카운터(`UserDefaults`
> `ad.developerSupportCount`) +1. **보상거리 = 상징적 "개발자 응원"으로 어떤 기능도
> 잠그지 않음**(R10). 보상 플래그는 `@MainActor` 참조 박스로 present 핸들러·닫힘
> delegate 가 공유(mutable var 캡처 회피), 시청 중단·취소·실패 시 미적용(R9). Settings
> 진입점은 `#if os(iOS)` 로 macOS 비노출(AdService no-op). 결정:
> `docs/wiki/Decision/2026-06-17-AdMob-광고-수익화-도입.md`. 잔여: 출시 전 실광고
> 앱/단위 ID 교체, ATT/동의·전면·보상형 실기 런타임 검증.
> 이전 완료: **macOS 플랫폼 지원 횡단(screen-17)** — 네이티브 macOS 앱 타깃 추가
> (화면 추가 아님, 플랫폼 확장). `Project.swift` 에 `HomePinApp-macOS`(`.macOS("26.0")`,
> bundleId `com.sro.homepinappmac`, entitlements app-sandbox·files.user-selected.read-write·
> device.audio-input) 추가, **소스·리소스 한 벌 공유** + `#if os` 흡수(Mac Catalyst·
> Designed-for-iPad 아닌 네이티브). 플랫폼 nav/입력 modifier 헬퍼 macOS no-op +
> 동적 색 provider UIColor/NSColor 분기. STT·FoundationModels 는 공통이고,
> macOS 는 `AVAudioSession` 분기만 skip.
> 셸·네비게이션 재설계 없이 동작. **스킴 분리**(`targetSchemesGrouping: .notGrouped`) →
> `HomePinApp`(iOS)/`HomePinApp-macOS`(macOS) 각각 노출(한 스킴 묶음은 macOS 빌드 시 iOS
> 타깃 서명 오류라 분리). iOS·macOS 빌드 둘 다 green. 동작 로직 변경 없음(iOS 회귀 0).
> 결정: `docs/wiki/Decision/2026-06-17-macOS-네이티브-타깃-추가.md`. 잔여(다음 할 일):
> macOS 실기 런타임 검증(AC-005~006).
> 이전: **검색·추가 정교화 횡단(screen-16)** — 중앙 검색([[Capture]],
> `CaptureSheet`)·물건 추가 경로의 횡단 정교화(새 화면 아님, `Shared/Search/`).
> (1) 자연어 규칙 외부화 — 조사·불용어·의미단어 3개를 `Resources/SearchRules.json` +
> `SearchRules.swift`(번들 1회 로드, 누락 시 `preconditionFailure`)로 분리(토큰화/`Item.normalize`
> 순서 동일, 회귀 0). (2) 랭킹 정렬 — `SearchRanking`·`MatchTier`(exact/prefix/contains/
> choseong/fuzzy)·`SearchRank`, 매칭 함수 Bool→`SearchRank?` → `compactMap`+`sorted`(등급→
> 상태가중치(임박↑·위치없음↓ / 지금가능·임박재료↑)→이름순). (3) 초성 검색 — `Hangul`(완성형
> 음절→초성, 유니코드 산술), 질의 전부 초성일 때만 활성(`.choseong`, 회귀 0). (4) 편집거리
> fallback — `Levenshtein`(음절 단위 2행 DP), 결과 0 + `hasConcreteSignal` 일 때만 토큰별
> 임계(≤3→1/그외 2) 근사 매칭(`.fuzzy`). (5) 추천 칩 — 빈 입력 시 최근 검색어
> (`@AppStorage("recentSearches")` JSON, `RecentSearches`)+임박 물건, 칩 탭=입력 채우기만. (6)
> 중복 가드 — 같은 `normalizedName` 추가 시 합치기/새로 추가 `confirmationDialog` 제안(자동
> 저장 없음, 합치기→`ItemEditor` edit). (7) 직전 위치 prefill — `@AppStorage` lastArea/SpotID,
> 저장 시 기록·create 진입 시 미지정이면 fetch prefill(삭제된 위치 nil→무시). 모든 경로가
> `hasConcreteSignal` 가드·`normalizedName` 단일 매칭키·위치 불변식 우회 없음. 새 `@Model`·
> 외부 의존성 없음. 결정: `docs/wiki/Decision/2026-06-17-자연어-규칙-외부화.md`,
> `docs/wiki/Decision/2026-06-17-검색-랭킹-초성-편집거리.md`. 잔여: 편집거리 자모 정밀화·
> 의미플래그 후보 외부화(`docs/follow-ups.md`).
> 이전: **데이터 백업/가져오기 + CSV 대량 입력(screen-15)** — `Settings > Data >
> Backup & Import`(`DataTransferView`) 진입. **전체 백업** = 디렉터리 패키지
> (`.homepinbackup`, exported UTType `com.sro.homepinappios.backup`/`com.apple.package`) —
> `data.json`(schemaVersion 메타 + 9 엔티티 Codable DTO, 관계 전부 UUID 참조,
> `RecipeStep` 인라인). 외부 의존성 없이 `FileManager`
> 만(ZIP 불채택, `dependencies: []` 유지). export = 전체 fetch→DTO→`fileExporter`,
> import = `fileImporter`→디코드→schemaVersion 가드→**2-pass upsert**(`BackupUpsertEngine`:
> pass-1 id fetch→갱신/insert, pass-2 UUID 참조 관계 재연결), 엔티티 단위 스킵+요약.
> import 정책 = id(UUID) upsert/덮어쓰기. **CSV 대량 입력** = Item·Recipe, 3파일
> (`items.csv`·`recipes.csv`·`recipe_ingredients.csv`, 재료는 `recipeTitle` 연결), RFC4180
> 최소 자체 파서/직렬화(`CSV`)+템플릿 export. upsert 키 = id 있으면 id, 없으면
> `normalizedName`(Item)/`title`(Recipe), area/spot/category/tags 는 이름 조회→없으면 생성,
> 행 단위 스킵+요약. 엔진 강제: `normalizedName` 동반 갱신·불변식 `spot→area`·`stockCredited`
> 보존. 얇은 `@Observable DataTransferModel`(비영속 UI 상태+다단계 쓰기 오케스트레이션).
> `SettingsView.clearAllData()` 의 `ShoppingItem` 삭제 누락 수정(export 9종 일치). `@Model`
> 스키마 변경 없음. 결정: `docs/wiki/Decision/2026-06-17-데이터-백업-번들포맷.md`,
> `docs/wiki/Decision/2026-06-17-CSV-대량입력-스키마.md`. 잔여: `VersionedSchema`
> 연동(`docs/follow-ups.md`).
> 이전: **레시피 부재료(optional) 횡단(screen-14)** — 주재료와 별도로
> **부재료**(곁들임·취향껏·선택적)를 입력·표시. `RecipeIngredient.isOptional: Bool = false`
> 가산 필드(마이그레이션 불필요). `Recipe` 의 `missingIngredients`·`isReadyToCook`·
> `inStockCount`·신규 `mainIngredients`/`mainIngredientCount`·`usesExpiringIngredient` 가
> **주재료(`!isOptional`)만** 집계 → "지금 가능" 판정·부족분→장보기에서 부재료 제외(부재료도
> `item` grounding·재고 보유 표시는 동일). `RecipeEditorView` 재료 입력을 주재료/부재료
> 섹션으로 분리(부재료는 비어도 됨), `RecipeEditorModel` 은 `mainIngredients`/
> `optionalIngredients` 두 draft 배열·섹션별 add/remove·연속 sortOrder. `RecipeDetailView`
> 주/부 섹션 구분·요약 분모 주재료 기준. AI 파서 `ParsedIngredient.isOptional`+instructions
> 주/부 안내·확인 화면 교정 친화. 신규 UI 문자열 en/ko. `@Model` 스키마는
> 가산 필드만(기존 데이터/시드 주재료로 자연 동작). 이어서 `RecipeDetail` 재고 요약에서
> 부족 주재료만 장보기에 추가하는 흐름을 완료했다(`ShoppingItem.sourceIngredient` 연동,
> 중복 방지, 완료된 원본 항목 미완료 복구). 이어서 장보기 완료 체크 시 기존 `Item`
> 수량 증가 또는 `ItemEditor` 신규 재고 생성까지 연결했다(`sourceIngredient` 재연결 포함,
> 체크 해제 시 재고 자동 차감 없음). 결정:
> `docs/wiki/Decision/2026-06-16-레시피-NL파서-ParsedRecipe.md`(ParsedIngredient 갱신). 잔여:
> 실기기 AI 주/부 추출 품질.
> 이전: **레시피 자연어 추가 단계 1(screen-12)** — 중앙 ✨ 시트(`CaptureSheet`)에
> 명시적 "Add a recipe" 행 추가(검색-우선 통합 UX 유지, 의도 자동추측 없음) →
> 레시피 전용 입력 화면 `RecipeCaptureView`(여러 줄 텍스트·붙여넣기·음성, 단일 경로).
> "Sort with AI" → 온디바이스 Foundation Models `@Generable ParsedRecipe`
> (`NLRecipeParser` 비-MainActor 추출 / `NLRecipeParseViewModel` 가용성 게이트·단일 Task /
> `RecipeDraftResolver` 분류 raw 정규화·draft 변환) → 확인은 기존 `RecipeEditorView` 를
> `RecipeEditorModel(prefill:)` 로 재사용(AI prefill 배너·빈 행 추가로 교정 친화). 저장은
> 수동 create 와 동일(재료 이름→보유 `Item` 정규화 매칭). 미가용·실패·취소·빈 결과면 수동
> 에디터 폴백. `@Model` 스키마 변경 없음. 결정:
> `docs/wiki/Decision/2026-06-16-레시피-NL파서-ParsedRecipe.md`. 잔여: 실기기 한국어 추출 품질.
> 이전: **캡처 시트 검색-우선 통합(screen-04)** — [추가|검색] 모드 토글 제거,
> 단일 입력 필드 하나로 통합. 입력 즉시 실시간 검색(물건+레시피 섹션), 결과 아래 항상
> `+ "{입력어}" 추가하기` 행으로 **명시적 추가만**(AI 가 추가/검색 의도 자동추측 안 함 →
> 오분류 데이터 오염 방지). 음성은 단일 입력 필드를 채우고 같은 `add()` 에디터 경로로 합류.
> `CaptureMode`·`modePicker`·이중 입력(`text`/`searchText`) dead code 제거. find/add 의도
> 자동판별 후속은 본 통합으로 대체·불필요 처리.
> 이전: **중앙 AI 버튼 + 레시피 검색 + 장보기(screen-04/09/11)** — 중앙 버튼
> 아이콘 `mic.fill`→`sparkles`(AI 추가/검색, 기존 `CaptureSheet` 유지). AI 검색 시트
> 확장: 물건 + 레시피(제목·재료명) 부분 일치 → 물건/레시피 섹션 구분, 레시피 결과 탭 시
> 시트 닫고 레시피 탭 상세 push(`AppRouter.openRecipe`·`recipesPath` 바인딩,
> `placesPath` 동형). 신규 `ShoppingItem` @Model + 홈 장보기 요약 섹션(미완료 N개 +
> 상위 3개 → push) + `ShoppingListView` CRUD(추가·체크·삭제, View↔SwiftData 직결).
> 결정: `docs/wiki/Decision/2026-06-16-장보기-데이터모델.md`, 네비 ADR §1·§3·§5 갱신.
> 1차 컷(후속): 자연어 검색·find/add 의도판별·레시피 NL 추가.
> 이전: **설정 언어 선택(screen-08/10)** — 시스템 추종 기본 + 설정 > 표시 > 언어에서
> 시스템/English/한국어 수동 오버라이드. `AppLanguagePreference`(`@AppStorage`, 테마
> 선례) + 루트 `AppRootView` `.environment(\.locale)` 즉시 전환. ADR·screen tasks·Settings 노트 갱신.
> 이전: **다국어(i18n, screen-10)** — 영어/한국어 + 시스템 언어 추종(기본 en).
> UI 텍스트 String Catalog, 권한 문구 InfoPlist 카탈로그, cuisine/dishType 저장값 유지·
> 표시만 매핑, 시드 언어 분기(`SeedText`). 잔여는 `docs/follow-ups.md` "다국어(i18n) 후속"
> (STT 인식 locale 시스템 추종, 영어 NL 추출 품질). 결정:
> `docs/wiki/Decision/2026-06-16-i18n-다국어화-방침.md`.

## 다음 후보 (우선순위순 제안)

0. **CloudKit 동기화 + 가족공유 착수** — `feat/icloud-sync` 브랜치에서 시작. 목표는
   Settings 에서 iCloud 동기화를 켜고, 이후 CloudKit 공유 초대로 가족에게 데이터를 공유할 수
   있게 하는 것. 단, 현재 모델/프로젝트 상태상 버튼부터 추가하지 않고 아래 순서로 진행한다.
   - **Phase 0 스키마 호환화**: 전 `@Model` 의 `id` `.unique` 제거, `#Index<Item>`
     재검토, 비옵셔널 속성 기본값/optional 감사, 관계 optional+inverse 보장 점검,
     물건 사진 저장은 제거했으므로 CloudKit 동기화 대상에서 제외.
   - **Phase A Private 동기화**: iCloud container 확정 후 iOS/macOS entitlements 확장,
     `AppModelContainer` 를 CloudKit private DB 구성으로 전환, Settings 에 sync 상태/안내
     진입점 추가. 골격 구현 완료: container ID `iCloud.com.sro.homepinapp`, Settings
     `iCloud Sync` 토글, iCloud 계정 상태 확인, 토글 전 계정 가용성 확인, startup
     CloudKit 실패 시 로컬 store fallback + Settings 사유 표시, iOS/macOS entitlements.
     **단, App ID 에 iCloud capability·컨테이너 미등록이라 실기기 서명이 실패해
     entitlements 의 CloudKit 키는 2026-06-18 임시 제거(주석)** — 계정 등록 후 복구 필요.
     잔여는 Apple Developer 포털 container 생성/확인 + entitlement 복구 + 실기기/실계정
     검증(`docs/follow-ups.md` "iCloud 동기화 / CloudKit").
   - **Phase B 가족공유**: 1차 초대 골격과 2차 가져오기 골격 구현 완료. Settings `Share Home Data` 가 iOS
     `UICloudSharingController` 를 띄우고, custom zone root record 에 현재 데이터를
     `BackupBundle` JSON 스냅샷으로 저장해 `CKShare` 한다. 초대 수락 후
     `Import Shared Home Data` 는 `sharedCloudDatabase` 의 root snapshot 을 로컬 SwiftData 로
     upsert 한다. Apple 가족 그룹 자동 연동이 아니라 초대 기반 공유로 다룬다. 잔여는
     참가자 push, 충돌 처리, 실기기/실계정 초대·가져오기 검증.
   - 전제: 유료 Apple Developer Program 및 사용할 iCloud container ID 확정.
   - 검토 문서: `docs/wiki/Research/CloudKit-동기화-가족공유-도입검토.md`.
1. **macOS 실기 런타임 검증(screen-17 후속)** — iOS·macOS 빌드는 green 이나 macOS 는
   실기 런타임 검증이 남았다(시뮬레이터/CI 빌드만으로는 못 보는 권한·파일·디바이스 경로).
   - **AC-005 파일 Import/Export** — [[DataTransfer]] 백업 `.homepinbackup` 패키지
     export/import 가 sandbox(`files.user-selected.read-write`)에서 정상 동작하는지.
   - **AC-006 STT 권한/받아쓰기** — 마이크(`device.audio-input`)·음성인식 권한 시트와
     온디바이스 받아쓰기가 macOS 에서 정상인지(`AVAudioSession` 없이).
   - macOS 데스크톱 UX 최적화(메뉴/창/사이드바)는 별도
     후속. 결정: [[2026-06-17-macOS-네이티브-타깃-추가]].
2. **물건 추가 흐름 통일** — 중앙 검색 시트의 `+ "{입력어}" 추가하기`와 장보기 미등록
   항목 체크 후 재고 생성이 같은 `ItemEditor` `create(initialName:)` 화면을 사용한다.
   입력어는 규칙 기반 `ItemQuickAddParser` 로 이름·수량·위치를 prefill 한다. 과거 물건
   AI 드래프트 경로(screen-09: `NLItemParser`/`CaptureDraftReviewView`/`AddDraftResolver`)는
   dead island 가 되어 2026-06-18 제거했다.
3. **검색 동작** — 중앙 버튼 시트 **검색-우선 통합** 완료(`screen-04`): [추가|검색]
   모드 토글 제거, 단일 입력 필드 하나(타이핑·음성 공용). 입력 즉시 물건
   (이름·위치·분류·태그·메모 부분 일치) + 레시피(제목·요약·분류·태그·재료 세부 텍스트
   부분 일치) 실시간 검색 → 물건/레시피 섹션, 결과 아래 항상 `+ "{입력어}" 추가하기` 행(명시적 추가만,
   AI 의도 자동추측 없음). 물건 결과 탭 → `ItemEditor` 편집, 레시피 결과 탭 → 레시피
   탭 상세 push(`AppRouter.openRecipe`). 자연어 문장은 `CaptureSearchQuery` 로 조사·불용어를
   제거한 토큰 전체 일치 + 임박/만료/위치 없음/지금 만들 수 있음/부족 재료 속성 플래그로
   보강. 홈/장소의 정적 검색바는 제거.
   (find/add 의도판별은 검색-우선 통합으로 대체·불필요.)
4. **음성 입력(STT)** — 입력기 완료 + actor 경계 분리 리팩터 완료
   (`SpeechDictationViewModel`(UI 상태/단일 세션 Task) + `SpeechDictationEngine`
   (비-MainActor 권한/오디오/모델) ↔ `DictationEvent` 스트림 경계. iOS 26
   `SpeechAnalyzer` + `SpeechTranscriber` 온디바이스 받아쓰기 → 활성 모드 필드,
   권한·불가용·거부 폴백, tap 버퍼 복사·고아 자원 누수 버그 해소). 잔여: 기기/모델 게이팅·한국어 모델 다운로드 UX,
   실기기 인식 정확도 검증(시뮬레이터 불가).
5. **물건/레시피 고급 편집** — 물건 추가/편집/삭제는 `ItemEditor` 로 연결됨. 물건 사진 선택/저장은 제거했고,
   분류 선택/신규 생성, 태그 다중 선택/신규 생성까지 완료. 수량 1에서
   `-` 탭 시 삭제 확인, 장소 상세 물건 행 "다 썼어요" 빠른 정리까지 완료.
   레시피 상세(`screen-03`)·CRUD(`screen-07`)·시드 10개 완료 — 카드 → `RecipeDetail`,
   "레시피 추가" → `RecipeEditor`, 재료/단계 동적 편집 + 재료 이름→보유 물건 매칭.
   레시피 목록은 검색어 + cuisine + dishType AND 필터로 실제 필터링.
   **레시피 자연어 추가(screen-12) 완료** — 중앙 ✨ → "Add a recipe" → NL 입력
   (텍스트·음성) → AI 파싱 → `RecipeEditor` prefill 확인. 부족분→장보기
   자동 생성과 장보기 완료→재고 반영은 완료.
   (장소 CRUD `screen-05`·세부위치 CRUD `screen-06` 완료 — 추가/편집은 `PlaceEditor`/`SpotEditor`, 삭제는 확인 다이얼로그.)
   장소/세부위치 에디터 확장(아이콘·Space 선택), 정렬 변경(drag) 이 후속.
6. **기기 게이팅 + 한국어/폴백** — AI 미지원 환경 처리. 레시피 NL 파서(screen-12,
   `NLRecipeParser`)의 가용성 게이트(`SystemLanguageModel.default.availability`)·수동
   에디터 폴백은 구현됨(물건 추가는 규칙 기반 `ItemQuickAddParser` 라 AI 게이팅 불필요).
   잔여는 한국어 모델 다운로드/Apple Intelligence 미설치 유도 UX(진행률·동의), 시작 전
   사전 게이팅(마이크/레시피 파싱 진입 시 미가용 사전 안내), 실기기 한국어 인식·추론
   정확도 검증.

## 진행 메모

- 빌드 검증: `tuist generate` → `xcodebuild ... -scheme HomePinApp`.
- 테스트는 후반 단계(`CLAUDE.md` "테스트 정책").
