---
aliases: [follow-ups, 후속 항목]
tags: [doc/code, followups]
created: 2026-06-12
updated: 2026-06-16
status: draft
---

# 후속 항목

리뷰 스코프 외 지적·검증 대기 항목을 누적한다.

## 데이터 / 영속화

- [ ] **이름 중복 방지(앱 로직)** — `@Attribute(.unique)` 는 upsert 의미라 사용자 입력
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
- [ ] **자연어 검색 미구현** — 현재 중앙 검색은 정규화 부분 일치 기반. 자연어 검색
  (`#Predicate` 변환 등)은 후속.
- [x] **물건 삭제/정리 UX** — `ItemEditor` 편집 모드 삭제, 수량 1에서 `-` 탭 시 삭제 확인,
  [[PlaceDetail]] 물건 행 context menu "다 썼어요" 빠른 정리 추가. 삭제 시
  `RecipeIngredient.item` 은 nullify 로 끊겨 레시피 부족 상태로 돌아간다.
- [ ] **물건 고급 편집 잔여** — 카테고리·태그·사진 편집은 미구현.
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
- [ ] **레시피 dish 필터 정적** — cuisine 필터만 동작, dish(국·찌개/볶음…) 필터는
  장식. 모델에 dish 분류 추가 여부 포함 검토.
- [ ] **홈 "장소 바로가기" 탭 동작 없음** — `HomeView.placeShortcuts` 가 단순
  `VStack`(배지+이름)이라 탭해도 [[PlaceDetail]] 로 이동하지 않는 죽은 상호작용.
  탭 시 해당 장소 상세로 진입 연결 필요(장소 탭 `NavigationStack` 경유 방법 검토).

## AI 검색·추가 / 장보기 후속

i18n·검색·장보기 1차(중앙 AI 버튼·레시피 검색·장보기 CRUD) 이후 미룬 항목. 결정:
`docs/wiki/Decision/2026-06-16-장보기-데이터모델.md`.

- [ ] **자연어 검색(`#Predicate` 변환)** — 현재 검색은 정규화 부분 일치만. "냉동실에
  있는 소고기" 같은 자연어를 위치·속성 술어로 변환하는 검색은 후속.
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
