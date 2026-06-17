---
aliases: [next-task, 다음 할 일]
tags: [doc/code, tasks]
created: 2026-06-12
updated: 2026-06-17
status: draft
---

# 다음 할 일

UI 우선 1차(시안 C 화면 골격: 5탭·장소·레시피·홈·추가 시트) 완료 후의 다음 후보.
보류 상세는 `docs/follow-ups.md`.

> 최근 완료: **데이터 백업/가져오기 + CSV 대량 입력(screen-15)** — `Settings > Data >
> Backup & Import`(`DataTransferView`) 진입. **전체 백업** = 디렉터리 패키지
> (`.homepinbackup`, exported UTType `com.sro.homepinappios.backup`/`com.apple.package`) —
> `data.json`(schemaVersion 메타 + 9 엔티티 Codable DTO, 관계 전부 UUID 참조,
> `RecipeStep` 인라인) + `photos/<itemID>.dat`(사진 원본). 외부 의존성 없이 `FileManager`
> 만(ZIP 불채택, `dependencies: []` 유지). export = 전체 fetch→DTO→임시 패키지→`fileExporter`,
> import = `fileImporter`→디코드→schemaVersion 가드→**2-pass upsert**(`BackupUpsertEngine`:
> pass-1 id fetch→갱신/insert, pass-2 UUID 참조 관계 재연결)+사진 복원, 엔티티 단위 스킵+요약.
> import 정책 = id(UUID) upsert/덮어쓰기. **CSV 대량 입력** = Item·Recipe, 3파일
> (`items.csv`·`recipes.csv`·`recipe_ingredients.csv`, 재료는 `recipeTitle` 연결), RFC4180
> 최소 자체 파서/직렬화(`CSV`)+템플릿 export. upsert 키 = id 있으면 id, 없으면
> `normalizedName`(Item)/`title`(Recipe), area/spot/category/tags 는 이름 조회→없으면 생성,
> 행 단위 스킵+요약. 엔진 강제: `normalizedName` 동반 갱신·불변식 `spot→area`·`stockCredited`
> 보존. 얇은 `@Observable DataTransferModel`(비영속 UI 상태+다단계 쓰기 오케스트레이션).
> `SettingsView.clearAllData()` 의 `ShoppingItem` 삭제 누락 수정(export 9종 일치). `@Model`
> 스키마 변경 없음. 결정: `docs/wiki/Decision/2026-06-17-데이터-백업-번들포맷.md`,
> `docs/wiki/Decision/2026-06-17-CSV-대량입력-스키마.md`. 잔여: 사진 downsampling/압축,
> `VersionedSchema` 연동(`docs/follow-ups.md`).
> 이전: **레시피 부재료(optional) 횡단(screen-14)** — 주재료와 별도로
> **부재료**(곁들임·취향껏·선택적)를 입력·표시. `RecipeIngredient.isOptional: Bool = false`
> 가산 필드(마이그레이션 불필요). `Recipe` 의 `missingIngredients`·`isReadyToCook`·
> `inStockCount`·신규 `mainIngredients`/`mainIngredientCount`·`usesExpiringIngredient` 가
> **주재료(`!isOptional`)만** 집계 → "지금 가능" 판정·부족분→장보기에서 부재료 제외(부재료도
> `item` grounding·재고 보유 표시는 동일). `RecipeEditorView` 재료 입력을 주재료/부재료
> 섹션으로 분리(부재료는 비어도 됨), `RecipeEditorModel` 은 `mainIngredients`/
> `optionalIngredients` 두 draft 배열·섹션별 add/remove·연속 sortOrder. `RecipeDetailView`
> 주/부 섹션 구분·요약 분모 주재료 기준. AI 파서 `ParsedIngredient.isOptional`+instructions
> 주/부 안내(자연어·OCR 공용)·확인 화면 교정 친화. 신규 UI 문자열 en/ko. `@Model` 스키마는
> 가산 필드만(기존 데이터/시드 주재료로 자연 동작). 이어서 `RecipeDetail` 재고 요약에서
> 부족 주재료만 장보기에 추가하는 흐름을 완료했다(`ShoppingItem.sourceIngredient` 연동,
> 중복 방지, 완료된 원본 항목 미완료 복구). 이어서 장보기 완료 체크 시 기존 `Item`
> 수량 증가 또는 `ItemEditor` 신규 재고 생성까지 연결했다(`sourceIngredient` 재연결 포함,
> 체크 해제 시 재고 자동 차감 없음). 결정:
> `docs/wiki/Decision/2026-06-16-레시피-NL파서-ParsedRecipe.md`(ParsedIngredient 갱신). 잔여:
> 실기기 AI 주/부 추출 품질.
> 이전: **레시피 자연어 추가 단계 2 — 사진/스크린샷 OCR(screen-13)** —
> `RecipeCaptureView` 에 OCR 입력 소스 추가. 온디바이스 Apple Vision
> (`VNRecognizeTextRequest`, `.accurate`, `usesLanguageCorrection`, 한국어+영어)으로
> 이미지→텍스트 추출. 카메라(`UIImagePickerController`)+사진 라이브러리(`PhotosPicker`)
> 둘 다 진입(카메라는 시뮬레이터 미지원이라 가용 시만). 추출 텍스트는 입력 필드에 **채우기**
> (자동 파싱 안 함 — 확인 단계 유지) → "Sort with AI" 로 단계 1 텍스트 경로 합류.
> `TextRecognizer`(비-MainActor `Sendable`, `Task.detached` 추론) + `RecipeOCRViewModel`
> (@MainActor 단일 세션 Task) + `CameraImagePicker`(Coordinator nonisolated — 시스템 콜백
> 격리 트랩 방지). 권한 신규(비가역): `NSCameraUsageDescription`·`NSPhotoLibraryUsageDescription`
> (`Project.swift` infoPlist + `InfoPlist.xcstrings` en/ko), `tuist generate` 재실행. 권한
> 거부·OCR 실패·빈 결과 모두 현지화 안내 + 텍스트 입력 폴백. `@Model` 스키마 변경 없음.
> 결정: `docs/wiki/Decision/2026-06-16-레시피-OCR-VisionKit.md`. 잔여: 실기기 카메라·한국어/
> 손글씨 OCR 품질(시뮬레이터 미지원).
> 이전: **레시피 자연어 추가 단계 1(screen-12)** — 중앙 ✨ 시트(`CaptureSheet`)에
> 명시적 "Add a recipe" 행 추가(검색-우선 통합 UX 유지, 의도 자동추측 없음) →
> 레시피 전용 입력 화면 `RecipeCaptureView`(여러 줄 텍스트·붙여넣기·음성, 단일 경로).
> "Sort with AI" → 온디바이스 Foundation Models `@Generable ParsedRecipe`
> (`NLRecipeParser` 비-MainActor 추출 / `NLRecipeParseViewModel` 가용성 게이트·단일 Task /
> `RecipeDraftResolver` 분류 raw 정규화·draft 변환) → 확인은 기존 `RecipeEditorView` 를
> `RecipeEditorModel(prefill:)` 로 재사용(AI prefill 배너·빈 행 추가로 교정 친화). 저장은
> 수동 create 와 동일(재료 이름→보유 `Item` 정규화 매칭). 미가용·실패·취소·빈 결과면 수동
> 에디터 폴백. `@Model` 스키마 변경 없음. 결정:
> `docs/wiki/Decision/2026-06-16-레시피-NL파서-ParsedRecipe.md`. 잔여: 단계 2(사진/스크린샷
> OCR), 실기기 한국어 추출 품질.
> 이전: **캡처 시트 검색-우선 통합(screen-04)** — [추가|검색] 모드 토글 제거,
> 단일 입력 필드 하나로 통합. 입력 즉시 실시간 검색(물건+레시피 섹션), 결과 아래 항상
> `+ "{입력어}" 추가하기` 행으로 **명시적 추가만**(AI 가 추가/검색 의도 자동추측 안 함 →
> 오분류 데이터 오염 방지). 음성은 단일 입력 필드를 채우고 같은 `add()` 파서 경로로 합류.
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

1. **AI 자연어 추가** — 1차 구현 완료(screen-09). Foundation Models `@Generable`
   (`NLItemParser`, 추출만·비-MainActor) → `NLParseViewModel`(@MainActor, 가용성
   게이트·단일 세션 Task) → 확인 드래프트(`CaptureDraftReviewView`) → `AddDraftResolver`
   다건 저장(grounding·없으면생성/있으면매핑·`Item.normalize` 매칭). `CaptureSheet.add()`
   가 가용 시 파싱→확인, 미가용·실패·취소 시 단건 스텁 폴백. 텍스트·음성 공용 단일 경로.
   잔여: 실기기 추론·한국어 품질 검증(시뮬레이터 미가용), 모델 다운로드 유도 UX(#5),
   유통기한·메모·find/add 의도판별은 후속. (제품 방향: [[제품-방향-재고-레시피-AI]],
   결정: [[2026-06-15-NL-추가-파서-FoundationModels]])
2. **검색 동작** — 중앙 버튼 시트 **검색-우선 통합** 완료(`screen-04`): [추가|검색]
   모드 토글 제거, 단일 입력 필드 하나(타이핑·음성 공용). 입력 즉시 물건
   (이름·위치·분류·태그·메모 부분 일치) + 레시피(제목·요약·분류·태그·재료 세부 텍스트
   부분 일치) 실시간 검색 → 물건/레시피 섹션, 결과 아래 항상 `+ "{입력어}" 추가하기` 행(명시적 추가만,
   AI 의도 자동추측 없음). 물건 결과 탭 → `ItemEditor` 편집, 레시피 결과 탭 → 레시피
   탭 상세 push(`AppRouter.openRecipe`). 자연어 문장은 `CaptureSearchQuery` 로 조사·불용어를
   제거한 토큰 전체 일치 + 임박/만료/위치 없음/지금 만들 수 있음/부족 재료 속성 플래그로
   보강. 홈/장소의 정적 검색바는 제거.
   (find/add 의도판별은 검색-우선 통합으로 대체·불필요.)
3. **음성 입력(STT)** — 입력기 완료 + actor 경계 분리 리팩터 완료
   (`SpeechDictationViewModel`(UI 상태/단일 세션 Task) + `SpeechDictationEngine`
   (비-MainActor 권한/오디오/모델) ↔ `DictationEvent` 스트림 경계. iOS 26
   `SpeechAnalyzer` + `SpeechTranscriber` 온디바이스 받아쓰기 → 활성 모드 필드,
   권한·불가용·거부 폴백, tap 버퍼 복사·고아 자원 누수 버그 해소). 잔여: 1번 AI 파서
   경로 재사용(받아쓰기 텍스트 → 구조화), 기기/모델 게이팅·한국어 모델 다운로드 UX,
   실기기 인식 정확도 검증(시뮬레이터 불가).
4. **물건/레시피 고급 편집** — 물건 추가/편집/삭제는 `ItemEditor` 로 연결됨. 사진 선택/제거,
   분류 선택/신규 생성, 태그 다중 선택/신규 생성까지 완료. 수량 1에서
   `-` 탭 시 삭제 확인, 장소 상세 물건 행 "다 썼어요" 빠른 정리까지 완료.
   레시피 상세(`screen-03`)·CRUD(`screen-07`)·시드 10개 완료 — 카드 → `RecipeDetail`,
   "레시피 추가" → `RecipeEditor`, 재료/단계 동적 편집 + 재료 이름→보유 물건 매칭.
   레시피 목록은 검색어 + cuisine + dishType AND 필터로 실제 필터링.
   **레시피 자연어 추가(screen-12/13) 단계 1·2 완료** — 중앙 ✨ → "Add a recipe" → NL 입력
   (텍스트·음성·사진/카메라 OCR) → AI 파싱 → `RecipeEditor` prefill 확인. 부족분→장보기
   자동 생성과 장보기 완료→재고 반영은 완료.
   남은 범위는 사진 downsampling/압축 정책.
   (장소 CRUD `screen-05`·세부위치 CRUD `screen-06` 완료 — 추가/편집은 `PlaceEditor`/`SpotEditor`, 삭제는 확인 다이얼로그.)
   장소/세부위치 에디터 확장(아이콘·Space 선택), 정렬 변경(drag) 이 후속.
5. **기기 게이팅 + 한국어/폴백** — AI 미지원 환경 처리. NL 추가 파서의 가용성 게이트
   (`SystemLanguageModel.default.availability`)·단건 스텁 폴백은 #1 에서 구현됨. 잔여는
   한국어 모델 다운로드/Apple Intelligence 미설치 유도 UX(진행률·동의), 시작 전 사전
   게이팅(마이크/추가 진입 시 미가용 사전 안내), 실기기 한국어 인식·추론 정확도 검증.

## 진행 메모

- 빌드 검증: `tuist generate` → `xcodebuild ... -scheme HomePinApp`.
- 테스트는 후반 단계(`CLAUDE.md` "테스트 정책").
