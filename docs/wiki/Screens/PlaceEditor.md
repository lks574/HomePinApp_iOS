---
aliases: [PlaceEditor, 장소 추가, 장소 편집]
tags: [screen, screen/place]
created: 2026-06-15
updated: 2026-06-15
status: in-progress
screen-id: screen-05
---

# PlaceEditor (장소 추가/편집)

장소([[Area]])를 새로 추가하거나 기존 장소 이름을 편집하는 공용 에디터 시트.

## 역할

- 이름을 입력/수정한다(현재 편집 대상은 이름만).
- 추가 시 새 [[Area]] 를 `modelContext.insert` 로 저장하고, `sortOrder` 는 기존 개수, `space` 는 첫 [[Space]] 로 자동 배정한다.
- 편집 시 기존 [[Area]] 의 `name`·`updatedAt` 을 갱신한다.
- 삭제는 이 에디터가 아니라 [[Places]] 카드 컨텍스트 메뉴·[[PlaceDetail]] 헤더 메뉴에서 확인 다이얼로그로 처리한다.

## 연결된 화면

- 들어옴 ←: [[Places]] — "장소 추가" 버튼(생성), 카드 컨텍스트 메뉴 "이름 수정"(편집)
- 들어옴 ←: [[PlaceDetail]] — 헤더 메뉴 "장소 이름 수정"(편집)

## 사용 모델

- [[Area]] — 추가/편집 쓰기
- [[Space]] — 읽기, 생성 시 첫 공간 자동 배정

## 상태 관리

- 저장 전 draft(이름)는 SwiftData 에 넣지 않고 `@State` 로 보관, 저장 시에만 직결.
- 별도 `@Observable` 모델은 두지 않는다(단일 필드 draft).

## 관련 태스크 / 결정

- `[screen-05]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-위치-물건-데이터모델]]

## 메모

- 코드: `HomePinApp/Sources/Features/Places/PlaceEditorView.swift`
- 삭제 의미: [[Area]] 삭제 시 [[Spot]] 은 cascade 삭제, 직속·하위 [[Item]] 은 nullify 로 보존(위치만 해제).
- 후속: 아이콘 선택, 다중 [[Space]] 시 공간 선택.
