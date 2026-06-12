---
aliases: [Home, 홈]
tags: [screen, screen/home]
created: 2026-06-12
updated: 2026-06-12
status: in-progress
---

# Home (홈)

스플래시 다음의 **메인 화면**. 현재는 공간(Space) 목록(임시) — 추후 홈 대시보드/검색
등으로 확장.

## 역할

- 앱의 주 진입 화면. 현재는 공간을 나열하고 추가/삭제.

## 연결된 화면

- 들어옴 ←: [[Splash]] (`phase = .home`)
- (예정) → 구역 목록 / 물건 상세 등

## 사용 모델

- [[Space]] — 읽기 `@Query(sort: \Space.sortOrder)`, 쓰기 `modelContext` 직결

## 상태 관리

- View ↔ SwiftData 직결(별도 모델 없음). 하위 화면·복잡 상태가 생기면 재검토.

## 메모

- 코드: `HomePinApp/Sources/Features/Home/HomeView.swift`
