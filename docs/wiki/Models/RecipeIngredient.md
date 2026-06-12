---
aliases: [RecipeIngredient, 레시피 재료]
tags: [model]
created: 2026-06-12
updated: 2026-06-12
status: in-progress
---

# RecipeIngredient (레시피 재료)

레시피 재료 한 줄. 재고(Item)와 매칭되면 보유/부족을 판정. 매칭 실패해도 `name` 으로
레시피는 온전(식재료=Item 통합).

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | 재료명(표시·매칭 기준) |
| `quantity` | `Double?` | |
| `unit` | `String?` | g·개·큰술… |
| `note` | `String?` | "다진 것" 등 |
| `sortOrder` | `Int` | |
| `isInStock` | computed | 매칭 item 있고 수량>0 |

## 관계

- ← [[Recipe]] : `recipe` (부모, cascade 로 함께 삭제)
- → [[Item]] : `item` (매칭 재고, `.nullify` — Item 삭제 시 링크만 끊김)

## 매칭

1. 명시적 링크(`item`) 우선 — AI/사용자가 지정.
2. 미링크 시 `Item.normalizedName` ↔ 재료 정규화명(+동의어·AI). 상세: [[2026-06-12-레시피-모델]].

## 메모

- 코드: `HomePinApp/Sources/Models/RecipeIngredient.swift`
