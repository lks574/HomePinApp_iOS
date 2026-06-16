---
aliases: [RecipeEditor, 레시피 추가/편집]
tags: [screen, screen/recipe]
created: 2026-06-15
updated: 2026-06-16
status: in-progress
screen-id: screen-07
---

# RecipeEditor (레시피 추가/편집)

레시피([[Recipe]])를 새로 만들거나 편집하는 공용 시트. 기본정보와 함께 재료·조리
단계를 동적 행으로 추가/삭제한다. [[ItemEditor]] 의 `@Observable` 에디터 패턴을 따른다.

## 역할

- 기본정보 입력: 제목(필수)·인분·소요 시간·요약.
- 분류: 요리권(cuisine)·요리 종류(dishType)를 각각 프리셋 칩으로 단일 선택(재탭 해제).
- 재료([[RecipeIngredient]]) 동적 편집: 이름·수량·단위 행 추가/삭제.
- 조리 단계([[RecipeStep]]) 동적 편집: 단계 텍스트·소요 분 행 추가/삭제.
- 저장 시 각 재료 이름을 보유 [[Item]] 과 정규화 매칭해 `RecipeIngredient.item` 연결
  (없으면 nil) → 상세 화면 재고 상태가 산다.
- 편집 모드 하단 삭제 버튼 + 확인(레시피 삭제, 재료 cascade).

## 연결된 화면

- 들어옴 ←: [[Recipes]] — "레시피 추가" 버튼(`.create`). `.sheet(item:)`
- 들어옴 ←: [[RecipeDetail]] — ⋯ 메뉴 "편집"(`.edit`). `.sheet(item:)`
- 들어옴 ←: [[RecipeCapture]] — AI 파싱 성공 시 `init(prefill:)` 확인 화면으로 push, 미가용·실패 시 수동 `.create` 폴백 시트. AI prefill 모델은 `isAIPrefilled` 배너로 가볍게 구분하고, 재료/단계 끝에 빈 행을 하나 더해 교정 친화.

## 사용 모델

- [[Recipe]] — 쓰기(`modelContext.insert` / 필드 갱신 / `delete`)
- [[RecipeIngredient]] — 쓰기(draft → materialize, 편집 시 기존 라인 cascade 정리 후 재구성)
- [[RecipeStep]] — 쓰기(`recipe.steps` 값 배열 갱신)
- [[Item]] — 읽기 `@Query`, 재료 이름 매칭으로 `item` 링크

## 상태 관리

- 얇은 `@Observable` 모델(`RecipeEditorModel`). 사유: 저장 전 draft(기본정보·재료/단계
  동적 행)와 다단계 쓰기 불변식(create/edit 분기·ingredients 재구성·sortOrder·이름 매칭).
- View 는 `@State private var model` + `$model.x` 바인딩(프로젝트 관례상 `@Bindable` 미사용).
- 재고 매칭 후보 `availableItems` 는 View 의 `@Query items` 를 저장 직전 주입.
- create 모드는 3종: 수동(`init(mode: .create)`), AI prefill 확인(`init(prefill:)`,
  `isAIPrefilled = true`). prefill 은 분류 raw·재료/단계 draft 를 채우고 저장 로직은 수동과
  동일(재료 Item 매칭 재사용)하므로 [[RecipeCapture]] 가 별도 저장 경로를 두지 않는다.

## 관련 태스크 / 결정

- `[screen-07]`, `[screen-12]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-레시피-모델]], [[2026-06-16-레시피-NL파서-ParsedRecipe]]

## 메모

- 코드: `HomePinApp/Sources/Features/Recipes/RecipeEditorView.swift` · `RecipeEditorModel.swift`
- 에디터 패턴 참고: [[ItemEditor]].
- AI prefill 변환: `RecipeDraftResolver.prefill(from:)` → `RecipeEditorPrefill` → `RecipeEditorModel(prefill:)`.
