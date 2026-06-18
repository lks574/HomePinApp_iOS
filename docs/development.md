---
aliases: [development, 개발 워크플로]
tags: [doc/code, dev]
created: 2026-06-12
updated: 2026-06-18
status: draft
---

# 개발 워크플로

## 도구 체인

- **mise** — 도구 버전 관리. Tuist 등을 mise 로 설치한다.
- **Tuist** — Xcode 프로젝트 생성/관리. `Project.swift`(manifest)가 단일 소스이며,
  `.xcodeproj` 는 생성물이므로 손으로 편집하지 않는다.

## 빌드 / 검증

```bash
mise trust                    # 최초 1회, mise.toml 신뢰
tuist generate                # Project.swift -> HomePinApp.xcworkspace 생성 (.xcodeproj 는 생성물)
# iOS 빌드(시뮬레이터):
xcodebuild build \
  -workspace HomePinApp.xcworkspace -scheme HomePinApp \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

### 멀티플랫폼 빌드 (iOS / macOS 분리)

타깃별 스킴이 분리돼 있다 — `HomePinApp`(iOS) / `HomePinApp-macOS`(macOS). 데스티네이션
별로 해당 스킴을 골라 각 타깃만 빌드한다(한 스킴에 묶으면 macOS 빌드 시 iOS 타깃까지
끌려와 서명 오류가 난다 — `targetSchemesGrouping: .notGrouped`).

```bash
# iOS 디바이스 타깃 빌드:
xcodebuild -workspace HomePinApp.xcworkspace -scheme HomePinApp \
  -destination 'generic/platform=iOS' build
# macOS 네이티브 타깃 빌드(서명 자동, sandbox entitlements 적용):
xcodebuild -workspace HomePinApp.xcworkspace -scheme HomePinApp-macOS \
  -destination 'platform=macOS' build
```

- 스킴 목록 확인: `xcodebuild -workspace HomePinApp.xcworkspace -list`.
- 분리 빌드 검증: iOS·macOS 두 스킴 모두 `** BUILD SUCCEEDED **` 인지 각각 확인.
- CloudKit entitlement 가 켜진 macOS 타깃은 실행 가능한 서명 빌드에 Apple Development
  인증서가 필요하다. 서명 환경이 준비되지 않은 컴파일 검증은 아래처럼 수행한다.
  (단 **2026-06-18 현재 CloudKit entitlement 는 임시 제거** 상태 — App ID 미등록으로 인한
  실기기 서명 실패 회피. iOS device 빌드도 서명까지 green. 복구 시 다시 인증서 필요.
  `docs/follow-ups.md` "iCloud 동기화 / CloudKit".)

```bash
xcodebuild -workspace HomePinApp.xcworkspace -scheme HomePinApp-macOS \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

- `tuist generate` 산출물(`*.xcworkspace`/`*.xcodeproj`/`Derived/`)은 git 무시.
  매니페스트(`Project.swift`)만 추적한다.
- 검증 기본은 **빌드 green**(컴파일·동작 확인). 테스트는 후반 단계에서 작성한다
  (`CLAUDE.md` "테스트 정책"). 그 전까지 `make test` 를 게이트로 강제하지 않는다.

> [!note] 작성 예정
> Makefile(`make build`/`make format`/`make lint`)과 SwiftFormat/SwiftLint 설정이
> 정비되면 명령을 래핑해 여기에 추가한다.
