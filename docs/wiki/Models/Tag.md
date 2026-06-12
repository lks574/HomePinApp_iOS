---
aliases: [Tag, 태그]
tags: [model]
created: 2026-06-12
updated: 2026-06-12
status: in-progress
---

# Tag (태그)

자유 라벨. 물건·레시피와 N:N(다대다)로 **공유**. 재사용·이름변경·자동완성 용도.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | 중복은 앱 로직 검증 |
| `createdAt`/`updatedAt` | `Date` | |

## 관계

- ↔ [[Item]] : `items: [Item]` (N:N, inverse 는 `Item.tags` 에 선언)
- ↔ [[Recipe]] : `recipes: [Recipe]` (N:N, inverse 는 `Recipe.tags` 에 선언)

## 메모

- 결정: [[2026-06-12-위치-물건-데이터모델]]
