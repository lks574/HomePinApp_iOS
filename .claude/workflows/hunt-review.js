export const meta = {
  name: 'hunt-review',
  description: '변경 diff를 다중 렌즈로 병렬 리뷰하고 각 finding을 반증 검증한다 (hpi:hunt / Branch Hunt)',
  phases: [
    { title: 'Review', detail: '렌즈별 병렬 리뷰' },
    { title: 'Verify', detail: 'finding 반증 검증' },
  ],
}

// args.target 이 주어지면 그 커밋/레인지(`git show <ref>`)를, 없으면 현재 작업트리의
// 미커밋 변경(`git diff HEAD`)을 리뷰한다.
const TARGET = args && args.target ? String(args.target) : null
const DIFF_CMD = TARGET ? `git show ${TARGET} -- '*.swift'` : `git diff HEAD -- '*.swift'`
const SCOPE = TARGET ? `커밋/레인지 ${TARGET}` : `현재 작업트리의 미커밋 Swift 변경(HEAD 대비)`

const LENSES = [
  { key: 'bug', prompt: '버그·회귀·엣지케이스(nil/옵셔널, 경계값, 비동기 경쟁, 강제 unwrap, 잘못된 상태 전이)' },
  { key: 'arch', prompt: '아키텍처 경계·네비게이션 ownership. CLAUDE.md "아키텍처" 섹션과 docs/architecture.md 의 규칙(상태 소유권, 네비게이션 소유권, 모델/뷰/service 경계, 금지 패턴)을 따르는가. 아키텍처가 아직 확정 전이면 명백한 경계 위반·중복 소유만 지적한다.' },
  { key: 'effect', prompt: 'async effect·cancellation 사용, 장기 작업의 명시적 취소, clock/date/uuid를 전역 API 대신 주입받는가, View/모델이 persistence/network/notification을 직접 호출하지 않는가' },
  { key: 'env', prompt: '환경 분기 누락: 오프라인, 권한 거부, 빈/로딩/에러 상태, 동기화 충돌, 데이터 로드 실패 등 실제 실행 환경 분기를 빠뜨렸는가' },
  { key: 'failure', prompt: 'AI 실패 5패턴 가드(docs/agents/reviewer.md 기준): 원인 축소(증상만 막음)·가설 고착·국소 최적화(건드린 파일만 맞춤)·환경 맹점·탐색 중단(기존 dependency/feature 중복 구현)' },
]

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          severity: { type: 'string', enum: ['HIGH', 'MEDIUM', 'LOW'] },
          file: { type: 'string' },
          line: { type: 'string' },
          title: { type: 'string' },
          detail: { type: 'string' },
        },
        required: ['severity', 'file', 'line', 'title', 'detail'],
      },
    },
  },
  required: ['findings'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    refuted: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: ['refuted', 'reason'],
}

const base = `리뷰 대상은 ${SCOPE} 이다. \`${DIFF_CMD}\` 로 diff 를 보고, 필요하면 관련 파일을 읽어 맥락을 보강하라. 프로젝트 규칙은 CLAUDE.md 와 docs/agents/reviewer.md 를 따른다. 확실하지 않으면 finding 에 넣지 마라(정확도 > 재현율). 각 finding 은 {severity, file, line, title, detail} 로 작성한다. 변경이 없으면 빈 findings 를 반환한다.`

phase('Review')
const results = await pipeline(
  LENSES,
  (lens) => agent(`${base}\n\n이번 리뷰 렌즈: ${lens.prompt}`, { label: `review:${lens.key}`, phase: 'Review', schema: FINDINGS_SCHEMA }),
  (review, lens) => parallel(((review && review.findings) || []).map((f) => () =>
    agent(`아래 리뷰 지적이 실제로 맞는지 코드를 다시 열어 반증을 시도하라. ${SCOPE} 의 해당 파일/라인을 확인하고, 지적이 틀렸거나 근거가 약하면 refuted=true, 명백히 실제 문제면 refuted=false. 기본값은 회의적으로(애매하면 refuted=true).\n\n지적 [${f.severity}] ${f.file}:${f.line} — ${f.title}\n${f.detail}`,
      { label: `verify:${lens.key}`, phase: 'Verify', schema: VERDICT_SCHEMA })
      .then((v) => ({ ...f, lens: lens.key, verdict: v }))
  ))
)

const all = results.flat().filter(Boolean)
const confirmed = all.filter((f) => f.verdict && !f.verdict.refuted)
const refuted = all.filter((f) => f.verdict && f.verdict.refuted)
return {
  target: TARGET || 'working-tree',
  raw_total: all.length,
  confirmed_count: confirmed.length,
  refuted_count: refuted.length,
  confirmed,
  refuted_titles: refuted.map((f) => `[${f.lens}] ${f.title}`),
}
