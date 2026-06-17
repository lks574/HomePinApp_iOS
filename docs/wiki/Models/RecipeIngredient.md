---
aliases: [RecipeIngredient, 레시피 재료]
tags: [model]
created: 2026-06-12
updated: 2026-06-17
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
| `isOptional` | `Bool = false` | 부재료(곁들임·취향껏·선택적) 여부. 가산 필드(기본 false=주재료). 조리 가능 판정·부족분·장보기 집계는 주재료만 본다([[Recipe]] computed) |
| `isInStock` | computed | 매칭 item 있고 수량>0 (주/부 무관 동일) |
| `stockStatus` | computed | 재고 상태 도메인 enum `missing`/`soon`/`have` (주/부 무관 동일, 시각 매핑은 View) |

## 관계

- ← [[Recipe]] : `recipe` (부모, cascade 로 함께 삭제)
- → [[Item]] : `item` (매칭 재고, `.nullify` — Item 삭제 시 링크만 끊김)

## 매칭

1. 명시적 링크(`item`) 우선 — AI/사용자가 지정.
2. 미링크 시 `Item.normalizedName` ↔ 재료 정규화명(+동의어·AI). 상세: [[2026-06-12-레시피-모델]].

## 부재료(isOptional)

- 주재료(`!isOptional`)만 [[Recipe]] 의 `missingIngredients`·`isReadyToCook`·`inStockCount`·`mainIngredientCount` 집계 대상. 부재료는 보유/부족 표시만 하고 "지금 가능" 판정·부족분→장보기에서 빠진다.
- AI 파서(`ParsedIngredient.isOptional`)가 주/부 추출 → 확인 화면([[RecipeEditor]] 부재료 섹션)에서 교정 가능. 결정: [[2026-06-16-레시피-NL파서-ParsedRecipe]].
- 가산 필드(기본값 보유)라 기존 데이터/시드는 전부 주재료로 자연 동작 — lightweight 마이그레이션 안전.

## 메모

- 코드: `HomePinApp/Sources/Models/RecipeIngredient.swift`
- [[DataTransfer]] — 전체 백업 export/import 대상(2-pass id upsert). CSV 대량 입력은 Item·Recipe 와 위치/분류/태그 이름 조회→생성. 결정: [[2026-06-17-데이터-백업-번들포맷]]·[[2026-06-17-CSV-대량입력-스키마]].
