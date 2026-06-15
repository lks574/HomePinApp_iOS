---
aliases: [Spot, 세부위치]
tags: [model]
created: 2026-06-12
updated: 2026-06-15
status: in-progress
---

# Spot (세부위치)

구역 안의 구체적 수납처(냉동실·두번째 서랍·우측 하단 등). 위치 계층의 leaf.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | 한 구역 내 중복은 앱 로직 검증 |
| `sortOrder` | `Int` | |
| `createdAt`/`updatedAt` | `Date` | |

## 관계

- ← [[Area]] : `area: Area?` (부모)
- → [[Item]] : `items: [Item]` `@Relationship(.nullify)` — 세부위치 삭제 시 물건은
  보존(구역엔 남음).

## 사용 화면

- [[PlaceDetail]] — 세부위치별 물건 목록·추가/편집/삭제
- [[SpotEditor]] — 추가/편집 쓰기
- [[ItemEditor]] — 물건 세부위치 선택

## 메모

- 결정: [[2026-06-12-위치-물건-데이터모델]]
