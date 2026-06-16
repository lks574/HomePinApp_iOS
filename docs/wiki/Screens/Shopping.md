---
aliases: [Shopping, 장보기, 쇼핑리스트]
tags: [screen, screen/shopping]
created: 2026-06-16
updated: 2026-06-16
status: in-progress
screen-id: screen-11
---

# Shopping (장보기 목록)

사야 할 물건 체크리스트. 수동 추가 + 레시피 부족분 추가 + 체크(완료 토글) + 삭제 CRUD.
[[Home]] 의 장보기 요약 섹션에서 push 로 진입한다.

## 역할

- 살 것을 수동으로 추가한다(상단 입력행 + "추가").
- [[RecipeDetail]] 의 부족 주재료 추가 액션으로 `ShoppingItem(sourceIngredient:)` 이 생성될 수 있다.
- 행 좌측 동그라미를 탭해 완료/미완료 토글한다(완료는 취소선 + 아래 "완료" 섹션으로).
- 행 우측 휴지통으로 삭제한다.
- 미완료("살 것")를 위에, 완료("완료")를 아래에 둔다.

## 연결된 화면

- 들어옴 ←: [[Home]] — 장보기 요약 섹션 탭(`navigationDestination(for: ShoppingDestination.self)`)
- 데이터 유입 ←: [[RecipeDetail]] — 부족 주재료를 장보기 항목으로 생성

## 사용 모델

- [[ShoppingItem]] — 읽기 `@Query(sort: \ShoppingItem.createdAt, order: .reverse)`,
  쓰기 `modelContext` insert(추가)/delete(삭제)/`isChecked` 토글(autosave).

## 상태 관리

- View ↔ SwiftData 직결. 단순 목록·체크·삭제·수동 추가라 별도 `@Observable` 모델 없음
  (직결 우선 원칙). 입력 필드 `newItemName`·포커스만 `@State`/`@FocusState`.

## 관련 태스크 / 결정

- `[screen-11]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-16-장보기-데이터모델]]

## 메모

- 코드: `HomePinApp/Sources/Features/Shopping/ShoppingListView.swift`
- 후속: 완료 → 재고 반영.
