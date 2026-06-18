---
aliases: [레시피 NL 파서, ParsedRecipe, 레시피 자연어 추가 파서]
tags: [decision, decision/data]
created: 2026-06-16
updated: 2026-06-18
status: accepted
---

# 2026-06-16 레시피 NL 파서 — ParsedRecipe (Foundation Models)

[[Capture]] 중앙 ✨ 시트에서 레시피를 온디바이스 LLM 으로 구조화 추가하는 비가역 결정
(`@Generable` 출력 스키마 + 확인 화면 방식 + grounding 범위 + 진입점). [[레시피-간편-추가]]
아이디어 §1·§2(텍스트/음성/붙여넣기)의 **코어 + 입력 소스 1·2** 를 구체화하고,
물건 전용 [[2026-06-15-NL-추가-파서-FoundationModels]] 의 "추출(엔진)/매칭(도메인) 분리 +
가용성 폴백 + 텍스트·음성 단일 경로" 원칙을 레시피로 확장한다.

## 맥락

[[RecipeEditor]] 수동 입력은 제목·분류·인분·시간·재료 N·단계 N 으로 필드가 많아 마찰이
크다. 이 결정 시점에 물건용 `NLItemParser → NLParseViewModel → AddDraftResolver → 확인 드래프트`
파이프라인이 있었고(이후 2026-06-18 물건 경로는 규칙 기반 `ItemQuickAddParser` 로 교체되며 제거됨 —
[[2026-06-15-NL-추가-파서-FoundationModels]] 참고), 레시피는 같은 패턴에 **스키마 한 벌**을 더해
재사용한다. 최소 사양
iOS 26.5 / Swift 6.2. 출력 스키마·확인 방식·진입점은 되돌리기 어려운 표면이라 확정이
필요했다. 이번 단계 범위는 텍스트/음성/붙여넣기까지이며 OCR(#3·#4)은 다음 단계다.

## 결정

1. **프레임워크 = Foundation Models 재사용.** 레시피 추출도 온디바이스
   `LanguageModelSession`. 물건과 동일하게 추론은 비-MainActor 엔진(`NLRecipeParser`),
   UI 상태/단일 세션 Task 는 `@MainActor @Observable`(`NLRecipeParseViewModel`)이 소유.
2. **출력 스키마 = 기본 세트(`@Generable ParsedRecipe`).** 제목·cuisine·dishType·
   servings(Int)·totalMinutes(Int)·재료배열 `[ParsedIngredient(name, quantity, isOptional)]`·
   단계 텍스트 배열 `[String]`. **단계별 타이머(`RecipeStep.minutes`)는 파싱 제외** —
   확인 화면에서 수동. 수량은 자유 문자열(`"200g"`, `"한 컵"`)로 받고 단위 분해는 사람이.
   **(2026-06-16 추가) `ParsedIngredient.isOptional`** — 필수 주재료 false / 곁들임·취향껏·
   선택적 부재료 true. instructions 에 주/부 구분 안내 추가. 모델이 가끔 틀리므로 확인 화면
   ([[RecipeEditor]] 주재료/부재료 섹션)에서 교정. 부재료는 조리 가능 판정·부족분→장보기에서
   빠진다([[Recipe]] computed 가 주재료만 집계). 가산 필드(기본 false)라 회귀 없음.
3. **확인 화면 = 기존 에디터 prefill 재사용(신규 화면 아님).** screen-09(`AddDraft` 다건)는
   확장하지 않고, `RecipeEditorModel(prefill:)` 로 AI 결과를 채워 기존
   `RecipeEditorView` 의 재료/단계 편집·저장 로직을 그대로 쓴다. AI 가 채운 값임을
   가벼운 배너로 구분하고, 모델이 순서·수량을 가끔 틀리므로 빈 행을 하나 더해 교정 친화.
4. **grounding = ① 분류 raw 후보 주입(프롬프트), ② 재료 Item 링크(저장 시).**
   cuisine/dishType 는 `RecipeClassification` raw 키 후보를 프롬프트에 주입하고 정확히
   일치할 때만 raw 로 채운다(표류 흡수, 표시 라벨 아님). 재료→`Item` 매칭은 별도 사전
   매칭을 두지 않고 **`RecipeEditorModel.save()` 의 `Item.normalize` 매칭을 그대로** 쓴다.
   부족분→`ShoppingItem` 자동 생성은 후속.
5. **진입점 = 중앙 ✨ 시트(`CaptureSheet`)에 합류, 의도 자동 추측 없음.** 검색-우선 통합
   UX 를 깨지 않는다. 단일 query 검색/추가 행은 그대로 두고, 별도 **"Add a recipe"** 행을
   항상 노출해 사용자가 **명시적으로** 레시피 입력 화면(`RecipeCaptureView`, 여러 줄
   텍스트/붙여넣기/음성)으로 간다. 물건 vs 레시피를 AI 가 추측하지 않는다.
6. **가용성 게이트.** Foundation Models 미지원 시 수동 `RecipeEditorView` 폴백. 음성은
   기존 `SpeechDictationViewModel` 입력기를 그대로 쓰고 별도 레시피 음성 파서를 두지 않는다.

## 폐기한 대안

- **AI 자동 저장(확인 생략)** — 모델이 순서·수량을 틀릴 수 있어 레시피도 확인 필수.
- **screen-09 확인 화면 확장** — 레시피는 단계/재료 편집 형태가 물건 다건과 달라 기존
  레시피 에디터 prefill 이 더 자연스럽고 저장 로직 중복도 없앤다.
- **음성 독립 파서** — 단일 경로 원칙 위배. 받아쓰기 텍스트가 같은 입력으로 합류.
- **분류 enum 강제** — 후보 주입 + 사후 정규화(raw 일치만 채움)로 표류 흡수.

## 영향 / 결과

- 신규 비영속 타입만 추가: `@Generable ParsedRecipe`/`ParsedIngredient`,
  `RecipeEditorPrefill`. **`@Model` 스키마 변경 없음**(기존 `Recipe`/`RecipeIngredient`/
  `RecipeStep`/`Item` 으로 저장).
- 신규 파일: `Shared/AI/NLRecipeParser.swift`, `Features/Recipes/NLRecipeParseViewModel.swift`,
  `Features/Recipes/RecipeDraftResolver.swift`, `Features/Recipes/RecipeCaptureView.swift`.
- 후속(미결): 사진/스크린샷 OCR(#3·#4), 실기기 한국어 추출 품질.

## 관련

- 아이디어: [[레시피-간편-추가]] · 상위 [[AI-적용-후보]]
- 잇는 결정: [[2026-06-15-NL-추가-파서-FoundationModels]] · [[2026-06-15-음성입력-STT-아키텍처]] · [[2026-06-15-레시피-요리종류-dishType]] · [[2026-06-12-레시피-모델]]
- 화면/모델: [[Capture]] · [[RecipeEditor]] · [[Recipe]] ⊃ [[RecipeIngredient]] · [[Item]]
