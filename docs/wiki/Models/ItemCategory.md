---
aliases: [ItemCategory, 카테고리]
tags: [model]
created: 2026-06-12
updated: 2026-06-12
status: in-progress
---

# ItemCategory (카테고리)

물건 분류(주방용품·의류·공구 등). 물건과 1:N. 카테고리 삭제 시 물건은 미분류로 보존.

> 이름은 `Category`(Darwin 시스템 타입과 충돌)를 피해 **`ItemCategory`**.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | 중복은 앱 로직 검증 |
| `icon` | `String?` | |
| `sortOrder` | `Int` | |
| `createdAt`/`updatedAt` | `Date` | |

## 관계

- → [[Item]] : `items: [Item]` `@Relationship(.nullify, inverse: \Item.category)`

## 메모

- 결정: [[2026-06-12-위치-물건-데이터모델]]
