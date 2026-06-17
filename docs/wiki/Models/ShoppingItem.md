---
aliases: [ShoppingItem, 장보기 항목]
tags: [model]
created: 2026-06-16
updated: 2026-06-17
status: done
---

# ShoppingItem (장보기 항목)

사야 할 물건 한 줄. 재고([[Item]])와 독립된 가벼운 체크리스트 엔티티. 수동 추가/체크
(완료)/삭제와 레시피 부족분 추가를 다룬다(홈 장보기 섹션 + [[Shopping]] 목록 화면).
완료 체크 시 기존 재고 수량 증가 또는 신규 재고 생성으로 반영된다.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | 살 것 이름(사용자 입력, 현지화 비대상) |
| `normalizedName` | `String` | 매칭/검색용 정규화 키(`Item.normalize` 재사용) |
| `quantity` | `Int?` | 살 수량(옵셔널 — 나중에 정함) |
| `isChecked` | `Bool` | 구매 완료 체크 |
| `stockCredited` | `Bool` | 한 번이라도 재고에 가산됐는지(기본 `false`). 재체크 시 이중 가산 방지용 |
| `createdAt` | `Date` | 정렬 기준(최신순) |

## 관계

- → [[RecipeIngredient]] : `sourceIngredient` (`.nullify`, 레시피 부족분에서 생성된 항목의 원본 재료)

## 사용 화면

- [[Home]] : 장보기 요약 섹션(미완료 개수 + 상위 3개 미리보기 + 진입점)
- [[Shopping]] : 전체 목록 CRUD(추가/체크/삭제)
- [[RecipeDetail]] : 부족 주재료를 `ShoppingItem(sourceIngredient:)` 으로 생성

## 동작

- 미완료 항목 완료 처리: 같은 `normalizedName` 의 [[Item]] 이 있으면 `quantity` 를 증가.
- 같은 이름 재고가 없으면 [[ItemEditor]] 로 신규 [[Item]] 을 만들고 저장 후 완료 처리.
- `sourceIngredient` 가 있으면 반영된 [[Item]] 을 `RecipeIngredient.item` 에 연결한다.
- 완료 항목을 미완료로 되돌릴 때는 재고 수량을 자동 차감하지 않는다(의도된 비대칭).
- 재고에 가산되면 `stockCredited` 를 `true` 로 둔다. 미완료→완료→미완료→재완료 시
  이 플래그로 재가산을 막아 수량 이중 가산을 방지한다.

- [[DataTransfer]] — 전체 백업 export/import 대상(2-pass id upsert). CSV 대량 입력은 Item·Recipe 와 위치/분류/태그 이름 조회→생성. 결정: [[2026-06-17-데이터-백업-번들포맷]]·[[2026-06-17-CSV-대량입력-스키마]].

## 메모

- 코드: `HomePinApp/Sources/Models/ShoppingItem.swift`
- 스키마 등록: `HomePinApp/Sources/Persistence/AppModelContainer.swift`
- 결정: [[2026-06-16-장보기-데이터모델]]
