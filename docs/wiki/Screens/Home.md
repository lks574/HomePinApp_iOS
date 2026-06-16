---
aliases: [Home, 홈]
tags: [screen, screen/home]
created: 2026-06-12
updated: 2026-06-16
status: in-progress
screen-id: screen-01
---

# Home (홈)

스플래시 다음의 **홈 대시보드**. 검색 placeholder, 유통기한 임박 카드, 장보기 요약,
장소 바로가기, 최근 추가 물건을 보여준다.

## 역할

- 앱의 주 진입 화면.
- 임박 물건과 최근 추가 물건을 빠르게 확인한다.
- 최근 추가 행을 탭해 [[ItemEditor]] 로 편집한다.
- 장소 바로가기를 탭하면 장소 탭으로 전환하고 그 장소 상세로 이동한다.
- **장보기 요약 섹션**: 미완료 살 것 개수 + 상위 3개 미리보기. 탭하면 [[Shopping]]
  목록 화면으로 push(진입점+요약만, CRUD 는 목록 화면).

## 연결된 화면

- 들어옴 ←: [[Splash]] (`phase = .home`)
- 이동 →: [[ItemEditor]] — 최근 추가 물건 행 탭
- 이동 →: [[PlaceDetail]] — 장소 바로가기 탭(탭 전환). `AppRouter.openPlace(area)`
- 이동 →: [[Shopping]] — 장보기 요약 섹션 탭(`navigationDestination(for: ShoppingDestination.self)`)

## 사용 모델

- [[Area]] — 읽기 `@Query(sort: \Area.sortOrder)`, 장소 바로가기 표시·이동
- [[Item]] — 읽기 `@Query(sort: \Item.createdAt)`, 임박/최근 목록 표시
- [[ShoppingItem]] — 읽기 `@Query(sort: \ShoppingItem.createdAt)`, 미완료 요약·미리보기

## 상태 관리

- View ↔ SwiftData 직결.
- 에디터 presentation state 만 `@State` 로 보관.
- 탭 전환·장소 상세 이동은 `@Environment(AppRouter.self)` 로 받은 셸 라우터에 위임.

## 메모

- 코드: `HomePinApp/Sources/Features/Home/HomeView.swift`
