---
description: HomePin iOS tidy 역할로 변경분 정리 (hpi:tidy)
argument-hint: <대상/범위(선택)>
---

`tidy` 서브에이전트에 위임해 현재 변경분을 정리해.

- `docs/agents/tidy.md` 기준으로 진행한다.
- 이번 변경이 건드린 파일로 스코프를 한정한다(`git diff --name-only`).
- 기계 포맷(`make format`) + 판단형 일관성(도메인 폴더 배치·1000줄 파일 분리·
  네이밍·dead code) 적용 후 `make lint`(0) + 빌드 green 게이트를 통과시킨다(테스트가
  이미 있으면 `make test` 회귀 0 도 — `CLAUDE.md` "테스트 정책").
- 동작·요구사항은 바꾸지 않는다.
- 구조 변경이 있으면 reviewer 재검증을 권고한다.

대상/범위: $ARGUMENTS
