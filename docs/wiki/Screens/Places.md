---
aliases: [Places, 장소 목록]
tags: [screen, screen/place]
created: 2026-06-12
updated: 2026-06-16
status: in-progress
screen-id: screen-01, screen-05
---

# Places (장소 목록)

집 안의 장소([[Area]])를 2열 그리드로 보여주는 탭 화면. 장소별 물건 개수·미리보기를 보여주고, 탭하면 상세로 이동한다.

## 역할

- 모든 [[Area]] 를 `sortOrder` 순 2열 그리드로 나열한다.
- 상단에 전체 장소 수와 총 보관 물건 수를 요약한다.
- 장소 카드를 탭하면 `navigationDestination` 으로 [[PlaceDetail]] 로 이동한다.
- "장소 추가" 버튼으로 [[PlaceEditor]] 생성 시트를 연다.
- 카드 long-press 컨텍스트 메뉴로 이름 수정([[PlaceEditor]] 편집) / 삭제(확인 다이얼로그)를 한다.

## 연결된 화면

- 들어옴 ←: 탭바 (5-슬롯 중 장소 탭)
- 이동 →: [[PlaceDetail]] — 장소 카드 탭 (`NavigationLink(value: area)`)
- 이동 →: [[PlaceEditor]] — 추가 버튼(생성), 카드 컨텍스트 메뉴 "이름 수정"(편집)

## 사용 모델

- [[Area]] — 읽기 `@Query(sort: \Area.sortOrder)`
- [[Space]] — 읽기 `@Query`
- [[Item]] — 카드 미리보기·개수 집계(파생, `Area` 관계 경유)

## 상태 관리

- 직결(View ↔ SwiftData). `@Query` 로 관찰, 삭제는 `modelContext.delete`.
- 비영속 UI 상태: 에디터 라우팅 `editorRoute`, 삭제 확인 대상 `pendingDelete`.

## 관련 태스크 / 결정

- `[screen-01]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-위치-물건-데이터모델]] · [[2026-06-12-네비게이션-UI구조]]

## 메모

- 코드: `HomePinApp/Sources/Features/Places/PlacesListView.swift`
- 장소 목록에는 별도 검색바를 두지 않는다. 전역 검색은 중앙 AI 검색 시트가 맡는다.
