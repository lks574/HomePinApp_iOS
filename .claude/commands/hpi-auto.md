---
description: HomePin iOS triage→planner→developer⇄reviewer 자동 진행 (hpi:auto)
argument-hint: <요청 내용>
---

`CLAUDE.md`의 "자동 진행 명령" 규약(Triage 루브릭·수렴 루프 포함)을 따라 진행해.

## 0) Triage (인라인, 서브에이전트 미사용)
요청을 LOW/MEDIUM/HIGH로 분류한다 (루브릭은 CLAUDE.md "자동 진행 명령" 참고).
- 애매하면 한 단계 위 등급으로 올린다(보수적 기본값).
- `라우팅: <등급> (근거: ...)` 한 줄을 남긴다.

## 0.5) Recall (MEDIUM/HIGH)
MEDIUM·HIGH 면 `recall` 서브에이전트로 관련 과거 맥락(이미 내린 결정·폐기한 접근·
미결 항목)을 회수한다. 요약 digest 만 받아 이후 planner·developer 위임 프롬프트에
함께 전달한다 (원문은 끌어오지 않음). LOW 는 생략한다.

## 1) 특이점 체크
CLAUDE.md 특이점 체크리스트에 하나라도 해당하면 즉시 멈추고 사용자에게 질문한다.
recall 이 "따라야 할 결정" 과 충돌하는 요청을 드러내면 특이점으로 보고 멈춘다.

## 2) 등급별 실행
- LOW    : planner 생략 → 3)로
- MEDIUM : planner 서브에이전트(경량, recall digest 전달) → 결과 확인 → 특이점
           재점검 → 3)로
- HIGH   : planner 서브에이전트(풀, recall digest 전달) → 결과 확인 → 특이점 재점검
           (되돌리기 어려운 결정이면 Decision 노트 후보로 표시) → 3)로

## 3) 구현
developer 서브에이전트 위임 → 결과 확인 → 특이점 재점검.
- developer가 BLOCKED를 보고하면 정지하고 planner 재호출을 제안한다.

## 4) 수렴 루프 (Maker-Checker, 최대 fix 2회)
reviewer 서브에이전트 위임 → 판정 확인.
- APPROVE         : 루프 종료 → 5)로
- REJECT          : 자동 수정 금지, 정지·사용자 에스컬레이션
- REQUEST_CHANGES :
    - fix 횟수 < 2 → developer에게 "reviewer가 짚은 findings만 스코프 한정 수정,
                     새 기능·리팩터 금지" 위임 → reviewer 재리뷰(지적 해소·회귀
                     여부만 확인) → 본 단계 반복
    - fix 횟수 = 2 → 정지, 남은 findings·판정 이력 요약·사용자 에스컬레이션

## 5) 정리 (tidy)
reviewer APPROVE 직후 tidy 서브에이전트 위임 → 변경 파일에 기계 포맷 + 판단형
일관성(도메인 폴더 배치·1000줄 파일 분리·네이밍·dead code) 적용 → `make lint`(0) +
빌드 green 게이트 확인(테스트가 있으면 `make test` 회귀 0 도 — CLAUDE.md "테스트 정책").
- 변경 성격이 MECHANICAL_ONLY → 6)로
- STRUCTURAL(파일 이동/분리·시그니처 변경) → 4) 수렴 루프로 1회 재진입(reviewer
  재검증). 단 tidy 재진입은 1회만(무한 루프 방지) — 재검증 후엔 6)로.

## 6) 요약
라우팅 등급, 검증/리뷰 결과, 변경 파일, fix 반복 횟수, tidy 변경 성격, 다음 추천
행동을 짧게 요약한다.

각 단계 핵심 결과만 남기고 이어가. 일반 역할 전환 확인은 생략(사용자가 hpi:auto로 명시).

요청: $ARGUMENTS
