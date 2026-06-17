---
aliases: [ItemCategory, 카테고리]
tags: [model]
created: 2026-06-12
updated: 2026-06-17
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
- [[DataTransfer]] — 전체 백업 export/import 대상(2-pass id upsert). CSV 대량 입력은 Item·Recipe 와 위치/분류/태그 이름 조회→생성. 결정: [[2026-06-17-데이터-백업-번들포맷]]·[[2026-06-17-CSV-대량입력-스키마]].
