---
aliases: [ItemEditor, 물건 추가, 물건 편집]
tags: [screen, screen/item]
created: 2026-06-14
updated: 2026-06-15
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
- 들어옴 ←: [[PlaceDetail]] — 물건 행 탭, 장소/수납공간 추가 버튼
- 들어옴 ←: [[Capture]] — 텍스트 입력 후 확인 단계

## 사용 모델

- [[Item]] — 추가/편집 쓰기
- [[Area]] — 읽기 `@Query(sort: \Area.sortOrder)`, 선택
- [[Spot]] — 선택한 `Area` 의 세부위치 선택

## 상태 관리

- 얇은 `@Observable` 모델 **`ItemEditorModel`** 이 draft(7필드)와 `save(into:)`(create/edit
  분기·`normalizedName` 동기화·spot→area 불변식)를 소유한다. SwiftData 직결로
  충분하지 않은 다필드 draft + 다단계 쓰기 케이스.
- View 는 레이아웃과 순수 UI 상태(focus·picker 시트 표시)만 갖고 `@Bindable` 로
  모델에 바인딩한다. 저장 시에만 모델이 SwiftData 에 반영.
- 단일 필드 에디터([[PlaceEditor]]·[[SpotEditor]])는 직결을 유지한다(모델 없음).

## 관련 태스크 / 결정

- `[screen-02]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-위치-물건-데이터모델]] · [[2026-06-15-에디터-상태-소유-패턴]]

## 메모

- 코드: `HomePinApp/Sources/Features/Items/ItemEditorView.swift` (레이아웃),
  `ItemEditorModel.swift` (draft·저장)
- 선택 시트: `HomePinApp/Sources/Features/Items/ItemLocationPickerSheets.swift`
- 후속: 삭제, 카테고리, 태그, 사진, AI 파싱 결과 structured draft.
