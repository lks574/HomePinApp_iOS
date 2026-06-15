---
aliases: [Recipes, 레시피]
tags: [screen, screen/recipe]
created: 2026-06-12
updated: 2026-06-15
status: in-progress
screen-id: screen-01
---

# Recipes (레시피)

보유 재료([[Item]])로 만들 수 있는 요리를 추천하는 탭 화면. 유통기한 임박 재료를 우선 소진하도록 "임박 재료로 만들기" 와 "내 재료로 만들 수 있어요" 목록을 보여준다.

## 역할

- 유통기한 임박 [[Item]] 을 요약 카드로 보여준다.
- 임박 재료를 쓰는 [[Recipe]] 와 보유 재료로 만들 수 있는 레시피를 나눠 나열한다.
- 요리 종류(한식/일식 등)·메뉴 칩으로 필터(현재 UI, 실제 필터는 후속).

## 연결된 화면

- 들어옴 ←: 탭바 (5-슬롯 중 레시피 탭)
- 이동 →: RecipeDetail — 레시피 카드 탭 (`screen-03`, 미구현)

## 사용 모델

- [[Recipe]] — 읽기 `@Query(sort: \Recipe.title)`
- [[RecipeIngredient]] — 보유/임박 매칭(관계 경유)
- [[Item]] — 읽기 `@Query`, 보유·임박 판정 기준

## 상태 관리

- 직결(View ↔ SwiftData). 비영속 UI 상태는 `@State cuisine`(선택 칩)뿐.

## 관련 태스크 / 결정

- `[screen-01]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-레시피-모델]] · [[2026-06-12-식재료-모델-Item-통합]]

## 메모

- 코드: `HomePinApp/Sources/Features/Recipes/RecipesView.swift`
- 임박/보유 판정·추천은 현재 seed 기반 단순 로직. AI 추천은 후속.
- RecipeDetail(`screen-03`) 추가 시 이 노트의 "연결된 화면" 을 `[[RecipeDetail]]` 로 갱신.
