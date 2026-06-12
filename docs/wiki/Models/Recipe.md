---
aliases: [Recipe, 레시피]
tags: [model]
created: 2026-06-12
updated: 2026-06-12
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
| `cuisine` | `String?` | 한식/양식… (초기 문자열) |
| `sourceURL` | `String?` | 출처 |
| `steps` | `[RecipeStep]` | Codable 값(text+minutes?), 순서=배열 |
| `createdAt`/`updatedAt` | `Date` | |
| `missingIngredients`/`isReadyToCook` | computed | 없는 재료·지금 가능 여부 |

> 사진(photoData)은 v1 제외.

## 관계

- → [[RecipeIngredient]] : `ingredients` `@Relationship(.cascade)`
- ↔ [[Tag]] : `tags` **N:N**(inverse 를 `Recipe.tags` 에 선언)

## 동작

- 보유/부족: 각 [[RecipeIngredient]] 의 `isInStock` 집계 → "N개 부족 / 지금 가능".
- 임박 추천: 임박 [[Item]] → `usedInIngredients` → 이 레시피.

## 메모

- 결정: [[2026-06-12-레시피-모델]] · 제품 방향: [[제품-방향-재고-레시피-AI]]
- 코드: `HomePinApp/Sources/Models/Recipe.swift`
