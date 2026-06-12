---
description: HomePin iOS 변경 diff 다중 렌즈 병렬 리뷰 + 반증 검증 (hpi:hunt)
argument-hint: <선택: 커밋/레인지 (비우면 현재 미커밋 변경)>
---

`.claude/workflows/hunt-review.js` 워크플로를 `Workflow` 툴로 실행해서 변경을 다중 렌즈(버그·아키텍처 경계·effect·환경 분기·AI 실패 패턴)로 병렬 리뷰하고 각 finding 을 반증(refute) 검증해. `CLAUDE.md` 의 `hpi:hunt` 규약과 `docs/agents/hunt.md` 의 렌즈·출력 형식을 따른다.

- 대상 커밋/레인지가 주어지면 `args.target` 으로 전달하고, 비어 있으면 현재 미커밋 변경(HEAD 대비)을 리뷰한다.
- 워크플로가 끝나면 **confirmed finding 만** 심각도·렌즈·파일과 함께 보고하고, 반증으로 걸러진 항목 수도 알린다.
- 여러 렌즈가 같은 코드 경로에 합의한 finding 은 신뢰도가 높으니 우선 강조한다.

대상: $ARGUMENTS
