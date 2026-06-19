---
aliases: [Firebase 도입, Analytics Crashlytics RemoteConfig, 앱 버전 게이트]
tags: [decision, decision/dependency, decision/privacy]
created: 2026-06-18
updated: 2026-06-18
status: accepted
---

# 2026-06-18 Firebase 도입 (Analytics·Crashlytics + RemoteConfig 버전 게이트)

> Firebase 를 두 번째 외부 의존성으로 도입한다. 목적은 (1) 간단한 분석 + 크래시 리포팅,
> (2) RemoteConfig 기반 앱 버전 게이트(최신/강제 업데이트 안내·차단)다. 이 단계는 **코드만
> 먼저** 들어가고 `GoogleService-Info.plist`(Firebase 계정 산출물)는 비커밋으로 로컬에서
> 주입한다.

## 맥락

서버 없이 기기 내부(SwiftData)에 저장하는 로컬 앱에 운영 가시성(크래시·간단 분석)과
출시 후 버전 강제/권장 업데이트 수단이 필요했다. AdMob(첫 외부 의존성)은 iOS 전용이라
iOS 타깃에만 링크했지만, Firebase 는 macOS 를 지원하므로 **iOS·macOS 두 타깃 모두**에
링크한다. Firebase 는 계정·`GoogleService-Info.plist`(앱별 시크릿성 설정)를 동반하는
되돌리기 어려운 외부 결정이라, 코드를 먼저 넣고 plist 는 사용자가 콘솔에서 받아 로컬에
주입하는 방식으로 분리했다.

## 결정

- **SDK = `firebase-ios-sdk` 12.15.0(2026 최신 안정) `.exact` 핀.** AdMob 과 동일하게
  재현성 우선으로 정확 버전 고정. 링크 product 는 **`FirebaseAnalytics`·
  `FirebaseCrashlytics`·`FirebaseRemoteConfig`** 셋만.
- **플랫폼 = iOS·macOS 두 타깃 모두 링크.** Firebase 가 macOS 를 지원하므로 AdMob 과
  달리 macOS `dependencies` 에도 `firebaseDependencies` 를 넣는다. 광고 SDK 는 여전히
  iOS 전용(AdMob 미지원). macOS 는 샌드박스라 `com.apple.security.network.client`
  entitlement 를 추가해야 Firebase 가 서버에 접속한다.
- **plist = 타깃별로 분리, 비커밋.** iOS(`com.sro.homepinappios`)와
  macOS(`com.sro.homepinappmac`)는 bundle id 가 달라 Firebase 앱도 둘이고 plist 도 둘이다.
  `Resources-iOS/**`·`Resources-macOS/**` glob 으로 포함하되, 실제
  `GoogleService-Info.plist` 는 `.gitignore`(이미 등재) 로 비커밋한다. 형식 안내용
  `GoogleService-Info.sample.plist` 만 커밋한다. **plist 가 없으면 빌드는 green** 이고
  런타임에 Firebase 구성을 skip 한다.
- **구성 가드 = `FirebaseBootstrap.configureIfAvailable()`.** 번들에
  `GoogleService-Info.plist` 가 있을 때만 `FirebaseApp.configure()` 한다(plist 없이
  configure 시 크래시). `HomePinAppApp.init()` 에서 가능한 한 이르게 1회 호출.
  미구성 시 Analytics·Crashlytics·RemoteConfig 가 모두 no-op — 앱 흐름 차단 없음.
- **분석 = 기본 자동 수집 + 소수 커스텀 이벤트.** 화면 전환·세션·`app_open` 등은 Analytics
  가 자동 수집한다. `AppAnalytics` 얇은 래퍼로 의미 있는 이벤트(`app_update_prompt`)만
  추가하고, Crashlytics `record(error:)`·`log(message:)` 진입점을 제공한다. 호출부는
  Firebase 타입을 보지 않는다(`#if canImport` 내부 격리).
- **버전 게이트 = `VersionGateService`(`@MainActor @Observable`).** RemoteConfig 키
  `latest_app_version`·`min_required_app_version`·`update_store_url` 를 fetch 해
  현재 버전(`CFBundleShortVersionString`)과 `.numeric` 비교한다. 상태는
  `forced`(현재 < 강제 하한) / `optional`(현재 < 최신) / `upToDate`. `AppRootView` 가
  소유·`.environment` 주입(AdService 와 동일 패턴), `AppModel.start()` 에서 광고 준비·
  스플래시와 병렬로 `check()` 한다. fetch 완료 핸들러는 nonisolated 로 올 수 있어
  `nonisolated static` 헬퍼 + `withCheckedContinuation` 으로 Sendable 값만 받아 메인
  액터로 hop 한다(시스템 콜백 격리 트랩 회피 — AdMob UMP 와 동일 패턴).
- **업데이트 UX = 강제는 차단, 선택은 1회 안내.** `forced` 면 `ForcedUpdateView` 가 앱
  전체를 덮는 닫을 수 없는 차단 화면(스토어 이동 버튼만). `optional` 이면 이번 실행에서
  한 번만 닫기 가능한 알럿(`Update`/`Later`). 설정 > About 에 업데이트 상태 행
  (`업데이트 가능` + 최신 버전 + App Store 버튼 / `최신 버전입니다`)을 둔다.
- **Crashlytics dSYM 업로드 = guarded post 스크립트.** SPM 체크아웃의 `run` 스크립트와
  번들 내 plist 가 둘 다 있을 때만 실행하고 없으면 skip(코드만 먼저 단계에서 빌드 green
  유지). `basedOnDependencyAnalysis: false` 로 매 빌드 실행.

## RemoteConfig 파라미터 (콘솔 설정)

버전 게이트가 읽는 키. 콘솔에 만들지 않거나 fetch 가 실패하면 게이트는 미적용(차단 없음).
비교는 `CFBundleShortVersionString` 과 `.numeric` 비교다(`1.10.0` > `1.9.0`).

| 키 | 타입 | 예시 | 의미 |
| --- | --- | --- | --- |
| `latest_app_version` | String | `1.2.0` | 현재 < 이 값 → **선택** 업데이트(닫기 가능한 1회 알럿) |
| `min_required_app_version` | String | `1.1.0` | 현재 < 이 값 → **강제** 업데이트(닫을 수 없는 차단 화면) |
| `update_store_url` | String | App Store 링크 | 업데이트 버튼이 여는 URL. 비우면 코드 기본값 사용 |

- 판정 우선순위: 강제(`min_required_app_version`) → 선택(`latest_app_version`) → 최신.
- iOS·macOS **공통 키**다. 플랫폼별로 다른 버전을 강제하려면 키 분리(`ios_*`/`macos_*`)를
  검토한다. 코드 키 정의는 `VersionGateService.Key`.

## 대안 / 폐기한 선택지

- **버전 범위 핀(`.upToNextMajor`)** — Firebase 권장 기본값이지만 프로젝트 관례(재현성
  우선 `.exact`)를 따라 정확 버전 고정. 정기 수동 갱신.
- **iOS 전용 링크(AdMob 선례 답습)** — Firebase 는 macOS 를 지원하므로 굳이 한쪽만 둘
  이유가 없다. 두 타깃 모두 링크해 macOS 도 크래시·분석·버전 게이트를 얻는다.
- **plist 를 커밋** — 앱별 시크릿성 설정이라 비커밋(`.gitignore`)으로 두고 샘플만 커밋.
- **강제 업데이트를 알럿으로** — 알럿은 단일 버튼으로도 닫혀 "차단"이 보장되지 않는다.
  전체 화면 오버레이(`ForcedUpdateView`)로 확실히 막는다.
- **MainActor 콜백 직접 캡처** — RemoteConfig `fetchAndActivate` 완료 핸들러가
  nonisolated 로 호출될 수 있어 `@MainActor` 타입 직접 캡처 시 격리 트랩 위험.
  `nonisolated static` 헬퍼로 우회(AdMob 과 동일).

## 영향

- 영향받는 화면: [[Splash]](시작 시 버전 check), 앱 셸([[RootTabView]]/[[Settings]] —
  강제 차단 오버레이·선택 알럿·설정 업데이트 행), 신규 `ForcedUpdateView`.
- 영향받는 모델: 없음(SwiftData `@Model` 변경 없음). `VersionGateService`·`AdService` 와
  마찬가지로 비영속 셸 서비스.
- 빌드: iOS·macOS 두 타깃 모두 green(plist 미주입 상태), Firebase 12.15.0 SPM 해석 성공,
  동시성 경고 0.
- 후속: ① Firebase 콘솔에서 iOS/macOS 앱 등록 후 각 `GoogleService-Info.plist` 주입,
  ② RemoteConfig 콘솔에 `latest_app_version`·`min_required_app_version`·
  `update_store_url` 파라미터 생성, ③ 출시 후 실제 App Store 링크로
  `update_store_url`·`defaultStoreURLString` 교체, ④ 실기기에서 강제/선택 게이트·
  크래시 리포팅·dSYM 업로드 동작 검증.
