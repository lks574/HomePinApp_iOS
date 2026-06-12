---
aliases: [hunt, branch-hunt, 다중 렌즈 리뷰]
tags: [doc/agent]
role: hunt
created: 2026-06-08
updated: 2026-06-11
status: stable
---

# Hunt Agent (Branch Hunt)

변경 diff 를 **여러 관점(렌즈)으로 병렬 리뷰**하고, 각 지적을 **반증 검증**으로
걸러 신뢰도 높은 finding 만 남기는 리뷰 워크플로다. 단일 패스 `reviewer` 를
대체하지 않고, 깊은 리뷰가 필요할 때 **보완**한다.

`Workflow` 툴 기반이라 Claude Code 전용이다 (스크립트: `.claude/workflows/hunt-review.js`).
Codex 카운터파트는 없다.

## 언제 쓰나

- HIGH 등급 변경(새 화면/flow, 데이터모델·persistence·권한·동기화, 네비게이션 구조
  변경, 여러 feature 교차)의 깊은 리뷰.
- 단일 `reviewer` 가 APPROVE 했지만 한 번 더 다관점으로 확인하고 싶을 때.
- 버그가 의심되지만 어디인지 불명확해 여러 각도로 동시에 훑고 싶을 때.

가벼운 변경(LOW/MEDIUM)은 단일 `reviewer` 로 충분하다. hunt 는 에이전트를 여러 개
띄우므로 비용이 크다 — 필요할 때만 쓴다.

## 동작

1. **Review (병렬)** — 5개 렌즈가 동시에 같은 diff 를 리뷰한다.
   - `bug` — 버그·회귀·엣지케이스
   - `arch` — 아키텍처 경계·navigation ownership (`CLAUDE.md` "아키텍처" 섹션 +
     `docs/architecture.md` 기준. 확정 전이면 명백한 경계 위반·중복 소유만)
   - `effect` — async effect·cancellation·dependency 주입
   - `env` — 오프라인·권한·빈/로딩/에러·동기화 등 환경 분기 누락
   - `failure` — AI 실패 5패턴 가드(`docs/agents/reviewer.md`)
2. **Verify (병렬)** — 각 finding 을 독립 에이전트가 코드를 다시 열어 **반증**
   시도한다. 근거가 약하거나 틀리면 기각(refuted), 명백히 실제 문제면 확정.
   기본값은 회의적(애매하면 기각).
3. **확정 finding 만 반환** — 반증으로 걸러진 수도 함께 보고한다.

## 대상 지정

- 인자 없음: 현재 작업트리의 미커밋 Swift 변경(`git diff HEAD`).
- 커밋/레인지 인자: 해당 ref 의 변경(`git show <ref>`). `args.target` 으로 전달.

## 결과 해석

- **여러 렌즈가 같은 코드 경로에 합의한 finding 은 신뢰도가 매우 높다.** 우선
  처리한다.
- 단일 렌즈만 짚고 반증을 통과한 finding 은 실제 문제일 수 있으나 맥락을 한 번 더
  확인한다.
- 반증 기각 수가 많으면 렌즈 프롬프트가 과도하게 광범위한지 점검한다.

## 출력 형식

```markdown
## Hunt 결과 (대상: <ref 또는 working-tree>)

- raw N → confirmed C / refuted R

### 합의 finding (여러 렌즈 일치, 우선)
- [SEVERITY] path - 제목 (렌즈: bug, env, ...)

### 단일 렌즈 confirmed
- [SEVERITY][lens] path - 제목

### 반증으로 걸러진 항목
- [lens] 제목

### 추천 다음 행동
- 수정이 필요하면 developer 위임 제안 (사용자 확인)
```

## 제약

- 읽기·분석 전용. 코드를 수정하지 않는다. 수정은 developer 역할로 위임한다.
- 확정되지 않은(반증된) finding 을 사용자에게 실제 문제처럼 보고하지 않는다.
