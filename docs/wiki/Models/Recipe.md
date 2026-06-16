---
aliases: [Recipe, 레시피]
tags: [model]
created: 2026-06-12
updated: 2026-06-16
status: in-progress
---

# Recipe (레시피)

레시피 저장 + 재고 연동. 재료를 재고(Item)와 매칭해 보유/부족을 판정.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `title` | `String` | |
| `summary` | `String?` | |
| `servings` | `Int?` | 인분 |
| `totalMinutes` | `Int?` | 조리시간 |
| `cuisine` | `String?` | 요리권: 한식/일식/중식/양식/분식 (문자열). 목록 필터·에디터 칩 연동 |
| `dishType` | `String?` | 요리 종류: 국·찌개/볶음/구이/조림/밥·면/반찬 (문자열). 목록 필터·에디터 칩 연동 |
| `sourceURL` | `String?` | 출처 |
| `steps` | `[RecipeStep]` | Codable 값(text+minutes?), 순서=배열 |
| `createdAt`/`updatedAt` | `Date` | |
| `missingIngredients`/`isReadyToCook` | computed | 없는 재료·지금 가능 여부 |
| `inStockCount` | computed | 보유 재료 수 (← RecipesView `haveCount`) |
| `usesExpiringIngredient` | computed | 임박 재료 사용 여부 (← `soonRecipes` 필터) |

> 사진(photoData)은 v1 제외.

## 관계

- → [[RecipeIngredient]] : `ingredients` `@Relationship(.cascade)`
- ↔ [[Tag]] : `tags` **N:N**(inverse 를 `Recipe.tags` 에 선언)

## 동작

- 보유/부족: 각 [[RecipeIngredient]] 의 `isInStock` 집계 → "N개 부족 / 지금 가능".
- 임박 추천: 임박 [[Item]] → `usedInIngredients` → 이 레시피.
- 도메인 판정은 모델 계산 프로퍼티로 둔다(View 에 비즈니스 로직 금지). 결정:
  [[2026-06-15-에디터-상태-소유-패턴]].

## 메모

- 결정: [[2026-06-12-레시피-모델]] · [[2026-06-15-레시피-요리종류-dishType]] · [[2026-06-16-레시피-NL파서-ParsedRecipe]] · 제품 방향: [[제품-방향-재고-레시피-AI]]
- 코드: `HomePinApp/Sources/Models/Recipe.swift`
- 쓰는 화면: [[RecipeEditor]](수동·AI prefill 공용) ← [[RecipeCapture]](자연어 추가, 비영속 `ParsedRecipe` → prefill). 스키마 변경 없음.
