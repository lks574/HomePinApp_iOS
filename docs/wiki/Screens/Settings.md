---
aliases: [Settings, 설정]
tags: [screen, screen/settings]
created: 2026-06-12
updated: 2026-06-15
status: stub
screen-id: screen-01
---

# Settings (설정)

앱 정보 위주의 설정 탭. 현재는 stub 으로, 버전·저장 방식·앱 소개만 보여준다.

## 역할

- 버전, 저장 방식(이 기기 / SwiftData), 앱 한 줄 소개를 정적으로 보여준다.
- 실제 설정 항목(데이터 관리·알림 등)은 아직 없다.

## 연결된 화면

- 들어옴 ←: 탭바 (5-슬롯 중 설정 탭)
- 이동 →: 없음

## 사용 모델

- 없음(정적 정보 stub).

## 상태 관리

- 상태 없음. 정적 `List`.

## 관련 태스크 / 결정

- `[screen-01]` (docs/screen-implementation-tasks.md)

## 메모

- 코드: `HomePinApp/Sources/Features/Settings/SettingsView.swift`
- 데이터 초기화/내보내기·알림 설정 등이 추가되면 모델·상태 섹션을 갱신.
