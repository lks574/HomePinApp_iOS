---
aliases: [agents, claude, 에이전트 규칙]
tags: [doc/agent, rules]
created: 2026-06-12
updated: 2026-06-12
status: draft
---

# HomePin iOS 에이전트 규칙

이 파일은 Claude Code와 Codex가 공유하는 **단일 소스 오브 트루스**다. Claude Code는
이 `CLAUDE.md`를 직접 읽고, Codex는 `AGENTS.md`(이 파일을 `@CLAUDE.md`로 import)를
읽는다. 규칙·역할·워크플로는 여기에서 한 번만 정의한다.

이 프로젝트는 iOS 앱이다. 단순하고 명시적인 구조를 우선한다.

## 플랫폼 / 기술 스택

확정된 기반 스택은 아래와 같다. 이 위에서 아키텍처(상태 관리·네비게이션·폴더 구조)를
정한다.

- **UI**: SwiftUI
- **프로젝트 구성**: Tuist 로 Xcode 프로젝트를 생성/관리한다 (mise 로 설치). 손으로
  `.xcodeproj` 를 직접 편집하지 않고 `Project.swift`(Tuist manifest)를 단일 소스로
  둔다. 생성은 `tuist generate`.
- **대상**: iOS 기기, **최소 iOS 26.5**
- **언어**: Swift 6.2 — Swift 6 언어 모드의 strict concurrency 를 기준으로 한다
  (`Sendable`, actor 격리, `async`/`await`). 동시성 경고를 억지로 우회하지 않는다.
- **영속화**: SwiftData (`@Model`, `ModelContainer`, `@Query`)
- **SwiftData 매크로를 적극 사용한다.** 모델은 `@Model`, 프로퍼티/관계 커스터마이즈는
  `@Attribute`·`@Relationship`·`@Transient`, 쿼리/제약은 `#Predicate`·`#Index`·
  `#Unique`·`#Expression` 를 기본값으로 쓴다. 수동 보일러플레이트(직접 fetch 문자열,
  수기 인덱스/유니크 관리)보다 매크로 선언을 우선한다. (`@Query`·`@Environment` 는
  매크로가 아니라 SwiftUI 프로퍼티 래퍼지만 SwiftData 읽기·주입에 함께 쓴다.)
- iOS 26.5 / Swift 6.2 최소 사양 덕에 최신 SwiftUI · Observation(`@Observable`) ·
  SwiftData API 를 제약 없이 쓴다. 하위 호환을 위한 우회 코드는 두지 않는다.

> [!warning] 아키텍처 세부 미확정 (필독)
> 위 기반 스택은 확정됐지만, 그 위의 아키텍처 세부(상태 관리 패턴, 네비게이션
> 소유권, 폴더/모듈 구조, 모델·뷰·service 경계, 금지 패턴)는 아래 "아키텍처"
> 섹션과 `docs/architecture.md` 가 채워질 때 확정한다. 그 전까지 구조·패턴 규칙은
> 강제하지 않는다. 에이전트 역할·워크플로(아래)는 아키텍처와 무관하게 그대로 쓴다.

## 테스트 정책

- **테스트 코드는 개발 초기에 작성하지 않는다.** 기능 구현이 거의 완료된 뒤 별도
  테스트 단계에서 작성한다(기능별 동시 작성·TDD 아님). 사용자가 테스트 단계를 열기
  전까지는 테스트를 만들지 않는다.
- 그 전까지 검증은 **컴파일·빌드·실행 동작 확인**으로 한다. `make test`(또는 테스트
  타깃)는 테스트가 존재하기 전까지 게이트로 강제하지 않는다.
- 따라서 `developer` 는 기능마다 테스트를 추가하지 않아도 되고, `reviewer` 는 테스트
  누락을 (테스트 단계 전에는) `REQUEST_CHANGES`/`REJECT` 사유로 보지 않는다. 대신
  빌드 green·동작·회귀를 본다.
- 테스트 단계에 들어가면 모델 로직·service contract·상태 전이를 우선 대상으로 하고,
  순수 시각적 SwiftUI 컴포넌트와 `@Query` 바인딩 자체는 대상에서 제외한다.

## 기본 방향

- 이 프로젝트에서 새로 작성하는 문서는 한국어로 작성한다.
- 커밋 메시지는 conventional commit 타입을 사용하되 설명은 한국어로 작성한다.
  - 예: `feat: 홈 화면 추가`
  - 예: `fix: 핀 저장 오류 수정`
- 커밋 메시지는 제목 한 줄만 사용한다. 본문, 부연 설명, `Co-Authored-By`
  같은 트레일러는 붙이지 않는다.
- 화면 구현 태스크 커밋은 가능한 경우 `docs/screen-implementation-tasks.md`의
  작업 ID를 포함한다.
  - 형식: `type: [screen-01] 설명`
  - 예: `feat: [screen-01] 홈 지도 화면 추가`
- 화면 구현 태스크를 새로 추가할 때는 `screen-XX` 형식의 다음 번호를 사용하고,
  기존 작업 ID와 겹치지 않게 `docs/screen-implementation-tasks.md`에서 먼저
  확인한다.
- Swift 스타일은 Airbnb Swift Style Guide를 따른다.
- SwiftFormat, SwiftLint, Mise, Makefile이 추가되면 루트 설정을 우선 사용한다.
- 코드 변경 후 가능한 경우 `make format`, `make lint`, 그리고 **빌드 green** 으로
  확인한다(테스트는 "테스트 정책" 참고 — 후반 단계 전까지 `make test` 를 게이트로
  강제하지 않는다). 아직 명령이 없다면 가능한 Xcode 또는 SwiftPM 검증 명령을 쓴다.
- 화면, 디자인, UX, UI 구현 작업을 할 때는 먼저 `docs/screen-map.md`와
  `docs/screen-implementation-tasks.md`를 확인한다(문서가 준비되면).
- 전달된 화면 목록, 구현 상태, 누락 화면, 다음 구현 태스크는
  `docs/screen-implementation-tasks.md`를 기준으로 확인하고 갱신한다.
- 사용자가 "다음 할 일", "다음 할일", "next task"처럼 다음 작업을 물으면
  `docs/next-task.md`를 먼저 확인한다.
- 화면 프로토타입 원본이 추가되면 `references/prototypes/homepin`을 기준으로
  확인한다.

## 아키텍처

기반 스택(SwiftUI · iOS 26.5+ · Swift 6.2 · SwiftData · Tuist)은 "플랫폼 / 기술
스택"에 있다. 이 앱은 **서버 없이 데이터를 기기 내부(SwiftData)에 저장**한다. 따라서
저장소가 곧 단일 진실 소스이고, 상태 계층을 얇게 가져간다.

### 상태 관리 (확정)

**기본은 `View ↔ SwiftData` 직결**이다.

- **읽기**: View 가 `@Query` 로 `@Model` 을 직접 관찰한다(자동 갱신).
- **쓰기**: View 가 `@Environment(\.modelContext)` 의 `modelContext` 로 직접
  insert/delete 하거나 `@Model` 프로퍼티를 변경한다(SwiftData autosave).
- 단순 목록·상세·간단 편집은 별도 모델/계층 없이 이렇게 처리한다.

**얇은 `@Observable` 모델은 다음 두 경우에만** 그 화면에 둔다(기본값은 두지 않음).

1. 의미 있는 **비영속 UI 상태** — 저장 전 draft, 다단계 폼/wizard, 선택/검색어 등
   SwiftData 에 넣으면 안 되는 화면 로컬 상태.
2. **다단계 쓰기 규칙(불변식)** — 여러 `@Model` 에 걸친 트랜잭션이나 파생 쓰기
   (예: "소비 → 수량 감소 → 0 이면 삭제 → 로그 추가"). 단순 cascade 는 `@Model` 의
   `@Relationship(deleteRule:)` 로 처리하고 모델을 만들지 않는다.

즉 화면 대부분은 직결, 복잡한 에디터/플로우만 모델 하나를 갖는다. 모든 작은 SwiftUI
컴포넌트를 모델로 만들지 않는다.

> [!note] 미확정 (정해지면 이 섹션에 추가)
> 아래는 아직 정하지 않았다. 확정 전까지 관련 규칙은 강제하지 않는다.
>
> - 폴더/모듈 구조 (feature-first 등) — Tuist `Project.swift` 구성과 함께
> - 네비게이션 — push/modal 소유권, 라우팅 규칙
> - 의존성 / side-effect — 알림·파일 등 비영속 외부 작업의 service 경계 (영속화는
>   SwiftData 직결이라 별도 service 불필요)
> - 금지 패턴
>
> 상세 배경·결정은 `docs/architecture.md`에, 코드베이스 지도는
> `docs/codebase-overview.md`에 둔다.

## 에이전트 역할 문서

역할별 세부 지침은 `docs/agents/`에 둔다. 전체 플로우와 에이전트 구조 지도는
`docs/agents/overview.md`를 본다.

- 전체 구조·플로우 개요: `docs/agents/overview.md`
- 기획과 범위 정리: `docs/agents/planner.md`
- 코드와 문서 구현: `docs/agents/developer.md`
- 변경 리뷰: `docs/agents/reviewer.md`
- 다중 렌즈 병렬 리뷰: `docs/agents/hunt.md`
- 스타일·구조 정리: `docs/agents/tidy.md`
- 과거 맥락 회수: `docs/agents/recall.md`

### 역할 호출 별칭

사용자가 아래 형식으로 요청하면 해당 역할 문서를 먼저 읽고 그 기준으로 작업한다.

- `hpi:plan`: `docs/agents/planner.md`
- `hpi:dev`: `docs/agents/developer.md`
- `hpi:review`: `docs/agents/reviewer.md`
- `hpi:hunt`: `docs/agents/hunt.md` (변경 diff 다중 렌즈 병렬 리뷰 + 반증 검증, 깊은
  리뷰용. Claude Code 전용 `Workflow` 기반)
- `hpi:tidy`: `docs/agents/tidy.md`
- `hpi:recall`: `docs/agents/recall.md` (작업 시작 전 과거 맥락 회수, 보조 워크플로)
- `hpi:auto`: `triage` -> (`planner`) -> `developer` <-> `reviewer` -> `tidy` 자동
  진행 (복잡도 라우팅 + 수렴 루프 + 정리, 자세한 규약은 "자동 진행 명령" 참고)

`hpi`는 HomePin iOS의 프로젝트 접두어다. 이 별칭은 셸 명령이나 외부 도구 명령이
아니라 대화 안에서 역할을 명확히 지정하기 위한 요청 형식이다.

사용자가 `hpi`만 입력하면 아래 역할 목록과 사용 예시를 짧게 안내한다.

```txt
HomePin iOS 역할 명령

hpi:plan    기획/범위 정리
hpi:dev     구현
hpi:review  리뷰
hpi:hunt    변경 diff 다중 렌즈 병렬 리뷰 + 반증 검증(깊은 리뷰)
hpi:tidy    스타일·구조 정리(포맷+일관성)
hpi:recall  작업 시작 전 관련 과거 맥락 회수
hpi:auto    기획 -> 구현 -> 리뷰 -> 정리 자동 진행

예: hpi:plan 홈 지도 플로우 잡아줘
예: hpi:dev ItemEditor 화면 구현해줘
예: hpi:review 현재 변경사항 규칙 기준으로 봐줘
예: hpi:hunt 현재 변경분 다중 렌즈로 깊게 봐줘
예: hpi:tidy 방금 변경분 포맷·구조 정리해줘
예: hpi:recall 레시피 영속화 관련 과거 결정 있나 찾아줘
```

### 자동 진행 명령

사용자가 `hpi:auto`로 요청하면 아래 순서로 진행한다.

```txt
triage -> (recall) -> (planner) -> developer <-> reviewer -> tidy
```

고정 선형 체인이 아니라, 요청 복잡도로 진입점을 정하고(`triage`) 리뷰는 수렴
루프(`developer <-> reviewer`)로 운영하며, 승인 후 `tidy` 가 스타일·구조
일관성을 정리한다. MEDIUM·HIGH 면 진입 직후 `recall` 로 관련 과거 맥락을 회수해
이후 단계에 주입한다.

#### Triage (진입 라우터)

`hpi:auto` 시작 시 메인 루프가 별도 서브에이전트 없이 인라인으로 요청을
LOW/MEDIUM/HIGH 중 하나로 분류한다.

| 등급 | 신호 (하나라도 해당) | 실행 경로 |
| --- | --- | --- |
| LOW | 오타·주석·문구·로그·상수값, 단일 파일의 명백한 fix, 문서만 수정 | planner 생략 → developer → reviewer |
| MEDIUM | 기존 feature 동작 수정, 작은 화면 변경, 1~2개 feature 범위 | planner(경량) → developer → reviewer |
| HIGH | 새 화면/flow 추가, 데이터모델·persistence·권한·동기화, 네비게이션/아키텍처 구조 변경, 여러 feature 교차 | planner(풀) → developer → reviewer |

- 등급이 애매하면 항상 한 단계 위로 올린다(보수적 기본값). 라우터의 실수는
  과소 분류가 위험하다.
- 분류 직후 `라우팅: <등급> (근거: ...)` 한 줄을 남긴다.
- 데이터모델·권한·동기화 신호가 보이면 등급 판정보다 아래 특이점 정지가 먼저다.

#### Recall (과거 맥락 회수)

MEDIUM·HIGH 면 triage 직후 `recall` 서브에이전트(`docs/agents/recall.md`)로
`docs/wiki/`(`Decision/`·`Research/`·`Idea/` + 관련 `Screens/`·`Models/` 노트)·
`docs/follow-ups.md`·`docs/next-task.md` 에서 이번 작업과 관련된 과거 맥락을 회수한다. 목적은 "탐색 품질이 결과 품질을 결정한다" — 이미 내린 결정·폐기한
접근·미결 항목을 다시 밟지 않게 하는 것이다.

- recall 은 요약 digest 만 반환하고(원문 덤프 금지), 메인 루프는 이를 이후
  planner·developer 위임 프롬프트에 함께 전달한다 (컨텍스트 격리).
- recall 이 "따라야 할 결정" 과 충돌하는 요청을 드러내면 특이점 정지로 본다.
- LOW 는 생략한다 (회수 비용이 이득을 넘는다).

#### 수렴 루프 (Maker-Checker)

`reviewer` 판정에 따라 분기한다. 최대 fix 반복은 2회(= 리뷰 최대 3회)다.

HIGH 등급의 깊은 검토가 필요하면 단일 `reviewer` 대신(또는 APPROVE 후 한 번 더)
`hunt`(`docs/agents/hunt.md`) 로 다중 렌즈 병렬 리뷰 + 반증 검증을 돌릴 수 있다.
hunt 는 에이전트를 여럿 띄워 비용이 크므로 HIGH·고위험 변경에 한정한다.

- `APPROVE`: 루프를 종료한다.
- `REJECT`: 자동 수정하지 않고 정지하여 사용자에게 에스컬레이션한다(설계 결함은
  자동 수정 대상이 아니다).
- `REQUEST_CHANGES`:
  - fix 횟수 < 2 → developer에게 **reviewer가 짚은 findings만 스코프 한정**으로
    수정 위임(새 기능·리팩터 금지) → reviewer 재리뷰(지적 해소·회귀 여부만 확인)
    → 본 단계를 반복한다.
  - fix 횟수 = 2 → 정지하고 남은 findings와 판정 이력을 요약하여 사용자에게
    에스컬레이션한다.
- developer가 `BLOCKED`를 보고하면 정지하고 planner 재호출을 제안한다(이벤트
  기반 재평가).
- 루프의 작업 소유자(owner)는 메인 루프로 고정한다. owner·상한·에스컬레이션으로
  무한 handoff 루프를 차단한다.

#### 정리 (tidy)

`reviewer` 가 `APPROVE` 하면 마지막으로 `tidy` 서브에이전트가 변경분의 스타일·구조
일관성을 정리한다. developer 는 동작·요구사항에 집중하고, 포맷·재배치·일관성은
tidy 가 전담한다(관심사 분리).

- 대상은 이번 태스크가 변경한 파일로 한정한다.
- 기계 포맷(`make format`)과 판단형 일관성(도메인 폴더 배치, 1000줄 초과 View 파일
  분리, 네이밍, dead code 정리)을 적용한다.
- `make lint`(0 violations) 와 **빌드 green** 게이트를 통과시킨다(테스트가 이미
  있으면 `make test` 회귀 0 도 — "테스트 정책" 참고).
- 동작·로직은 바꾸지 않는다. 순수 스타일/구조 정리만 한다.
- 변경 성격이 기계 포맷 수준(`MECHANICAL_ONLY`)이면 종료하고, 파일 이동/분리·
  시그니처 변경 같은 구조 변경(`STRUCTURAL`)이면 `reviewer` 수렴 루프로 1회만
  재진입해 재검증한다(tidy 발 재검증은 1회로 제한해 무한 루프를 막는다).

다만 아래 특이점이 있으면 즉시 멈추고 사용자에게 질문한다.

- 제품 범위, 화면 맵, 프로토타입 의도와 요청 범위가 충돌한다.
- 저장소, 데이터 모델, 권한, 동기화처럼 되돌리기 어려운 결정을 새로 해야 한다.
- `docs/screen-map.md` 또는 `references/prototypes/homepin`과 UI 요청이 크게
  충돌한다.
- `docs/screen-implementation-tasks.md`의 화면 목록, 상태, phase 계획과 요청
  범위가 크게 충돌한다.
- 검증 실패, 테스트 실패, 빌드 오류, 린트 오류가 발생한다.
- 사용자 변경으로 보이는 미커밋 변경이 현재 작업과 충돌한다.
- 외부 계정, 시크릿, 유료 서비스, 배포, 원격 데이터 삭제가 필요하다.
- 요구사항이 모호해서 합리적 기본값으로 진행하면 제품 동작이 크게 달라질 수 있다.

특이점이 없으면 각 단계의 핵심 결과만 짧게 남기고 계속 진행한다. 마지막에는
검증/리뷰 결과, 변경 파일, 다음 추천 행동을 요약한다.

### 역할 전환

역할 전환은 기본적으로 자동으로 하지 않는다. 예를 들어 `hpi:plan` 작업 중 다음
단계가 `developer` 또는 `reviewer`라면, 전환 전에 사용자에게 확인한다. 사용자가
한 요청 안에서 여러 역할 실행을 명시한 경우나 `hpi:auto`로 요청한 경우에만
순서대로 진행한다.

## 문서 구조

프로젝트 문서는 두 영역으로 나뉜다.

### 코드 문서 (`docs/`)

코드 변경과 함께 갱신되는 "사실/규칙" 문서. 아키텍처 확정과 함께 작성한다.

- `docs/codebase-overview.md` — 코드베이스 전체 지도 (빌드·구조·Feature·Dependency·위젯·테스트) *(작성 예정)*
- `docs/architecture.md` — flow 소유권·네비게이션 원칙 *(작성 예정)*
- `docs/screen-map.md` — 화면 노드 맵과 mermaid 플로우 다이어그램 *(작성 예정)*
- `docs/screen-implementation-tasks.md` — 화면별 구현 진도 (단일 진실 소스) *(작성 예정)*
- `docs/development.md` — 빌드·검증 워크플로 *(작성 예정)*
- `docs/style-guide.md` — Swift/SwiftUI 스타일 *(작성 예정)*
- `docs/follow-ups.md` — 리뷰 지적·검증 대기 항목 *(작성 예정)*
- `docs/next-task.md` — 다음 할 일 *(작성 예정)*
- `docs/agents/` — 에이전트 역할 정의 (Claude Code · Codex 공유)

### 옵시디언 위키 (`docs/wiki/`)

`docs/wiki/`는 옵시디언 vault다. 코드 문서가 "사실/규칙"을 담는다면 위키는 **앱의
구조 지식 지도**(화면·모델 노드)와 "맥락/결정"을 담는다. **시간 기반 데일리/주간
노트는 두지 않는다** — 위키는 날짜가 아니라 **엔티티(화면·모델) 단위**로 조직한다.

- `docs/wiki/index.md` — MOC, 진입 허브 (화면·모델·결정 목록)
- `docs/wiki/notes-guide.md` — 명명·태그·frontmatter·링크 규약 + 노트 템플릿
- `docs/wiki/Screens/` — **화면 노트.** 화면 하나당 1노트. 생성일·역할·연결된
  화면(`[[...]]`)·연결된 모델(`[[...]]`)·관련 태스크(`[screen-XX]`). 태그 `#screen`.
- `docs/wiki/Models/` — **모델 노트.** SwiftData `@Model` 하나당 1노트. 생성일·역할·
  보유 데이터·`@Relationship` 대상 모델(`[[...]]`)·사용 화면(`[[...]]`). 태그 `#model`.
- `docs/wiki/Decision/` — 비가역 결정 (ADR 스타일). 태그 `#decision`.
- `docs/wiki/Research/` — 외부 자료·조사 정리. 태그 `#research`.
- `docs/wiki/Idea/` — 임시 아이디어. 태그 `#idea`.

**옵시디언 링크(`[[노트명]]`)와 태그(`#screen`/`#model`/...)를 적극 사용한다** —
화면↔화면, 화면↔모델, 노트↔결정을 위키링크로 잇고, 그래프 뷰에서 앱 구조가 한눈에
보이게 한다. 모든 코드 문서·위키 노트는 YAML frontmatter(`aliases`, `tags`,
`created`, `updated`, `status`)를 갖는다. 태그 체계·frontmatter 스키마·템플릿은
`docs/wiki/notes-guide.md`를 단일 기준으로 한다.

## 문서 동기화

코드 · 코드 문서 · 위키 사이의 일관성을 유지하기 위한 갱신 규칙.

### 코드 변경 → 코드 문서 갱신

| 변경 종류 | 갱신 대상 |
| --- | --- |
| 화면 구현 진행 | `docs/screen-implementation-tasks.md` (상태/Phase) |
| 화면 추가·제거 | `docs/screen-map.md` (노드·엣지·mermaid) + `docs/screen-implementation-tasks.md` |
| flow·네비게이션 구조 변경 | `docs/architecture.md`, `docs/codebase-overview.md` |
| 새 dependency client | `docs/codebase-overview.md` |
| 빌드 구성 변경 | `docs/development.md`, `docs/codebase-overview.md` |
| 다음 작업 변동 | `docs/next-task.md` |
| reviewer 스코프 외 지적 | `docs/follow-ups.md` 추가 |
| **화면 추가·역할/연결 변경** | `docs/wiki/Screens/<화면>.md` 생성·갱신 (역할·연결 화면·연결 모델·`updated`) |
| **`@Model` 추가·필드/관계 변경** | `docs/wiki/Models/<모델>.md` 생성·갱신 (역할·보유 데이터·관계·사용 화면·`updated`) |

갱신한 문서의 frontmatter `updated:` 필드도 함께 바꾼다.

### 위키 작성 워크플로우

위키는 **앱 구조 지식 지도**다. 화면·모델 노트는 **그것을 추가·변경하는
`developer` 가 코드와 함께** 만들고 갱신한다(별도 데일리 워크플로 없음).

| 노트 유형 | 작성 주체 | 갱신 시점 |
| --- | --- | --- |
| Screen | developer (코드와 함께) | 화면 추가 시 생성, 역할/연결 변경 시 갱신 |
| Model | developer (코드와 함께) | `@Model` 추가 시 생성, 필드/관계 변경 시 갱신 |
| Decision | 에이전트 작성 | 비가역 결정(데이터 모델·권한·영속화 등) 발생 시 즉시 |
| Research | 사용자 또는 에이전트 | 외부 자료 정리 필요 시 |
| Idea | 사용자 | 자유 |

화면·모델 노트는 **연결 관계를 `[[위키링크]]` 로 양방향 표기**한다(화면→모델,
모델→화면). 명명·태그·링크·템플릿은 `docs/wiki/notes-guide.md` 를 단일 기준으로
한다. 위키 노트도 코드 문서와 동일한 frontmatter 스키마를 쓴다.

## 다음 할 일 기록

다음 작업은 `docs/next-task.md`에 짧게 기록한다. 작업을 완료하거나 우선순위가
바뀌면 이 파일을 함께 갱신한다.
