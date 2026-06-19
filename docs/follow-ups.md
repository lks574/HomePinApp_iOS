---
aliases: [follow-ups, 후속 항목]
tags: [doc/code, followups]
created: 2026-06-12
updated: 2026-06-18
status: draft
---

# 후속 항목

리뷰 스코프 외 지적·검증 대기 항목을 누적한다.

## 플랫폼 / macOS (screen-17)

- [ ] **macOS 실기 런타임 검증(AC-005~006)** — iOS·macOS 빌드는 green 이나 macOS 는
  실기 런타임 미검증(빌드만으로는 권한·파일·디바이스 경로를 확인 못 함).
  - AC-005 파일 Import/Export — [[DataTransfer]] `.homepinbackup` export/import 가
    sandbox(`files.user-selected.read-write`)에서 정상인지.
  - AC-006 STT 권한/받아쓰기 — 마이크(`device.audio-input`)·음성인식 권한·온디바이스
    받아쓰기가 macOS 에서 정상인지(`AVAudioSession` 없이).
  (결정: `docs/wiki/Decision/2026-06-17-macOS-네이티브-타깃-추가.md`)
- [ ] **macOS 데스크톱 UX 최적화** — 셸(`RootTabView`)·네비게이션은 macOS 재설계 없이
  그대로 동작(이번 범위). 메뉴 바·창 크기/리사이즈·사이드바·키보드 단축키 등 데스크톱
  1급 경험은 후속. (결정: `docs/wiki/Decision/2026-06-17-macOS-네이티브-타깃-추가.md`)

## 데이터 / 영속화

- [ ] **백업 schemaVersion ↔ VersionedSchema 연동** — `BackupBundle.schemaVersion`(현재 1)
  은 import 가드(상위 버전 거부)만 쓴다. 첫 릴리스 `VersionedSchema` 도입 시(아래 항목),
  백업 스키마 버전을 모델 스키마 버전과 연동하고 구버전 번들 마이그레이션 경로를 정해야
  한다. (모듈: `Features/DataTransfer/`, 결정:
  `docs/wiki/Decision/2026-06-17-데이터-백업-번들포맷.md`)
- [ ] **CSV 재료 재import 중복 누적** — `recipe_ingredients.csv` 재료는 id 키가 없어(스키마상
  의도) upsert 불가, 항상 신규 insert 된다. 같은 재료 CSV 를 두 번 넣으면 재료가 중복
  누적된다. 재료 식별 키(예: recipeTitle+name) 기반 dedup 도입 여부 검토. (모듈:
  `Features/DataTransfer/CSVImporter.swift`, 결정:
  `docs/wiki/Decision/2026-06-17-CSV-대량입력-스키마.md`)

- [ ] **이름 중복 방지(앱 로직)** — `.unique` 는 upsert 의미라 사용자 입력
  이름엔 안 씀. 한 공간 내 구역명·한 구역 내 세부위치명·전역 카테고리/태그명 중복을
  **쓰기 로직에서 검증**해야 한다. (모델: [[Space]]/[[Area]]/[[Spot]]/[[ItemCategory]]/[[Tag]],
  결정: `docs/wiki/Decision/2026-06-12-위치-물건-데이터모델.md`)
- [ ] 첫 릴리스 시 `VersionedSchema`(`SchemaV1`) + `SchemaMigrationPlan` 도입
  (`AppModelContainer` 에 연결). 결정: `docs/wiki/Decision/2026-06-12-swiftdata-마이그레이션-방침.md`
- [ ] `Item.name` 직접 수정 경로 금지 — `ItemEditor` 는 `name` 변경 시
  `normalizedName` 을 함께 갱신한다. 향후 다른 쓰기 경로가 생기면 같은 규칙을 반드시
  적용해야 한다.

## UI 1차 이후 보류 (의도된 미구현)

UI 우선 1차(시안 C 화면 골격)에서 의도적으로 뒤로 미룬 것들.

- [~] **물건 AI 자연어 파싱 — 제거됨(규칙 기반 `ItemQuickAddParser` 로 대체)** — 한때
  추가 시트(`CaptureSheet`)가 입력 텍스트를 온디바이스 Foundation Models 파서
  (`NLItemParser` `@Generable`)로 구조화하고 확인 드래프트(`CaptureDraftReviewView`,
  screen-09)에서 다건 확인/수정 후 `AddDraftResolver` 로 일괄 저장했으나, screen-04
  검색-우선 통합에서 물건 추가가 규칙 기반 `ItemQuickAddParser → ItemEditor.create(initialName:)`
  로 교체되며 이 물건 NL 파서 플로우는 dead island 가 되어 2026-06-18 제거됐다. 결정
  supersede: `docs/wiki/Decision/2026-06-15-NL-추가-파서-FoundationModels.md`. 레시피 NL
  파서(screen-12)·STT 는 영향 없음.
- [x] **음성(STT) 입력기 연동 완료** — `SpeechDictation`(iOS 26 `SpeechAnalyzer` +
  `SpeechTranscriber` 온디바이스 받아쓰기)을 `CaptureSheet` 마이크 버튼에 실연동.
  받아쓰기 결과를 단일 입력 필드(`query`)에 주입, 권한·불가용·
  거부 시 텍스트 폴백. (결정: `docs/wiki/Decision/2026-06-15-음성입력-STT-아키텍처.md`)
  잔여는 아래 3개 항목으로 분리.
- [x] **음성 → 공용 물건 에디터 경로 재사용 완료** — 받아쓰기로 채운 텍스트가 타이핑 텍스트와
  같은 `CaptureSheet.add()` 경로에서 `ItemEditor` `create(initialName:)` 로 합류한다.
- [ ] **한국어 받아쓰기 모델 다운로드 UX** — 현재는 모델 미설치·미지원 시 `state`
  를 `.unavailable` 로 떨어뜨려 텍스트 폴백만 안내. 진행률·다운로드 동의 UI 미구현
  (`AssetInventory.assetInstallationRequest` 진행률 노출).
- [ ] **음성 입력 기기 게이팅** — `SpeechTranscriber.isAvailable`·로케일 지원으로
  마이크 진입 자체를 사전 차단/안내하는 게이팅은 미구현(현재는 시작 시점 판단).
- [ ] **음성 받아쓰기 실기기 검증** — actor 경계 분리 리팩터(`SpeechDictationViewModel`
  + `SpeechDictationEngine` ↔ `DictationEvent`) + 오디오 세션 인터럽션 처리(인터럽션
  `.began` 시 세션 종료 → `.idle` 복귀, transcript 보존, 자동 재개 없음) 후 빌드 green·
  시뮬레이터 불가용 폴백 경로(텍스트 입력)까지 확인. 실제 권한 프롬프트·한국어 모델
  다운로드·온디바이스 인식 정확도·녹음 중 재토글/모드전환 시 자원 정리·**인터럽션
  실동작(전화/Siri/타 앱 점유 시 마이크 버튼 `.idle` 복귀)** 은 시뮬레이터로 검증
  불가(인터럽션은 `.recording` 진입 전 시뮬레이터에서 빠짐) → 실기기 확인 필요.
  **무음 자동 종료(3초 텍스트 무변화 시 `stop()` 자동 종료, transcript 보존)** 도
  같은 이유로 시뮬레이터 인식 불가 → 실기기에서 발화 멈춤 후 3초 자동 종료·재무장
  (말 이어가면 안 끊김)·`.preparing`(모델 다운로드) 중 미종료 확인 필요.
- [x] **홈/장소 정적 검색바 제거** — 실제 필터가 없는 placeholder 검색바는 죽은 입력이라
  홈과 장소 상세에서 제거했다. 중앙 AI 검색 시트가 전역 물건/레시피 검색 진입점 역할을
  맡는다.
- [x] **자연어 검색 1차 완료** — 중앙 검색은 정규화 부분 일치 + 로컬 자연어 토큰/속성
  규칙(`CaptureSearchQuery`)으로 보강됐다. `#Predicate`/AI 변환 고도화는 아래 별도 항목.
- [x] **물건 삭제/정리 UX** — `ItemEditor` 편집 모드 삭제, 수량 1에서 `-` 탭 시 삭제 확인,
  [[PlaceDetail]] 물건 행 context menu "다 썼어요" 빠른 정리 추가. 삭제 시
  `RecipeIngredient.item` 은 nullify 로 끊겨 레시피 부족 상태로 돌아간다.
- [x] **물건 고급 편집 1차** — `ItemEditor` 에 분류 선택/신규 생성,
  태그 다중 선택/신규 생성을 추가했다. 저장 시 `category`·`tags` 갱신.
- [x] **물건 사진 선택/저장 제거** — `Item.photoData`, 물건 에디터 사진 선택 UI,
  백업 `photos/` 패키징/복원을 제거했다.
- [ ] **Pretendard 미번들** — 우선 시스템 폰트. 폰트 파일 번들 + 적용 필요.
- [ ] **비주얼 미세조정** — `음성 플로우` 시안은 컴포넌트 픽셀 미확인(개념 기준 구성).
  실기기 렌더 후 중앙 마이크 위치·탭바 여백·세이프에어리어 조정 필요.
- [ ] **Apple Intelligence 기기 게이팅 / 한국어 모델 다운로드 / fallback UX (레시피 NL 파서)** —
  레시피 NL 파서(`NLRecipeParser`/`NLRecipeParseViewModel`, screen-12)의 미가용 기기·언어 처리
  (텍스트·수동 에디터 폴백은 구조상 확보). 잔여: 모델 미설치 시 다운로드 동의·진행률 UI,
  진입 전 사전 게이팅 안내(현재는 파싱 트리거 시점 가용성 판단). 결정:
  `docs/wiki/Decision/2026-06-16-레시피-NL파서-ParsedRecipe.md`. (물건 NL 파서 게이팅 부분은
  물건 island 제거로 무효 — 물건 추가는 규칙 기반 `ItemQuickAddParser` 로 게이팅 불필요.)
- [ ] **Space 단일 가정** — UI 가 "장소"=Area 만 노출(단일 "우리집"). 멀티홈 필요 시
  Space 스위처 노출.
- [x] **레시피 검색/분류 필터 실제 동작** — 레시피 목록 검색바가 제목·요약·분류 라벨·
  재료 세부 텍스트를 필터하고, cuisine/dishType 칩이 AND 필터로 동작한다.
- [x] **홈 카드 액션 연결** — 장보기 요약은 [[Shopping]], 장소 바로가기는 [[PlaceDetail]],
  최근 추가 행과 임박 배너는 [[ItemEditor]] 로 이어진다.

## AI 검색·추가 / 장보기 후속

i18n·검색·장보기 1차(중앙 AI 버튼·레시피 검색·장보기 CRUD) 이후 미룬 항목. 결정:
`docs/wiki/Decision/2026-06-16-장보기-데이터모델.md`.

- [x] **자연어 검색 1차(로컬 규칙)** — "냉동실에 있는 소고기" 같은 문장을
  `CaptureSearchQuery` 가 조사·불용어 제거 토큰(`냉동실`, `소고기`)으로 바꾸고, 임박/만료/
  위치 없음/지금 만들 수 있음/부족 재료 같은 속성 플래그를 적용한다. 검색 대상도 이름뿐
  아니라 위치·분류·태그·메모·레시피 메타데이터까지 확장 완료.
- [ ] **자연어 검색 고도화(`#Predicate`/AI 변환)** — 현재 1차는 in-memory 규칙 기반.
  데이터가 커지거나 "주방 말고 냉동실" 같은 부정/비교 조건이 필요해지면 술어 변환으로 확장.
- [x] **검색 결과 랭킹·초성·편집거리 fallback·추천 칩·중복 가드·직전 위치 prefill 완료(screen-16)**
  — `Shared/Search/`(`SearchRules`·`SearchRanking`·`Hangul`·`Levenshtein`·`RecentSearches`).
  결과를 정확>접두>부분 등급 + 상태 가중치 + 이름순 정렬, 초성 전용 질의 매칭(유니코드 산술),
  결과 0 + `hasConcreteSignal` 일 때만 음절 편집거리 근사 폴백, 빈 입력 추천 칩(최근 검색어
  `@AppStorage`+임박 물건), 같은 `normalizedName` 추가 시 합치기/새로 추가 제안, 직전 추가
  위치 prefill(`@AppStorage` lastArea/SpotID). 모든 경로가 `hasConcreteSignal` 가드·
  `normalizedName` 단일 매칭키·위치 불변식을 우회하지 않음. 새 `@Model`·외부 의존성 없음.
  결정: `docs/wiki/Decision/2026-06-17-자연어-규칙-외부화.md`,
  `docs/wiki/Decision/2026-06-17-검색-랭킹-초성-편집거리.md`.
- [ ] **편집거리 자모 정밀화** — `Levenshtein` 은 현재 **음절 단위**(한 음절=한 단위)라
  "사과"↔"사가"는 거리 1 이지만 "사과"↔"삭과"(받침 차이)도 1 음절 치환으로 본다. 받침 한
  글자만 다른 오타를 더 가깝게 보려면 자모(초·중·종성) 단위 분해 후 거리 계산이 필요하다.
  (모듈: `Shared/Search/Levenshtein.swift`, 결정:
  `docs/wiki/Decision/2026-06-17-검색-랭킹-초성-편집거리.md`)
- [ ] **의미 플래그 후보 배열 외부화** — `screen-16` S1 은 조사·불용어·의미단어 3개만
  `SearchRules.json` 으로 외부화했다. `CaptureSearchQuery` init 의 의미 플래그 후보 배열
  (`wantsExpiringSoon`/`wantsExpired`/`wantsNoLocation`/`wantsReadyRecipe`/`wantsMissingRecipe`
  의 `containsAny` 후보)은 아직 코드 상수다. 사전 보강을 코드 변경 없이 하려면 같은 리소스로
  외부화해야 한다. (모듈: `Features/Capture/CaptureSheet.swift`,
  `Resources/SearchRules.json`, 결정: `docs/wiki/Decision/2026-06-17-자연어-규칙-외부화.md`)
- [x] **find/add 의도 자동 판별 — 검색-우선 통합으로 대체(불필요)** — [추가|검색]
  모드 토글을 없애고 단일 입력 필드로 통합했다. 검색은 입력 즉시 항상 일어나고, 추가는
  사용자가 결과 아래 `+ "{입력어}" 추가하기` 행을 명시적으로 누를 때만 일어난다. AI 가
  의도를 자동 추측하지 않으므로 오분류로 인한 데이터 오염 위험이 제거됨 → 의도 자동판별
  자체가 불필요. (screen-04, `CaptureSheet`)
- [x] **레시피 자연어 추가 — 단계 1(텍스트/음성/붙여넣기) 완료(screen-12)** — 중앙 ✨
  시트의 명시적 "Add a recipe" 행 → `RecipeCaptureView`(여러 줄 텍스트·붙여넣기·음성)
  → 온디바이스 Foundation Models `@Generable ParsedRecipe`(`NLRecipeParser`/
  `NLRecipeParseViewModel`/`RecipeDraftResolver`) → 확인은 기존 `RecipeEditorView` 를
  `RecipeEditorModel(prefill:)` 로 재사용. 미가용·실패 시 수동 에디터 폴백. 재료 Item
  grounding 은 기존 저장 매칭(`Item.normalize`) 재사용. 결정:
  `docs/wiki/Decision/2026-06-16-레시피-NL파서-ParsedRecipe.md`. 잔여: 실기기 한국어 추출 품질(아래).
- [x] **레시피 OCR 사진/카메라 입력 제거** — `RecipeCaptureView` 의 사진/카메라 OCR 진입점,
  `RecipeOCRViewModel`, `TextRecognizer`, `CameraImagePicker`, 카메라/사진 권한 문구를 제거했다.
- [ ] **레시피 NL 추가 실기기 한국어 추출 품질** — 빌드 green·시뮬레이터 폴백 경로
  (미가용 → 수동 `RecipeEditorView`)·prefill·저장 매칭까지 정적/시뮬레이터 검증. 실제
  온디바이스 추론·한국어 레시피 추출 품질(재료 분리·수량 문자열·단계 순서·분류 raw 매칭)
  ·`@Generable` 스키마 준수는 Apple Intelligence 가용 실기기 필수(시뮬레이터 `availability`
  미가용).
- [x] **레시피 부족분 → 장보기 자동 생성** — `Recipe.missingIngredients` →
  `ShoppingItem` 자동 생성(`sourceIngredient` 연동 훅 사용). `RecipeDetail` 재고 요약에서
  부족 주재료만 장보기에 추가하고, 같은 재료/같은 이름 미완료 항목 중복은 막는다.
  **부재료(`RecipeIngredient.isOptional`)는 대상 아님** — `missingIngredients` 가
  주재료(`!isOptional`)만 집계하므로 자동 반영(2026-06-16).
- [x] **장보기 완료 → 재고(`Item`) 반영** — 구매 완료 체크 시 같은 이름의 기존 재고가
  있으면 수량을 증가시키고, 없으면 `ItemEditor` 로 위치(`Area`)를 선택해 신규 `Item` 을
  만든다. `sourceIngredient` 가 있으면 반영된 `Item` 을 연결해 레시피 부족 상태도 해소한다.
  체크 해제는 재고 차감 없이 장보기 상태만 되돌린다.

## 다국어(i18n) 후속

i18n 1차(screen-10, en/ko 시스템 추종) 완료 후 남은 항목. 결정:
`docs/wiki/Decision/2026-06-16-i18n-다국어화-방침.md`.

- [ ] **STT 인식 locale 시스템 추종 검토** — `SpeechDictationEngine` 의 인식 locale 이
  `Locale("ko-KR")` 로 한국어 고정. 영어 사용자도 한국어 인식기로 받아쓰기된다.
  시스템 언어(en/ko)에 맞춰 인식 locale 을 고르고, 미지원 시 폴백 안내를 다듬어야 한다.
  (현재 i18n 범위 밖으로 분리. STT 권한·불가용·오류 표시 문구는 이미 현지화됨.)
- [ ] **영어 NL 추출 품질 검증 (레시피 NL 파서)** — `NLRecipeParser` 프롬프트·`@Guide` 가
  한국어 텍스트 추출 기준이라 영어 입력의 재료 분리·수량 문자열·분류 raw 매칭 정확도가
  미검증. 영어 입력 품질 확인 후 필요 시 프롬프트를 언어별로 다루는 방안 검토(시뮬레이터
  추론 불가 → Apple Intelligence 가용 실기기 필요). (물건 NL 파서는 island 제거로 무효 —
  물건 추가는 규칙 기반 `ItemQuickAddParser`.)
- [x] **AdMob 전면 최소간격 의미 명료화 — 해소(2026-06-18)** — "같은 날이면 차단"(하루
  1회) 우선 검사를 제거하고 **최소 간격(3분) + 하루 상한(4회)** 곱 조건으로 재설계해
  데드코드를 없앴다. 두 조건이 모두 실제로 동작한다. (결정:
  `docs/wiki/Decision/2026-06-18-전면광고-트리거-재설계.md`)
- [ ] **AdMob 보상형 로드 실패 자가 회복** — `presentRewarded` 는 미로드 시 조용히
  false 반환만 하고 재로드를 트리거하지 않아, 스타트업 보상형 로드가 실패하면 세션
  내 버튼이 계속 비활성(흐름 차단은 없음, R7/R9 만족). 세션 내 재시도 경로 추가 검토.
  (screen-18 리뷰 관찰)
- [ ] **AdMob 출시 전 실광고 ID 교체·실기 런타임 검증** — 현재 Google 테스트 앱/단위
  ID 사용. 출시 전 실 AdMob 계정 App ID·전면/보상형 단위 ID 로 교체. 실기에서 UMP
  동의 폼·ATT 프롬프트 표출, 전면/보상형 실제 렌더·닫힘·보상 콜백 타이밍 검증(정적
  리뷰 불가). (screen-18)
- [ ] **전면 트리거 재설계 실기기 검증 + 캡 수치 튜닝** — 트리거를 마일스톤 2개
  (`recipeAdded`·`shoppingSessionCompleted`)로 두고 캡을 최소 간격 8분 + 하루 3회로
  완화했다(2026-06-18). 핵심 고빈도 루프(물건 추가)는 UX 부담으로 트리거에서 제외. 실기기에서
  실제 노출 빈도·UX 체감을 보고 수치(8분/3회)를 튜닝하고, **에디터가 닫힌 직후 `onDisappear`
  에서 전면을 present 할 때 드물게 발생할 수 있는 타이밍 실패**(닫힘 애니메이션과 겹침)를
  확인한다. 실패 시 다음 runloop 으로 지연 present 검토. 필요 시 캡처 트리거를 강한
  게이팅(세션 N개 이상/M번째 세션) 얹어 재도입 검토. (모듈:
  `Features/Monetization/AdService.swift`, `Features/Recipes/RecipeEditorView.swift`. 결정:
  `docs/wiki/Decision/2026-06-18-전면광고-트리거-재설계.md`)

## iCloud 동기화 / CloudKit (screen-19)

- [ ] **iCloud / CloudKit entitlement 복구 (실기기 서명 차단 해소)** — Apple Developer
  App ID(`com.sro.homepinappios`)에 iCloud capability 와 컨테이너
  (`iCloud.com.sro.homepinapp`)가 미등록이라 실기기(device) 빌드 서명이 실패했다
  (`Provisioning profile ... doesn't include the iCloud capability`). 임시로 iOS·macOS
  entitlements 의 `com.apple.developer.icloud-container-identifiers`·
  `icloud-services(CloudKit)` 키를 **주석 처리해 제거**(2026-06-18) → 실기기·시뮬레이터
  빌드 green. CloudKit 동기화는 entitlement 없이도 `AppModelContainer` 가 로컬 fallback
  하므로 런타임 안전(기능만 비활성). 계정에 iCloud capability + 컨테이너 등록 후 양쪽
  entitlements 파일의 주석 블록을 복구해야 CloudKit private 동기화·가족공유가 실기기에서
  동작한다. (파일: `Tuist/Support/HomePinApp-iOS.entitlements`,
  `Tuist/Support/HomePinApp-macOS.entitlements`. 결정:
  `docs/wiki/Decision/2026-06-17-CloudKit-private-동기화-골격.md`)
- [ ] **CloudKit private 동기화·가족공유 실기기/실계정 검증** — private DB 동기화, 가족공유
  초대(`UICloudSharingController`)·`CKShare` 스냅샷 저장, 공유 가져오기(`sharedCloudDatabase`
  → 로컬 upsert)는 시뮬레이터/정적 검증만 됐다. entitlement 복구 + 유료 Developer Program +
  실 iCloud 계정으로 실기기 검증 필요. 잔여: 참가자 push, 충돌 처리. (결정:
  `docs/wiki/Decision/2026-06-18-CloudKit-가족공유-1차-스냅샷.md`,
  `docs/wiki/Decision/2026-06-18-CloudKit-가족공유-2차-가져오기.md`)

## Firebase (Analytics·Crashlytics·RemoteConfig)

- [ ] **Firebase 콘솔 앱 등록 + `GoogleService-Info.plist` 주입** — 코드만 먼저 들어간
  상태(plist 없으면 `FirebaseBootstrap` 가 구성 skip → 빌드 green·앱 정상). Firebase
  콘솔에서 iOS(`com.sro.homepinappios`)·macOS(`com.sro.homepinappmac`) 앱을 등록하고
  각 `GoogleService-Info.plist` 를 `HomePinApp/Resources-iOS/`·`Resources-macOS/` 에
  넣어야 Analytics·Crashlytics·RemoteConfig 가 실제 동작한다. 실 plist 는 `.gitignore`
  비커밋(샘플만 커밋). (결정:
  `docs/wiki/Decision/2026-06-18-Firebase-analytics-crashlytics-remoteconfig.md`)
- [ ] **RemoteConfig 파라미터 생성** — 콘솔 RemoteConfig 에 아래 3개 키를 만들어야 버전
  게이트가 동작한다(미생성/fetch 실패 시 게이트 미적용, 차단 없음). 키·타입·예시:
  - `latest_app_version` (String, 예: `1.2.0`) — 현재 < 이 값이면 **선택** 업데이트 안내(1회 알럿).
  - `min_required_app_version` (String, 예: `1.1.0`) — 현재 < 이 값이면 **강제** 업데이트(차단 화면).
  - `update_store_url` (String, 예: App Store 링크) — 업데이트 버튼이 여는 URL. 비우면 기본값 사용.
  비교는 `CFBundleShortVersionString` 과 `.numeric` 비교다(예: `1.10.0` > `1.9.0`). iOS·macOS
  공통 키 — 플랫폼별로 다른 버전을 강제하려면 키 분리 검토(예: `ios_*`/`macos_*`).
- [ ] **출시 후 실제 App Store 링크 교체** — 앱 미출시라 기본 스토어 URL 이 플레이스홀더
  (`VersionGateService.defaultStoreURLString = https://apps.apple.com/app/id000000000`).
  출시 후 실제 링크로 교체하고 RemoteConfig `update_store_url` 로 내린다. macOS 는 스토어
  URL 이 iOS 와 다를 수 있어 별도 확인. (파일:
  `HomePinApp/Sources/Features/AppUpdate/VersionGateService.swift`)
- [ ] **버전 게이트·크래시·dSYM 실기기 검증** — 강제/선택 업데이트 분기(차단 화면·1회 알럿·
  설정 행), Crashlytics 크래시 수집·증상 리포트, dSYM 업로드 스크립트(SPM 체크아웃 `run` +
  plist 존재 가드) 동작은 정적 검증만 됐다. 실 plist + 실기기에서 검증 필요. Analytics
  자동 이벤트 수집과 커스텀 `app_update_prompt` 이벤트 콘솔 도달도 확인. (모듈:
  `Features/AppUpdate/`, `Shared/Firebase/`, `Project.swift` Crashlytics 스크립트)
- [ ] **macOS Firebase 런타임 검증** — macOS 샌드박스에 `com.apple.security.network.client`
  를 추가했다(서버 통신용). 실제 macOS 앱에서 Firebase 서버 접속·RemoteConfig fetch·
  Crashlytics 전송이 되는지 확인. (파일: `Tuist/Support/HomePinApp-macOS.entitlements`)
