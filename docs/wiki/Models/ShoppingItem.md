---
aliases: [ShoppingItem, 장보기 항목]
tags: [model]
created: 2026-06-16
updated: 2026-06-16
status: in-progress
---

# ShoppingItem (장보기 항목)

사야 할 물건 한 줄. 재고([[Item]])와 독립된 가벼운 체크리스트 엔티티. 수동 추가/체크
(완료)/삭제와 레시피 부족분 추가를 다룬다(홈 장보기 섹션 + [[Shopping]] 목록 화면).
재고 반영은 후속.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | 살 것 이름(사용자 입력, 현지화 비대상) |
| `normalizedName` | `String` | 매칭/검색용 정규화 키(`Item.normalize` 재사용) |
| `quantity` | `Int?` | 살 수량(옵셔널 — 나중에 정함) |
| `isChecked` | `Bool` | 구매 완료 체크 |
| `createdAt` | `Date` | 정렬 기준(최신순) |

## 관계

- → [[RecipeIngredient]] : `sourceIngredient` (`.nullify`, 레시피 부족분에서 생성된 항목의 원본 재료)

## 사용 화면

- [[Home]] : 장보기 요약 섹션(미완료 개수 + 상위 3개 미리보기 + 진입점)
- [[Shopping]] : 전체 목록 CRUD(추가/체크/삭제)
- [[RecipeDetail]] : 부족 주재료를 `ShoppingItem(sourceIngredient:)` 으로 생성

## 메모

- 코드: `HomePinApp/Sources/Models/ShoppingItem.swift`
- 스키마 등록: `HomePinApp/Sources/Persistence/AppModelContainer.swift`
- 결정: [[2026-06-16-장보기-데이터모델]]
