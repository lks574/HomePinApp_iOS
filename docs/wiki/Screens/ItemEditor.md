---
aliases: [ItemEditor, 물건 추가, 물건 편집]
tags: [screen, screen/item]
created: 2026-06-14
updated: 2026-06-14
status: in-progress
screen-id: screen-02
---

# ItemEditor (물건 추가/편집)

물건을 새로 추가하거나 기존 물건의 기본 정보를 편집하는 공용 에디터 시트.

## 역할

- 이름, 수량, 장소(`Area`), 세부위치(`Spot`), 유통기한, 메모를 입력/수정한다.
- 추가 시 새 [[Item]] 을 `modelContext.insert` 로 저장한다.
- 편집 시 기존 [[Item]] 을 직접 갱신하고, `name` 변경 시 `normalizedName` 도 함께 갱신한다.
- `Spot` 을 선택하면 `Area` 를 `spot.area` 로 맞춰 위치 불변식을 유지한다.

## 연결된 화면

- 들어옴 ←: [[Home]] — 최근 추가 물건 행 탭
- 들어옴 ←: PlaceDetail — 물건 행 탭, 장소/수납공간 추가 버튼
- 들어옴 ←: Capture — 텍스트 입력 후 확인 단계

## 사용 모델

- [[Item]] — 추가/편집 쓰기
- [[Area]] — 읽기 `@Query(sort: \Area.sortOrder)`, 선택
- [[Spot]] — 선택한 `Area` 의 세부위치 선택

## 상태 관리

- 저장 전 draft 는 SwiftData 에 넣지 않고 `@State` 로 보관한다.
- 저장 시에만 View ↔ SwiftData 직결로 insert 또는 모델 프로퍼티 갱신.
- 별도 `@Observable` 모델은 두지 않는다. 현재 범위는 단일 화면 draft 로 충분하다.

## 관련 태스크 / 결정

- `[screen-02]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-위치-물건-데이터모델]]

## 메모

- 코드: `HomePinApp/Sources/Features/Items/ItemEditorView.swift`
- 선택 시트: `HomePinApp/Sources/Features/Items/ItemLocationPickerSheets.swift`
- 후속: 삭제, 카테고리, 태그, 사진, AI 파싱 결과 structured draft.
