---
aliases: [Recipes, 레시피]
tags: [screen, screen/recipe]
created: 2026-06-12
updated: 2026-06-17
status: in-progress
screen-id: screen-01
---

# Recipes (레시피)

보유 재료([[Item]])로 만들 수 있는 요리를 추천하는 탭 화면. 유통기한 임박 재료를 우선 소진하도록 "임박 재료로 만들기" 와 "내 재료로 만들 수 있어요" 목록을 보여준다.

## 역할

- 유통기한 임박 [[Item]] 을 요약 카드로 보여준다.
- 임박 재료를 쓰는 [[Recipe]] 와 보유 재료로 만들 수 있는 레시피를 나눠 나열한다.
- 검색어로 제목·요약·분류 라벨·재료명/단위/메모를 부분 일치 필터한다.
- 요리권(한식/일식…) 칩과 요리 종류(국·찌개/볶음…) 칩으로 필터([[Recipe]]
  `cuisine`·`dishType` AND 필터).

## 연결된 화면

- 들어옴 ←: 탭바 (5-슬롯 중 레시피 탭)
- 들어옴 ←: [[Capture]] — AI 검색 레시피 결과 탭(레시피 탭 전환 + 상세 push). `AppRouter.openRecipe`
- 이동 →: [[RecipeDetail]] — 레시피 카드 탭(`NavigationLink`, `screen-03`)
- 이동 →: [[RecipeEditor]] — "레시피 추가" 버튼(`.create`, `screen-07`). `.sheet(item:)`

## 사용 모델

- [[Recipe]] — 읽기 `@Query(sort: \Recipe.title)`
- [[RecipeIngredient]] — 보유/임박 매칭(관계 경유)
- [[Item]] — 읽기 `@Query`, 보유·임박 판정 기준

## 상태 관리

- 직결(View ↔ SwiftData). 비영속 UI 상태는 `@State searchText`(검색어),
  `@State cuisine`/`dish`(선택 칩).
- 탭 경로는 셸 라우터가 소유: `NavigationStack(path:)` 를 `router.recipesPath` 에
  바인딩(수동 `Binding`). [[Capture]] 검색 → 상세 교차 push 가 탭 재생성 후에도 유지.

## 관련 태스크 / 결정

- `[screen-01]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-레시피-모델]] · [[2026-06-12-식재료-모델-Item-통합]]

## 메모

- 코드: `HomePinApp/Sources/Features/Recipes/RecipesView.swift`
- 임박/보유 판정·추천은 현재 seed 기반 단순 로직. AI 추천은 후속.
- 카드 → [[RecipeDetail]] push, "레시피 추가" → [[RecipeEditor]] 시트 연결됨.
