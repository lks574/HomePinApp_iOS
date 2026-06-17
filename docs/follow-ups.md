---
aliases: [follow-ups, 후속 항목]
tags: [doc/code, followups]
created: 2026-06-12
updated: 2026-06-17
status: draft
---

# 후속 항목

리뷰 스코프 외 지적·검증 대기 항목을 누적한다.

## 플랫폼 / macOS (screen-17)

- [ ] **macOS 실기 런타임 검증(AC-004~006)** — iOS·macOS 빌드는 green 이나 macOS 는
  실기 런타임 미검증(빌드만으로는 권한·파일·디바이스 경로를 확인 못 함).
  - AC-004 PhotosPicker OCR — 사진 라이브러리 선택→Vision OCR→[[RecipeCapture]] 채우기.
  - AC-005 파일 Import/Export — [[DataTransfer]] `.homepinbackup` export/import 가
    sandbox(`files.user-selected.read-write`)에서 정상인지.
  - AC-006 STT 권한/받아쓰기 — 마이크(`device.audio-input`)·음성인식 권한·온디바이스
    받아쓰기가 macOS 에서 정상인지(`AVAudioSession` 없이).
  (결정: `docs/wiki/Decision/2026-06-17-macOS-네이티브-타깃-추가.md`)
- [ ] **sandbox 사진 entitlement 보정 필요 여부** — 현재 macOS entitlements 는
  app-sandbox·files.user-selected.read-write·device.audio-input 만. PhotosPicker 사진
  접근이 런타임에 막히면 사진 관련 entitlement 추가가 필요할 수 있다(AC-004 검증에서
  판단). (파일: `Tuist/Support/HomePinApp-macOS.entitlements`)
- [ ] **macOS 데스크톱 UX 최적화** — 셸(`RootTabView`)·네비게이션은 macOS 재설계 없이
  그대로 동작(이번 범위). 메뉴 바·창 크기/리사이즈·사이드바·키보드 단축키 등 데스크톱
  1급 경험은 후속. (결정: `docs/wiki/Decision/2026-06-17-macOS-네이티브-타깃-추가.md`)
- [ ] **macOS 카메라 입력 대응 여부** — 카메라 OCR 은 `UIImagePickerController` 기반이라
  macOS 비노출(사진 라이브러리 OCR 로 대체). 필요 시 AVFoundation 캡처로 macOS 카메라
  입력을 새로 구현할지 검토. (모듈: `Shared/OCR/CameraImagePicker.swift`)

## 데이터 / 영속화

- [ ] **백업 사진 downsampling/압축** — screen-15 백업은 아이템 사진을
  `photos/<itemID>.dat` 에 **원본 그대로** 번들에 넣는다(이번 범위 제외). 대용량 사진이
  많으면 패키지가 커지므로, export 시 다운샘플/압축(예: HEIC·JPEG quality) 정책을 정해야
  한다. (모듈: `Features/DataTransfer/BackupArchive.swift`, 결정:
  `docs/wiki/Decision/2026-06-17-데이터-백업-번들포맷.md`)
- [ ] **백업 schemaVersion ↔ VersionedSchema 연동** — `BackupBundle.schemaVersion`(현재 1)
  은 import 가드(상위 버전 거부)만 쓴다. 첫 릴리스 `VersionedSchema` 도입 시(아래 항목),
  백업 스키마 버전을 모델 스키마 버전과 연동하고 구버전 번들 마이그레이션 경로를 정해야
  한다. (모듈: `Features/DataTransfer/`, 결정:
  `docs/wiki/Decision/2026-06-17-데이터-백업-번들포맷.md`)
- [ ] **백업 import 사진 클리어 비대칭** — 번들 아이템의 `photoFile == nil`(사진 없음)이고
  기존 아이템에 사진이 있으면 `restorePhotos` 가 기존 `photoData` 를 보존한다(다른 스칼라
  필드는 전부 덮어쓰는 것과 비대칭). "병합" 관점에선 안전한 보존이라 버그는 아니나, 의도를
  명시하거나 사진도 덮어쓰기로 통일할지 정해야 한다. (모듈:
  `Features/DataTransfer/BackupArchive.swift` restorePhotos)
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

- [x] **AI 자연어 파싱 연동 완료(1차)** — 추가 시트(`CaptureSheet`)가 입력 텍스트를
  온디바이스 Foundation Models 파서(`NLItemParser` `@Generable`)로 구조화하고 확인
  드래프트(`CaptureDraftReviewView`, screen-09)에서 다건 확인/수정 후 `AddDraftResolver`
  가 없으면생성/있으면매핑(`Item.normalize`)으로 일괄 저장. 가용성 게이트·실패·취소 시
  단건 스텁 폴백. (결정: `docs/wiki/Decision/2026-06-15-NL-추가-파서-FoundationModels.md`)
  잔여: 실기기 추론·한국어 품질 검증, 모델 다운로드 유도 UX, 유통기한·메모. (find/add
  의도판별은 검색-우선 통합 UX 로 대체·불필요.)
- [x] **음성(STT) 입력기 연동 완료** — `SpeechDictation`(iOS 26 `SpeechAnalyzer` +
  `SpeechTranscriber` 온디바이스 받아쓰기)을 `CaptureSheet` 마이크 버튼에 실연동.
  받아쓰기 결과를 단일 입력 필드(`query`)에 주입, 권한·불가용·
  거부 시 텍스트 폴백. (결정: `docs/wiki/Decision/2026-06-15-음성입력-STT-아키텍처.md`)
  잔여는 아래 3개 항목으로 분리.
- [x] **음성 → AI 파서 경로 재사용 완료** — 받아쓰기로 채운 텍스트가 타이핑 텍스트와
  같은 `CaptureSheet.add()` 파서 경로로 합류한다(추가 모드). 텍스트·음성 공용 단일 파서.
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
- [x] **물건 고급 편집 1차** — `ItemEditor` 에 사진 선택/제거, 분류 선택/신규 생성,
  태그 다중 선택/신규 생성을 추가했다. 저장 시 `Item.photoData`·`category`·`tags` 갱신.
  잔여: 사진 downsampling/압축 정책.
- [ ] **Pretendard 미번들** — 우선 시스템 폰트. 폰트 파일 번들 + 적용 필요.
- [ ] **비주얼 미세조정** — `음성 플로우` 시안은 컴포넌트 픽셀 미확인(개념 기준 구성).
  실기기 렌더 후 중앙 마이크 위치·탭바 여백·세이프에어리어 조정 필요.
- [ ] **NL 추가 파서 실기기 검증** — 빌드 green·시뮬레이터 폴백 경로(미가용 → 단건
  스텁 → `ItemEditor` 이름 prefill)·UI·매칭/저장 로직까지 시뮬레이터 검증 완료. 실제
  온디바이스 추론·한국어 추출 품질(다건 분리·수량·위치 grounding 정확도)·`@Generable`
  스키마 준수·확인 화면 신규/기존 매칭·다건 일괄 저장은 Apple Intelligence 가용 실기기
  필수(시뮬레이터 `availability` 미가용). 결정: `docs/wiki/Decision/2026-06-15-NL-추가-파서-FoundationModels.md`
- [ ] **Apple Intelligence 기기 게이팅 / 한국어 모델 다운로드 / fallback UX** — 미가용
  기기·언어 처리(텍스트·단건 폴백은 구조상 확보). 잔여: 모델 미설치 시 다운로드 동의·
  진행률 UI, 추가 진입 전 사전 게이팅 안내(현재는 `add()` 시점 가용성 판단).
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
  `docs/wiki/Decision/2026-06-16-레시피-NL파서-ParsedRecipe.md`. 잔여: 단계 2(사진/스크린샷
  OCR), 실기기 한국어 추출 품질(아래).
- [x] **레시피 NL 추가 — 사진/스크린샷 OCR(단계 2) 완료(screen-13)** — 온디바이스 Apple
  Vision(`VNRecognizeTextRequest`, `.accurate`, `usesLanguageCorrection`, 한국어+영어)로
  이미지→텍스트 추출 후 기존 입력 필드에 채워 같은 코어(`NLRecipeParser` "Sort with AI")에
  합류. 카메라(`UIImagePickerController`)+사진(`PhotosPicker`) 둘 다, 카메라·사진 권한 신규
  (`InfoPlist.xcstrings` en/ko). 자동 파싱 안 함(확인 단계 유지). `TextRecognizer`(비-MainActor)
  + `RecipeOCRViewModel`(@MainActor 단일 Task) + `CameraImagePicker`(Coordinator nonisolated).
  결정: `docs/wiki/Decision/2026-06-16-레시피-OCR-VisionKit.md`. ([[레시피-간편-추가]] §Phase 2)
- [ ] **레시피 OCR 실기기 카메라·한국어/손글씨 품질 검증** — 빌드 green·시뮬레이터
  사진 라이브러리→Vision OCR→입력 필드 채움 경로는 검증. **카메라 즉석 촬영은 시뮬레이터
  미지원**이라 코드 경로/권한 키로만 검증함. 실기기에서 카메라 촬영→OCR, 한국어 인쇄체·
  손글씨·요리책 사진의 인식 정확도(재료/단계 줄 분리·순서 복원·언어 혼용)는 실기기 필수.
- [ ] **표/복잡 레이아웃 OCR 은 reading-order 근사 — 완벽한 표 복원은 후속** —
  `TextRecognizer` 가 관찰을 "줄 그룹핑(세로 겹침) + 줄 내 가로 정렬(minX)" 로 reading-order
  를 복원해, 표/멀티컬럼에서 같은 행 셀이 좌우로 뒤섞이던 열 인터리브 버그는 해소(2026-06-16).
  다만 **셀 격자(열 구조) 자체는 복원하지 않는다** — 한 행을 좌→우 연속 텍스트로 읽어 AI 파서가
  행 맥락을 이해하게 두는 근사다. 셀 정렬·열 헤더 매핑이 필요한 복잡 표는 후속(예: x-좌표
  클러스터링으로 열 경계 추정). 같은 줄 임계값(`sameLineHeightRatio = 0.6`)은 실데이터로
  미세조정 여지(너무 작은/큰 글자 혼용 표) — 실기기 다양한 표 레시피로 확인 필요.
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
- [ ] **영어 NL 추출 품질 검증** — `NLItemParser` 프롬프트·`@Guide` 가 한국어 문장
  추출 기준이라 영어 입력의 다건 분리·수량·위치 grounding 정확도가 미검증. 영어 입력
  품질 확인 후 필요 시 프롬프트를 언어별로 다루는 방안 검토(시뮬레이터 추론 불가 →
  Apple Intelligence 가용 실기기 필요).
- [ ] **AdMob 전면 최소간격 의미 명료화** — `AdService.isFrequencyCapSatisfied` 는
  "같은 날이면 차단"(하루 1회)이 먼저라, 30분 최소간격 검사는 날짜 경계를 넘은
  경우에만 도달해 사실상 데드코드. 정책상 더 보수적이라 버그는 아니나, 향후
  "하루 N회 + 간격" 으로 완화할 때 의미를 갖는다. (screen-18 리뷰 관찰)
- [ ] **AdMob 보상형 로드 실패 자가 회복** — `presentRewarded` 는 미로드 시 조용히
  false 반환만 하고 재로드를 트리거하지 않아, 스타트업 보상형 로드가 실패하면 세션
  내 버튼이 계속 비활성(흐름 차단은 없음, R7/R9 만족). 세션 내 재시도 경로 추가 검토.
  (screen-18 리뷰 관찰)
- [ ] **AdMob 출시 전 실광고 ID 교체·실기 런타임 검증** — 현재 Google 테스트 앱/단위
  ID 사용. 출시 전 실 AdMob 계정 App ID·전면/보상형 단위 ID 로 교체. 실기에서 UMP
  동의 폼·ATT 프롬프트 표출, 전면/보상형 실제 렌더·닫힘·보상 콜백 타이밍 검증(정적
  리뷰 불가). (screen-18)
