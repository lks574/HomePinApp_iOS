---
aliases: [development, 개발 워크플로]
tags: [doc/code, dev]
created: 2026-06-12
updated: 2026-06-12
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
# 생성된 워크스페이스로 빌드:
xcodebuild build \
  -workspace HomePinApp.xcworkspace -scheme HomePinApp \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

- `tuist generate` 산출물(`*.xcworkspace`/`*.xcodeproj`/`Derived/`)은 git 무시.
  매니페스트(`Project.swift`)만 추적한다.
- 검증 기본은 **빌드 green**(컴파일·동작 확인). 테스트는 후반 단계에서 작성한다
  (`CLAUDE.md` "테스트 정책"). 그 전까지 `make test` 를 게이트로 강제하지 않는다.

> [!note] 작성 예정
> Makefile(`make build`/`make format`/`make lint`)과 SwiftFormat/SwiftLint 설정이
> 정비되면 명령을 래핑해 여기에 추가한다.
