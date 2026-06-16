---
aliases: [PlaceDetail, 장소 상세]
tags: [screen, screen/place]
created: 2026-06-12
updated: 2026-06-16
status: in-progress
screen-id: screen-01, screen-05, screen-06
---

# PlaceDetail (장소 상세)

한 장소([[Area]]) 안을 수납공간([[Spot]])별로 펼쳐 보여주는 화면. 각 수납공간의 물건 목록과 수납공간 미지정 물건을 보여주고, 물건 추가/편집 에디터로 진입한다.

## 역할

- 선택한 [[Area]] 의 [[Spot]] 별 [[Item]] 목록을 카드로 보여준다.
- `Spot` 에 속하지 않은 직속 물건은 "수납공간 미지정" 카드로 묶는다.
- 물건 행/추가 버튼을 탭하면 [[ItemEditor]] 시트를 연다(`editorRoute` 로 라우팅).
- 헤더 ⋯ 메뉴로 장소 이름 수정([[PlaceEditor]] 편집) / 장소 삭제(확인 후 `dismiss`)를 한다.
- 헤더 ⋯ 메뉴 "세부위치 추가" 와 세부위치 카드 ⋯ 메뉴(이름 수정/삭제)로 [[Spot]] 을 관리한다([[SpotEditor]]).

## 연결된 화면

- 들어옴 ←: [[Places]] — 장소 카드 탭
- 들어옴 ←: [[Home]] — 장소 바로가기(탭 전환, `AppRouter.openPlace`)
- 이동 →: [[ItemEditor]] — 물건 행 탭(편집), 추가 버튼(생성). `.sheet(item:)`
- 이동 →: [[PlaceEditor]] — 헤더 메뉴 "장소 이름 수정"(편집)
- 이동 →: [[SpotEditor]] — 헤더 메뉴 "세부위치 추가"(생성), 카드 메뉴 "이름 수정"(편집)

## 사용 모델

- [[Area]] — 읽기(전달받은 `area`: 이름·헤더). 진입은 [[Places]] navigationDestination 또는 [[Home]] 바로가기
- [[Spot]] — 읽기 `@Query`(area id 필터, 추가 즉시 반영)
- [[Item]] — 읽기 `@Query`(area id 필터), 편집은 [[ItemEditor]] 에 위임

## 상태 관리

- 직결(View ↔ SwiftData). `spots`·`items` 는 `@Query`(area id 필터)로 관찰해 추가/편집/삭제가 즉시 반영된다(관계 배열 직접 읽기는 insert 직후 미반영 이슈가 있어 전환). 장소/세부위치 삭제는 `modelContext.delete`.
- 비영속 UI 상태: 물건 에디터 `editorRoute`, 장소 에디터 `placeEditorRoute`, 세부위치 에디터 `spotEditorRoute`, 장소 삭제 `showingDeleteConfirm`, 세부위치 삭제 대상 `pendingSpotDelete`.

## 관련 태스크 / 결정

- `[screen-01]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-위치-물건-데이터모델]]

## 메모

- 코드: `HomePinApp/Sources/Features/Places/PlaceDetailView.swift`
- 장소 상세 상단의 표시용 검색바는 제거했다. 실제 검색은 중앙 AI 검색 시트로 일원화한다.
