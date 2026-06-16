---
aliases: [RecipeDetail, 레시피 상세]
tags: [screen, screen/recipe]
created: 2026-06-15
updated: 2026-06-16
status: in-progress
screen-id: screen-03
---

# RecipeDetail (레시피 상세)

한 레시피([[Recipe]])의 메타·재고 상황·재료·조리 단계를 보여주는 상세 화면.
[[Recipes]] 목록의 카드를 탭하면 push 로 진입하고, 상단 ⋯ 메뉴로 편집/삭제한다.

## 역할

- [[Recipe]] 의 제목·요약·메타(종류 · 인분 · 소요 시간)를 헤더로 보여준다.
- 재고 요약: 보유 **주재료** 수/전체·진행바·"지금 만들 수 있어요"/부족 재료 칩. 분모는 주재료(`mainIngredientCount`) 기준(부재료는 판정에서 빠진다).
- 부족 주재료가 있으면 장보기 추가 버튼을 보여주고, 누르면 [[ShoppingItem]] 을 생성한다(`sourceIngredient` 연결). 같은 원본 재료나 같은 이름의 미완료 장보기 항목이 있으면 중복 생성하지 않고, 완료된 원본 항목은 미완료로 되돌린다.
- 재료 목록([[RecipeIngredient]], `sortOrder` 순): 주재료 섹션 + (있으면) 부재료 섹션("선택" 라벨). 이름·수량+단위·보유 상태 칩(보유/임박/없음). 부재료도 보유 표시는 동일.
- 조리 단계([[RecipeStep]]): 번호 매긴 목록 + 단계별 소요 분.
- 상단 ⋯ 메뉴: 편집([[RecipeEditor]] 편집) / 삭제(확인 후 `modelContext.delete` → `dismiss`).

## 연결된 화면

- 들어옴 ←: [[Recipes]] — 레시피 카드 탭(`NavigationLink`)
- 이동 →: [[RecipeEditor]] — ⋯ 메뉴 "편집"(`.edit`). `.sheet(item:)`

## 사용 모델

- [[Recipe]] — 읽기(전달받은 `recipe`), 삭제는 `modelContext.delete`
- [[RecipeIngredient]] — 읽기(관계 경유 `recipe.ingredients`), 재고 상태 칩
- [[ShoppingItem]] — 읽기 `@Query` 로 중복 확인, 부족 주재료 추가 시 `modelContext.insert`
- [[RecipeStep]] — 읽기(`recipe.steps` 값 배열)
- [[Item]] — 간접(재료의 `item` 링크로 보유/임박 판정)

## 상태 관리

- 직결(View ↔ SwiftData). 전달받은 `Recipe` 의 필드·관계를 직접 읽는다. 재료 계산은
  모델 계산 프로퍼티(`inStockCount`·`isReadyToCook`·`missingIngredients`·`mainIngredientCount`)에 위임 — 전부 주재료 기준.
- 편집 시 [[RecipeEditor]] 가 `recipe.ingredients` 를 직접 재설정하므로 dismiss 후
  상세가 반영된다.
- 비영속 UI 상태: 에디터 `editorRoute`, 삭제 확인 `showingDeleteConfirm`.
- 장보기 추가는 `Recipe.missingIngredients`(주재료만)와 `ShoppingItem` 쿼리를 조합한다. 같은
  `sourceIngredient` 또는 같은 `normalizedName` 의 미완료 항목이 있으면 새 항목을 만들지 않는다.

## 관련 태스크 / 결정

- `[screen-03]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-레시피-모델]] · [[2026-06-12-식재료-모델-Item-통합]]

## 메모

- 코드: `HomePinApp/Sources/Features/Recipes/RecipeDetailView.swift`
- push 진입(자체 NavigationStack 없음) + 커스텀 backButton(dismiss) — [[PlaceDetail]] 패턴.
- 재고 상태 칩 토큰은 [[Recipes]] 목록과 동일하게 맞춤.
