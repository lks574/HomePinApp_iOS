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
tuist generate     # manifest -> .xcodeproj 생성
# 빌드는 생성된 프로젝트로 (Makefile 정비되면 make build 로 래핑 예정)
```

- 검증 기본은 **빌드 green**(컴파일·동작 확인). 테스트는 후반 단계에서 작성한다
  (`CLAUDE.md` "테스트 정책"). 그 전까지 `make test` 를 게이트로 강제하지 않는다.
- 포맷·lint(`make format`/`make lint`, SwiftFormat/SwiftLint)는 도구가 정비되면
  루트 설정을 우선 사용한다.

> [!note] 작성 예정
> Makefile/Tuist 타깃·스킴이 정비되면 정확한 명령(빌드/실행/생성)을 여기에 채운다.
