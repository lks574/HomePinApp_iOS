---
aliases: [Places, 장소 목록]
tags: [screen, screen/place]
created: 2026-06-12
updated: 2026-06-15
status: in-progress
screen-id: screen-01
---

# Places (장소 목록)

집 안의 장소([[Area]])를 2열 그리드로 보여주는 탭 화면. 장소별 물건 개수·미리보기를 보여주고, 탭하면 상세로 이동한다.

## 역할

- 모든 [[Area]] 를 `sortOrder` 순 2열 그리드로 나열한다.
- 상단에 전체 장소 수와 총 보관 물건 수를 요약한다.
- 장소 카드를 탭하면 `navigationDestination` 으로 [[PlaceDetail]] 로 이동한다.

## 연결된 화면

- 들어옴 ←: 탭바 (5-슬롯 중 장소 탭)
- 이동 →: [[PlaceDetail]] — 장소 카드 탭 (`NavigationLink(value: area)`)

## 사용 모델

- [[Area]] — 읽기 `@Query(sort: \Area.sortOrder)`
- [[Space]] — 읽기 `@Query`
- [[Item]] — 카드 미리보기·개수 집계(파생, `Area` 관계 경유)

## 상태 관리

- 직결(View ↔ SwiftData). `@Query` 로 관찰만 하고 별도 모델은 두지 않는다.

## 관련 태스크 / 결정

- `[screen-01]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-위치-물건-데이터모델]] · [[2026-06-12-네비게이션-UI구조]]

## 메모

- 코드: `HomePinApp/Sources/Features/Places/PlacesListView.swift`
- 검색바·실제 필터는 후속(`screen-04`).
