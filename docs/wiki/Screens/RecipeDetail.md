---
aliases: [RecipeDetail, 레시피 상세]
tags: [screen, screen/recipe]
created: 2026-06-15
updated: 2026-06-15
status: in-progress
screen-id: screen-03
---

# RecipeDetail (레시피 상세)

한 레시피([[Recipe]])의 메타·재고 상황·재료·조리 단계를 보여주는 상세 화면.
[[Recipes]] 목록의 카드를 탭하면 push 로 진입하고, 상단 ⋯ 메뉴로 편집/삭제한다.

## 역할

- [[Recipe]] 의 제목·요약·메타(종류 · 인분 · 소요 시간)를 헤더로 보여준다.
- 재고 요약: 보유 재료 수/전체·진행바·"지금 만들 수 있어요"/부족 재료 칩.
- 재료 목록([[RecipeIngredient]], `sortOrder` 순): 이름·수량+단위·보유 상태 칩(보유/임박/없음).
- 조리 단계([[RecipeStep]]): 번호 매긴 목록 + 단계별 소요 분.
- 상단 ⋯ 메뉴: 편집([[RecipeEditor]] 편집) / 삭제(확인 후 `modelContext.delete` → `dismiss`).

## 연결된 화면

- 들어옴 ←: [[Recipes]] — 레시피 카드 탭(`NavigationLink`)
- 이동 →: [[RecipeEditor]] — ⋯ 메뉴 "편집"(`.edit`). `.sheet(item:)`

## 사용 모델

- [[Recipe]] — 읽기(전달받은 `recipe`), 삭제는 `modelContext.delete`
- [[RecipeIngredient]] — 읽기(관계 경유 `recipe.ingredients`), 재고 상태 칩
- [[RecipeStep]] — 읽기(`recipe.steps` 값 배열)
- [[Item]] — 간접(재료의 `item` 링크로 보유/임박 판정)

## 상태 관리

- 직결(View ↔ SwiftData). 전달받은 `Recipe` 의 필드·관계를 직접 읽는다. 재료 계산은
  모델 계산 프로퍼티(`inStockCount`·`isReadyToCook`·`missingIngredients`)에 위임.
- 편집 시 [[RecipeEditor]] 가 `recipe.ingredients` 를 직접 재설정하므로 dismiss 후
  상세가 반영된다.
- 비영속 UI 상태: 에디터 `editorRoute`, 삭제 확인 `showingDeleteConfirm`.

## 관련 태스크 / 결정

- `[screen-03]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-레시피-모델]] · [[2026-06-12-식재료-모델-Item-통합]]

## 메모

- 코드: `HomePinApp/Sources/Features/Recipes/RecipeDetailView.swift`
- push 진입(자체 NavigationStack 없음) + 커스텀 backButton(dismiss) — [[PlaceDetail]] 패턴.
- 재고 상태 칩 토큰은 [[Recipes]] 목록과 동일하게 맞춤.
