---
aliases: [Space, 공간]
tags: [model]
created: 2026-06-12
updated: 2026-06-12
status: in-progress
---

# Space (공간)

최상위 장소(집·별장·사무실 등). 위치 계층의 루트.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | 이름 중복은 앱 로직으로 검증 |
| `icon` | `String?` | SF Symbol/이모지 |
| `sortOrder` | `Int` | 수동 정렬 |
| `createdAt`/`updatedAt` | `Date` | |

## 관계

- → [[Area]] : `areas: [Area]` `@Relationship(.cascade)` (공간 삭제 시 구역까지 삭제)

## 사용 화면

- [[ContentView]] (임시 루트, 공간 목록)

## 메모

- 결정: [[2026-06-12-위치-물건-데이터모델]]
