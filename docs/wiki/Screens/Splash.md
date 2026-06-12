---
aliases: [Splash, 스플래시]
tags: [screen, screen/app]
created: 2026-06-12
updated: 2026-06-12
status: in-progress
---

# Splash (스플래시)

앱 **최초 화면**이자 **분기지점**. 시작 동안 표시되고, 다음 단계를 정한다.

## 역할

- 앱 실행 직후 보여주는 정적 화면(로고 + ProgressView).
- 분기 로직 자체는 뷰가 아니라 `AppModel.start()` 가 담당한다(셸이 단계 결정).
- 지금은 잠깐 대기 후 홈으로. 추후 온보딩 여부·데이터 준비·마이그레이션 결과 등을
  여기서 판단해 분기.

## 연결된 화면

- 이동 →: [[Home]] (`AppModel.start()` 완료 후 `phase = .home`)

## 사용 모델

- 없음 (앱 셸 상태 `AppModel.Phase` 만 사용)

## 상태 관리

- 앱 셸 `AppModel`(`@MainActor @Observable`)의 `phase` 전환. `AppRootView` 가 소유.

## 메모

- 코드: `HomePinApp/Sources/Features/Splash/SplashView.swift`, `App/AppModel.swift`,
  `App/AppRootView.swift`
