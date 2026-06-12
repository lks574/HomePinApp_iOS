---
aliases: [agents, codex, 에이전트 규칙]
tags: [doc/agent, rules]
created: 2026-06-12
updated: 2026-06-12
status: draft
---

# HomePin iOS 에이전트 규칙 (Codex 진입점)

이 프로젝트의 **단일 소스 오브 트루스는 `CLAUDE.md`**다. 프로젝트 규칙·아키텍처·
에이전트 역할·자동 진행 워크플로는 모두 `CLAUDE.md`에 정의되어 있고, 이 파일은
그 내용을 그대로 가져온 뒤 Codex 전용 사항만 덧붙인다.

@CLAUDE.md

## Codex 전용 보충

위 `CLAUDE.md` 규칙을 그대로 따르되, Codex 환경에서는 아래를 추가로 적용한다.

- **먼저 `CLAUDE.md` 전문을 읽는다.** 위 `@CLAUDE.md` 는 Claude Code 에서 자동
  전개되지만, Codex 는 이 import 를 자동 해석하지 않을 수 있으므로 작업 시작 시
  `CLAUDE.md` 파일을 직접 열어 그 규칙(기본 방향·아키텍처·자동 진행·문서 동기화)을
  적용한다.
- **역할 정의는 공유 문서를 읽는다.** `hpi:<role>` 별칭을 받으면 `docs/agents/<role>.md`를
  먼저 읽고 그 절차·출력 형식을 따른다. Codex 쪽 역할 래퍼는 `.codex/agents/<role>.toml`에
  있고, 본문은 같은 `docs/agents/<role>.md`를 가리킨다(내용 복사 금지 — 드리프트 방지).
- **`hpi:hunt`는 Claude Code 전용**이다. hunt 워크플로(`.claude/workflows/hunt-review.js`)는
  Claude Code의 `Workflow` 툴에 의존하므로 Codex에서는 실행할 수 없다. Codex에서 깊은
  리뷰가 필요하면 `reviewer`(`docs/agents/reviewer.md`)를 사용하거나 사용자에게
  Claude Code에서 `hpi:hunt`를 돌리도록 안내한다.
- 그 외 모든 규칙(커밋 형식, 한국어 문서, 검증 순서, 자동 진행 규약, 문서 동기화)은
  `CLAUDE.md`와 동일하다. 두 도구가 어긋나지 않도록, 규칙을 바꿀 때는 항상 `CLAUDE.md`를
  수정하고 이 파일은 Codex 전용 보충만 유지한다.
