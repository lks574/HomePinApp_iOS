---
aliases: [Shopping, 장보기, 쇼핑리스트]
tags: [screen, screen/shopping]
created: 2026-06-16
updated: 2026-06-16
status: done
screen-id: screen-11
---

# Shopping (장보기 목록)

사야 할 물건 체크리스트. 수동 추가 + 레시피 부족분 추가 + 체크 시 재고 반영 + 삭제 CRUD.
[[Home]] 의 장보기 요약 섹션에서 push 로 진입한다.

## 역할

- 살 것을 수동으로 추가한다(상단 입력행 + "추가").
- [[RecipeDetail]] 의 부족 주재료 추가 액션으로 `ShoppingItem(sourceIngredient:)` 이 생성될 수 있다.
- 행 좌측 동그라미를 탭해 완료/미완료 토글한다(완료는 취소선 + 아래 "완료" 섹션으로).
- 미완료 항목을 완료 처리할 때 같은 이름의 기존 [[Item]] 이 있으면 수량을 증가시키고,
  없으면 [[ItemEditor]] 를 열어 위치를 선택한 뒤 신규 재고를 만든다.
- `sourceIngredient` 가 있으면 반영된 [[Item]] 을 연결해 레시피 부족 상태도 해소한다.
- 완료 항목을 다시 미완료로 돌릴 때는 재고를 자동 차감하지 않고 장보기 체크만 되돌린다.
- 행 우측 휴지통으로 삭제한다.
- 미완료("살 것")를 위에, 완료("완료")를 아래에 둔다.

## 연결된 화면

- 들어옴 ←: [[Home]] — 장보기 요약 섹션 탭(`navigationDestination(for: ShoppingDestination.self)`)
- 데이터 유입 ←: [[RecipeDetail]] — 부족 주재료를 장보기 항목으로 생성
- 이동 →: [[ItemEditor]] — 신규 재고 위치 선택/저장

## 사용 모델

- [[ShoppingItem]] — 읽기 `@Query(sort: \ShoppingItem.createdAt, order: .reverse)`,
  쓰기 `modelContext` insert(추가)/delete(삭제)/`isChecked` 토글(autosave).
- [[Item]] — 읽기 `@Query(sort: \Item.name)` 로 같은 이름 재고를 찾고, 있으면 수량 증가.
  없으면 [[ItemEditor]] 생성 저장 결과를 받아 `sourceIngredient.item` 에 연결.

## 상태 관리

- View ↔ SwiftData 직결. 단순 목록·체크·삭제·수동 추가라 별도 `@Observable` 모델 없음
  (직결 우선 원칙). 입력 필드 `newItemName`, 신규 재고 저장 route `stockRoute`, 포커스만
  `@State`/`@FocusState`.

## 관련 태스크 / 결정

- `[screen-11]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-16-장보기-데이터모델]]

## 메모

- 코드: `HomePinApp/Sources/Features/Shopping/ShoppingListView.swift`
- 체크 해제 시 재고 자동 차감은 하지 않는다. 이미 실제 재고를 건드린 뒤의 undo 는 별도
  재고 편집에서 처리하는 쪽이 데이터 손상이 적다.
