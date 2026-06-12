---
aliases: [Item, 물건]
tags: [model]
created: 2026-06-12
updated: 2026-06-12
status: in-progress
---

# Item (물건)

핀하는 대상. 최소한 구역에 속하고(앱 규칙), 세부위치는 선택. 위치/카테고리 삭제 시
nullify 로 보존된다.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | `#Index` |
| `normalizedName` | `String` | `#Index`, 매칭/검색 키(소문자·공백정리). `Item.normalize()` |
| `quantity` | `Int` | 기본 1 |
| `photoData` | `Data?` | `@Attribute(.externalStorage)` |
| `memo` | `String?` | |
| `expiresAt` | `Date?` | `#Index`, 유통/소비기한 |
| `createdAt`/`updatedAt` | `Date` | |
| `locationPath` | computed | "집 > 주방 > 냉동실" (영속화 안 함) |

## 관계

- → [[Area]] : `area: Area?` (앱규칙 필수, nullify 보존 위해 옵셔널)
- → [[Spot]] : `spot: Spot?` (선택)
- → [[ItemCategory]] : `category: ItemCategory?` (분류 1개)
- ↔ [[Tag]] : `tags: [Tag]` **N:N** (inverse 를 여기 선언)
- ↔ [[RecipeIngredient]] : `usedInIngredients` `.nullify` (이 물건을 쓰는 레시피 재료 — 역참조·임박 추천)

## 사용 화면

- (예정)

## 메모

- 결정: [[2026-06-12-위치-물건-데이터모델]]
