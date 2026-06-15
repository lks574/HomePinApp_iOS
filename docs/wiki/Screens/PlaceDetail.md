---
aliases: [PlaceDetail, 장소 상세]
tags: [screen, screen/place]
created: 2026-06-12
updated: 2026-06-15
status: in-progress
screen-id: screen-01, screen-05
---

# PlaceDetail (장소 상세)

한 장소([[Area]]) 안을 수납공간([[Spot]])별로 펼쳐 보여주는 화면. 각 수납공간의 물건 목록과 수납공간 미지정 물건을 보여주고, 물건 추가/편집 에디터로 진입한다.

## 역할

- 선택한 [[Area]] 의 [[Spot]] 별 [[Item]] 목록을 카드로 보여준다.
- `Spot` 에 속하지 않은 직속 물건은 "수납공간 미지정" 카드로 묶는다.
- 물건 행/추가 버튼을 탭하면 [[ItemEditor]] 시트를 연다(`editorRoute` 로 라우팅).
- 헤더 ⋯ 메뉴로 장소 이름 수정([[PlaceEditor]] 편집) / 장소 삭제(확인 후 `dismiss`)를 한다.

## 연결된 화면

- 들어옴 ←: [[Places]] — 장소 카드 탭
- 이동 →: [[ItemEditor]] — 물건 행 탭(편집), 추가 버튼(생성). `.sheet(item:)`
- 이동 →: [[PlaceEditor]] — 헤더 메뉴 "장소 이름 수정"(편집)

## 사용 모델

- [[Area]] — 읽기(전달받은 `area`), 관계 경유로 `spots`·`items` 접근
- [[Spot]] — 읽기(수납공간별 그룹)
- [[Item]] — 읽기(목록), 편집은 [[ItemEditor]] 에 위임

## 상태 관리

- 직결(View ↔ SwiftData). 전달받은 `Area` 의 관계를 직접 읽고, 삭제는 `modelContext.delete` 후 `dismiss`.
- 비영속 UI 상태: 물건 에디터 `editorRoute`, 장소 에디터 `placeEditorRoute`, 삭제 확인 `showingDeleteConfirm`.

## 관련 태스크 / 결정

- `[screen-01]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-위치-물건-데이터모델]]

## 메모

- 코드: `HomePinApp/Sources/Features/Places/PlaceDetailView.swift`
- 검색바는 표시만, 실제 필터는 후속(`screen-04`).
