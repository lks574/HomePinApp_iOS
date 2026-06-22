---
aliases: [Item, 물건]
tags: [model]
created: 2026-06-12
updated: 2026-06-22
status: in-progress
---

# Item (물건)

핀하는 대상. 구역(Area)·세부위치(Spot)·분류(Category)는 모두 선택이다. 위치/카테고리
삭제 시 nullify 로 보존된다. **area=nil 캡처 허용(`screen-20`)**: 위치를 모르거나 나중에
정리하려는 물건은 `area == nil`("미정리함")으로 저장할 수 있다 — 스키마는 그대로(이미
옵셔널·합법)이고 "생성 시 area 강제" **앱 규칙만 완화**(`ItemEditorModel.canSave`)한 것이다.
신규 `@Model`·시스템 Area 를 만들지 않는다. area=nil 물건은 [[Capture]] 검색의
"위치미지정"(`wantsNoLocation`) 필터로 노출된다(기존 경로 재사용).

## 보유 데이터

| 프로퍼티 | 타입 | 비고 |
| --- | --- | --- |
| `id` | `UUID` | 앱 로직 유일성 |
| `name` | `String` | `#Index` |
| `normalizedName` | `String` | `#Index`, 매칭/검색 키(소문자·공백정리). `Item.normalize()` |
| `quantity` | `Int` | 기본 1 |
| `memo` | `String?` | |
| `expiresAt` | `Date?` | `#Index`, 유통/소비기한 |
| `createdAt`/`updatedAt` | `Date` | |
| `locationPath` | computed | "집 > 주방 > 냉동실" (영속화 안 함) |

## 관계

- → [[Area]] : `area: Area?` (선택 — nil 이면 "미정리함". nullify 보존도 옵셔널 사유)
- → [[Spot]] : `spot: Spot?` (선택)
- → [[ItemCategory]] : `category: ItemCategory?` (분류 1개)
- ↔ [[Tag]] : `tags: [Tag]?` **N:N** (inverse 를 여기 선언)
- ↔ [[RecipeIngredient]] : `usedInIngredients: [RecipeIngredient]?` `.nullify` (이 물건을 쓰는 레시피 재료 — 역참조·임박 추천)

## 사용 화면

- [[Home]] — 임박/최근 물건 표시, 임박 배너·최근 행 편집 진입.
- [[PlaceDetail]] — 장소별 물건 목록, 행 편집, "다 썼어요" 빠른 정리.
- [[ItemEditor]] — 추가/편집/삭제, 분류·태그 수동 편집.
- [[Capture]] — 검색 결과·AI 추가 저장 대상.
- [[RecipeDetail]]/[[Recipes]] — `RecipeIngredient.item` 연결을 통해 보유/부족 판정.

- [[DataTransfer]] — 전체 백업 export/import 대상(2-pass id upsert). CSV 대량 입력은 Item·Recipe 와 위치/분류/태그 이름 조회→생성. 결정: [[2026-06-17-데이터-백업-번들포맷]]·[[2026-06-17-CSV-대량입력-스키마]].
- App Intents (`AddItemIntent`, `screen-24`) — Siri / Shortcuts 에서 앱 없이 `Item` 하나를 직접 insert(UI 없음). 단건 캡처와 같은 파서·불변식 재사용. 결정: [[2026-06-22-App-Intents-물건추가-도입]].

## 메모

- 결정: [[2026-06-12-위치-물건-데이터모델]], [[2026-06-18-area-생략-캡처-허용-및-멀티-추가]], [[2026-06-22-유통기한-로컬알림-스케줄링]] (`expiresAt` 읽어 D-1·D-0 로컬 알림 예약 — 스키마 변경 없음, `Item.daysUntilExpiry`/`isExpiringSoon` 임박 단일 소스 재사용).
- 연속 입력(여러 개 추가, `screen-20`)으로 한 번에 여러 Item 을 insert 할 때도 단건과 같은 불변식(name→normalizedName 동기화, `spot?.area ?? area`)을 적용한다 — `ItemBulkAddModel.bulkInsert(into:existingItems:)`. 멀티 추가의 이름 중복은 차단 없는 경고가 기본이되, **기존 재고와 충돌하는 칩은 사용자가 합치기 토글로 기존 Item 수량에 가산**할 수 있다(새 Item 미생성, area/spot 은 기존 Item 유지, `updatedAt=.now`; 같은 `normalizedName` 기존 Item 여럿이면 최근 수정 대표 하나에만 가산). 자동 합치기·자동 저장은 아니다(명시적 "추가" + 토글). 유니크 제약 검토는 별도(`docs/follow-ups.md`).
