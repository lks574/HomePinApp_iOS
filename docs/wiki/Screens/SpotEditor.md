---
aliases: [SpotEditor, 세부위치 추가, 세부위치 편집]
tags: [screen, screen/place]
created: 2026-06-15
updated: 2026-06-15
status: in-progress
screen-id: screen-06
---

# SpotEditor (세부위치 추가/편집)

세부위치([[Spot]])를 새로 추가하거나 기존 세부위치 이름을 편집하는 공용 에디터 시트.

## 역할

- 이름을 입력/수정한다(현재 편집 대상은 이름만).
- 추가 시 새 [[Spot]] 을 `modelContext.insert` 로 저장하고, `sortOrder` 는 대상 [[Area]] 의 기존 세부위치 개수, `area` 는 진입한 장소로 배정한다.
- 편집 시 기존 [[Spot]] 의 `name`·`updatedAt` 을 갱신한다.
- 삭제는 이 에디터가 아니라 [[PlaceDetail]] 세부위치 카드 메뉴에서 확인 다이얼로그로 처리한다.

## 연결된 화면

- 들어옴 ←: [[PlaceDetail]] — 헤더 ⋯ 메뉴 "세부위치 추가"(생성), 세부위치 카드 ⋯ 메뉴 "이름 수정"(편집)

## 사용 모델

- [[Spot]] — 추가/편집 쓰기
- [[Area]] — 생성 시 부모로 배정

## 상태 관리

- 저장 전 draft(이름)는 SwiftData 에 넣지 않고 `@State` 로 보관, 저장 시에만 직결.
- 별도 `@Observable` 모델은 두지 않는다(단일 필드 draft).

## 관련 태스크 / 결정

- `[screen-06]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-위치-물건-데이터모델]]

## 메모

- 코드: `HomePinApp/Sources/Features/Places/SpotEditorView.swift`
- 삭제 의미: [[Spot]] 삭제 시 [[Item]] 은 nullify 로 보존, 장소 직속("수납공간 미지정")으로 이동.
- 후속: 아이콘 등 추가 속성. [[PlaceEditor]] 와 거의 동형.
