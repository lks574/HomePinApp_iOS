---
aliases: [Area, 구역]
tags: [model]
created: 2026-06-12
updated: 2026-06-15
status: in-progress
---

# Area (구역)

공간 안의 방/영역(주방·안방·주방펜트리·옷장 등). 물건의 **최소 위치 단위**.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | 한 공간 내 중복은 앱 로직 검증 |
| `icon` | `String?` | |
| `sortOrder` | `Int` | |
| `createdAt`/`updatedAt` | `Date` | |
| `itemCount` | computed | 직속 + 하위 Spot 물건 수 (← 전역 `areaItemCount` 대체) |

## 관계

- ← [[Space]] : `space: Space?` (부모)
- → [[Spot]] : `spots: [Spot]` `@Relationship(.cascade)`
- → [[Item]] : `items: [Item]` `@Relationship(.nullify)` — 세부위치 없는 물건. 구역
  삭제 시 물건은 보존("위치 미지정").

## 사용 화면

- [[Places]] — 그리드 목록·삭제
- [[PlaceDetail]] — 상세·편집/삭제
- [[PlaceEditor]] — 추가/편집 쓰기
- [[ItemEditor]] — 물건 위치(장소) 선택

## 메모

- 결정: [[2026-06-12-위치-물건-데이터모델]]
