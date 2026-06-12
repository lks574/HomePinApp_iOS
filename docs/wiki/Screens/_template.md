---
aliases: [ScreenName, 화면 한글명]
tags: [screen, screen/<도메인>]
created: 2026-06-12
updated: 2026-06-12
status: planned
screen-id: screen-XX
---

# ScreenName (화면 한글명)

> 이 파일은 템플릿이다. 복사해서 `Screens/<ScreenName>.md` 로 새 노트를 만든다.
> `_` 로 시작하는 파일은 실제 화면이 아니다.

## 역할

이 화면이 사용자에게 무엇을 하게 하는지 1~3문장. (무슨 데이터를 보여주고, 어떤
행동을 받는지.)

## 연결된 화면

이 화면에서 이동하거나, 이 화면으로 들어오는 화면. 양방향으로 표기한다.

- 이동 →: [[다른화면]] — 어떤 동작으로 가는지
- 들어옴 ←: [[진입화면]] — 어디서 오는지

## 사용 모델

이 화면이 읽거나 쓰는 SwiftData `@Model`.

- [[ModelName]] — 읽기(`@Query`) / 쓰기(`modelContext`) 중 무엇인지

## 상태 관리

- 직결(View↔SwiftData)인지, 얇은 `@Observable` 모델을 쓰는지. 모델을 쓴다면 왜
  (비영속 UI 상태 / 다단계 쓰기).

## 관련 태스크 / 결정

- `[screen-XX]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[Decision/...]]

## 메모

- 자유 메모.
