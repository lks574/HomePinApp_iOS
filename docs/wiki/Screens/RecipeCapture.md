---
aliases: [RecipeCapture, 레시피 NL 입력, 레시피 자연어 추가]
tags: [screen, screen/recipe]
created: 2026-06-16
updated: 2026-06-16
status: in-progress
screen-id: screen-12, screen-13
---

# RecipeCapture (레시피 NL 입력)

레시피([[Recipe]])를 자연어로 추가하는 전용 입력 화면. 중앙 ✨ [[Capture]] 시트의
명시적 "Add a recipe" 행에서 시트로 열린다. 물건 빠른 추가(한 단어)와 달리 레시피는
재료+단계가 긴 텍스트라 **여러 줄 입력 공간**을 따로 둔다. 타이핑·붙여넣기·음성·사진/카메라
OCR 이 모두 같은 단일 입력으로 합류하고, "Sort with AI" 를 눌러야만 파싱이 시작된다(명시적
추가, 의도 자동추측 없음). [[2026-06-15-NL-추가-파서-FoundationModels]] 의 물건 파이프라인을
레시피로 확장한 [[2026-06-16-레시피-NL파서-ParsedRecipe]] 결정(단계 1: 텍스트/음성)과
[[2026-06-16-레시피-OCR-VisionKit]] 결정(단계 2: 사진/카메라 OCR)을 구현한다.

## 역할

- 여러 줄 텍스트 입력 = 타이핑 + 붙여넣기 + 음성 받아쓰기 + 사진/카메라 OCR(단일 경로).
  음성은 [[Capture]] 와 같은 `SpeechDictationViewModel` 입력기를 재사용하고 개행을 보존해
  `text` 에 채운다.
- 사진/카메라 OCR(screen-13): 온디바이스 Vision 으로 이미지→텍스트 추출(`RecipeOCRViewModel`)
  → 입력 필드에 채우기(기존 입력 있으면 개행 append, 없으면 그대로). **자동 파싱 안 함** —
  OCR 은 부정확할 수 있어 사용자가 보고 고친 뒤 "Sort with AI" 로 텍스트 경로에 합류한다.
- "Sort with AI" 명시적 탭 → 가용 시 온디바이스 파싱 → prefill 된 [[RecipeEditor]] 확인
  화면을 시트로 제시. 미가용·실패·취소·빈 결과면 수동 [[RecipeEditor]] `.create` 폴백 시트.
- 파서 추론 중에는 진행 표시 + 취소. 권한 거부·받아쓰기/OCR 불가용·실패는 힌트 + 텍스트 폴백.

## 연결된 화면

- 들어옴 ←: [[Capture]] — "Add a recipe" 행(`.sheet(isPresented:)`)
- 이동 →: [[RecipeEditor]] — AI 파싱 성공 시 `init(prefill:)` 확인 시트, 미가용·실패 시
  수동 `.create` 폴백 시트. 저장 완료 시 시트 전체 dismiss.

## 사용 모델

- 직접 쓰기 없음. 저장은 [[RecipeEditor]] 가 [[Recipe]]/[[RecipeIngredient]]/[[RecipeStep]]
  로 수행하고, 재료→[[Item]] grounding 도 그 저장 매칭(`Item.normalize`)을 재사용한다.
- AI 파서 grounding: `RecipeDraftResolver` 가 `RecipeClassification` 의 cuisine/dishType
  raw 키 후보를 프롬프트에 주입(엔진은 SwiftData·도메인 무지).

## AI 자연어 추가 (파서 경로)

- 가용성 게이트: `SystemLanguageModel.default.availability == .available` 이면 파서 경로,
  아니면 수동 에디터 폴백. 시뮬레이터·미지원 기기는 미가용으로 폴백 검증됨.
- `NLRecipeParser`(`Shared/AI/`, 비-MainActor, **추출만**): `LanguageModelSession` +
  `@Generable ParsedRecipe`(제목·cuisine·dishType·servings·totalMinutes·재료배열
  `[ParsedIngredient(name, quantity)]`·단계 텍스트배열). 단계별 타이머는 파싱 제외.
- `NLRecipeParseViewModel`(@MainActor @Observable): 파싱 상태(idle/parsing/prefill/
  unavailable/failed) + 단일 세션 Task 소유/cancel([[Capture]] `NLParseViewModel` 패턴).
- `RecipeDraftResolver`(도메인 경계): 분류 raw 정규화 매칭(정확 일치만 채움, 표류 흡수)·
  인분/시간 양수만·재료/단계 trim·필터 → `RecipeEditorPrefill` → `RecipeEditorModel(prefill:)`.

## 사진/카메라 OCR (screen-13)

- `TextRecognizer`(`Shared/OCR/`, `Sendable` 비-MainActor): Apple Vision
  `VNRecognizeTextRequest`(`.accurate`, `usesLanguageCorrection`, 한국어+영어). 무거운
  동기 추론이라 `Task.detached` 로 배경 수행 후 결과 문자열만 MainActor 로. 박스 세로
  위치 정렬로 읽기 순서 복원·줄바꿈 보존, 회전 메타데이터 보정.
- `RecipeOCRViewModel`(@MainActor @Observable): 인식 상태(idle/recognizing/recognized/
  failed/empty) + 단일 세션 Task 소유/cancel. 결과는 `recognizedText` 일회성 채널로 emit.
- `CameraImagePicker`(`Shared/OCR/`): `UIImagePickerController`(`.camera`) 래퍼. 델리게이트
  `Coordinator` 는 nonisolated `NSObject` 로 분리(시스템 콜백 격리 트랩 방지), 콜백 안에서만
  `Task { @MainActor in }` hop. 카메라 미가용(시뮬레이터)이면 버튼 숨김.
- 사진 라이브러리는 SwiftUI 네이티브 `PhotosPicker`(`matching: .images`).
- 권한 신규: `NSCameraUsageDescription`·`NSPhotoLibraryUsageDescription`(`Project.swift`
  infoPlist + `InfoPlist.xcstrings` en/ko). 권한 추가 후 `tuist generate` 재실행.

## 상태 관리

- 비영속 UI 상태는 `@State` — 입력 `text`, 확인 시트 라우트 `confirmRoute`, 수동 폴백
  시트 라우트 `manualRoute`, 사진 선택 `photoItem`·카메라/사진 시트 표시 플래그.
- AI 파싱은 얇은 `@Observable` `NLRecipeParseViewModel`(`@State`). `parser.state` 변화를
  `.onChange` 으로 받아 성공이면 확인 시트, 미가용·실패면 수동 폴백. 화면 종료 시 `reset()`.
- 음성은 얇은 `@Observable` `SpeechDictationViewModel`(`@State`). `dictation.transcript`
  변화를 `.onChange` 으로 받아 `text` 에 주입. 화면 종료 시 `reset()`.
- OCR 은 얇은 `@Observable` `RecipeOCRViewModel`(`@State`). `ocr.recognizedText` 변화를
  `.onChange` 으로 받아 `text` 에 채운 뒤 채널 비움. 화면 종료 시 `reset()`.

## 관련 태스크 / 결정

- `[screen-12]`, `[screen-13]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-16-레시피-NL파서-ParsedRecipe]], [[2026-06-16-레시피-OCR-VisionKit]], [[2026-06-15-NL-추가-파서-FoundationModels]], [[2026-06-15-음성입력-STT-아키텍처]], [[2026-06-12-레시피-모델]]
- 아이디어: [[레시피-간편-추가]]

## 메모

- 코드: `HomePinApp/Sources/Features/Recipes/RecipeCaptureView.swift`
- 파서 엔진(추출만, 비-MainActor): `HomePinApp/Sources/Shared/AI/NLRecipeParser.swift`
- 파싱 상태/세션 소유: `HomePinApp/Sources/Features/Recipes/NLRecipeParseViewModel.swift`
- 도메인 변환(분류 raw·draft): `HomePinApp/Sources/Features/Recipes/RecipeDraftResolver.swift`
- OCR 인식기(비-MainActor): `HomePinApp/Sources/Shared/OCR/TextRecognizer.swift`
- OCR 상태/세션 소유: `HomePinApp/Sources/Features/Recipes/RecipeOCRViewModel.swift`
- 카메라 래퍼(Coordinator nonisolated): `HomePinApp/Sources/Shared/OCR/CameraImagePicker.swift`
- 확인 화면(prefill 재사용): [[RecipeEditor]] `init(prefill:)`
- 음성 입력기 재사용: [[Capture]] `HomePinApp/Sources/Shared/Speech/`
