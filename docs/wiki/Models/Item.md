---
aliases: [Item, 물건]
tags: [model]
created: 2026-06-12
updated: 2026-06-17
status: in-progress
---

# Item (물건)

핀하는 대상. 최소한 구역에 속하고(앱 규칙), 세부위치는 선택. 위치/카테고리 삭제 시
nullify 로 보존된다.

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | 앱 로직 유일성 |
| `name` | `String` | `#Index` |
| `normalizedName` | `String` | `#Index`, 매칭/검색 키(소문자·공백정리). `Item.normalize()` |
| `quantity` | `Int` | 기본 1 |
| `photoData` | `Data?` | `@Attribute(.externalStorage)` |
| `memo` | `String?` | |
| `expiresAt` | `Date?` | `#Index`, 유통/소비기한 |
| `createdAt`/`updatedAt` | `Date` | |
| `locationPath` | computed | "집 > 주방 > 냉동실" (영속화 안 함) |

## 관계

- → [[Area]] : `area: Area?` (앱규칙 필수, nullify 보존 위해 옵셔널)
- → [[Spot]] : `spot: Spot?` (선택)
- → [[ItemCategory]] : `category: ItemCategory?` (분류 1개)
- ↔ [[Tag]] : `tags: [Tag]?` **N:N** (inverse 를 여기 선언)
- ↔ [[RecipeIngredient]] : `usedInIngredients: [RecipeIngredient]?` `.nullify` (이 물건을 쓰는 레시피 재료 — 역참조·임박 추천)

## 사용 화면

- [[Home]] — 임박/최근 물건 표시, 임박 배너·최근 행 편집 진입.
- [[PlaceDetail]] — 장소별 물건 목록, 행 편집, "다 썼어요" 빠른 정리.
- [[ItemEditor]] — 추가/편집/삭제, 사진·분류·태그 수동 편집.
- [[Capture]] — 검색 결과·AI 추가 저장 대상.
- [[RecipeDetail]]/[[Recipes]] — `RecipeIngredient.item` 연결을 통해 보유/부족 판정.

- [[DataTransfer]] — 전체 백업 export/import 대상(2-pass id upsert). CSV 대량 입력은 Item·Recipe 와 위치/분류/태그 이름 조회→생성. 결정: [[2026-06-17-데이터-백업-번들포맷]]·[[2026-06-17-CSV-대량입력-스키마]].

## 메모

- 결정: [[2026-06-12-위치-물건-데이터모델]]
