---
aliases: [NL 추가 파서, Foundation Models 채택, 자연어 파싱 아키텍처]
tags: [decision, decision/data]
created: 2026-06-15
updated: 2026-06-17
status: accepted
---

# 2026-06-15 NL 추가 파서 — Foundation Models 채택

[[Capture]] 의 자연어 "추가" 를 온디바이스 LLM 으로 구조화하는 비가역 결정
(프레임워크 채택 + `@Generable` 출력 스키마 + 가용성 폴백). 제품 방향
[[제품-방향-재고-레시피-AI]] · 후보 [[AI-적용-후보]] · 음성 경로
[[2026-06-15-음성입력-STT-아키텍처]] 의 "텍스트·음성 공용 단일 파서로 수렴" 결정을 잇는다.

> [!note] 이 노트는 채택 방향 확정용 ADR 이고 구현은 아직 시작하지 않았다. 단계별
> 구현은 `docs/screen-implementation-tasks.md`(screen-09)·`docs/next-task.md` 를 따른다.

## 맥락

추가/검색 시트([[Capture]])는 텍스트 + 음성 2-입력이고, 음성은 받아쓰기로 텍스트를
채우는 입력기다(STT 결정). 현재 "추가" 는 입력 텍스트를 이름 draft 로
`ItemEditorRoute(.create(initialName:))` 에 넘기는 **스텁**이다. 제품 1순위는 이
텍스트(타이핑/받아쓰기 공용)를 **구조화 드래프트**(물건·위치·수량·분류, 다건 배열)로
바꿔 확인 후 저장하는 것. 최소 사양 iOS 26.5 / Swift 6.2. 온디바이스 LLM 프레임워크
채택과 출력 스키마는 되돌리기 어려운 표면이라 확정이 필요했다.

## 결정

1. **프레임워크**: Apple **Foundation Models**(온디바이스·무료·오프라인) 채택. 추론은
   `LanguageModelSession`, 구조화 출력은 `@Generable` + `@Guide`. 서버/네트워크/계정
   없음 → 새 권한 키 불필요.
2. **출력 스키마**(실제 모델에 grounding — `Item` 의 위치는 `area`(옵셔널, 앱 규칙상
   최소 Area 소속) + `spot`(옵셔널), `space` 는 `area.space` 로 파생이라 직접 필드가
   아님):
   ```
   @Generable struct ParsedItemList { var items: [ParsedItem] }
   @Generable struct ParsedItem {
     @Guide(description:"물건 이름")               var name: String
     @Guide(description:"수량(기본 1)")            var quantity: Int
     @Guide(description:"공간: 집/사무실 등, 없으면 빈 문자열") var space: String
     @Guide(description:"구역: 주방/안방 등")       var area: String
     @Guide(description:"세부위치: 냉동실/서랍 등, 없으면 빈 문자열") var spot: String
     @Guide(description:"카테고리: 식품/주방용품 등") var category: String
     @Guide(description:"태그(0개 이상)")           var tags: [String]
   }
   ```
   - 엔진은 **순수 추출만**(문자열) 한다. `Item` 객체·SwiftData 접근은 하지 않는다.
   - 유통기한·메모·사진·find/add 의도는 v1 범위 밖(확인 화면 수동 또는 후속).
3. **grounding + 매칭("없으면 생성/있으면 기존 매칭")**: 자유 텍스트 표류를 막기 위해
   기존 `Space/Area/Spot`·`ItemCategory`·`Tag` 후보를 프롬프트에 주입한다. 출력은
   문자열로 받고, **저장 직전 도메인 측에서 `Item.normalize(_:)` 로 정규화 매칭**해
   기존이면 연결, 없으면 신규 생성. 매칭은 엔진이 아니라 드래프트 해석 단계(도메인)에
   둔다(엔진=추출, 도메인=매칭/생성 분리). 강한 enum 강제 대신 후보 주입 + 사후 매칭을
   기본으로 하되, 한국어 품질에 따라 `@Guide(.anyOf(후보))` 약한 grounding 을 구현
   단계에서 택1.
   - **자동추론 억제(2026-06-17 보강)**: 분류·태그는 문장에 그 단어가 명시될 때만
     채우고 용도·성격 추론으로 지어내지 않는다. grounding 후보도 문장에 일치 단서가
     있을 때만 매칭에 쓰고, 단서가 없으면 후보가 있어도 비운다(기존 "가능한 한 그 이름을
     그대로 쓴다"가 과추론을 유도해 조건 부가). 이 규칙은 입력 언어와 무관하게 적용한다.
4. **가용성 게이팅 + 폴백**: `SystemLanguageModel.default.availability` 가 `.available`
   이면 파서 경로, 그 외(미지원 기기·OS·모델 미설치)면 **즉시 현 단건 스텁**(텍스트 →
   `ItemEditor` 이름 prefill)으로 폴백한다. 추론 실패·취소도 동일 폴백. **텍스트 입력
   경로는 항상 살아있다**(AI 는 거들기). `docs/next-task.md` #5 기기 게이팅과 연결.
5. **아키텍처 경계**(검증된 STT 패턴 복제): 비-MainActor 파서 엔진 `NLItemParser`
   (`Shared/AI/`, 추출만) + `@MainActor @Observable NLParseViewModel`(파싱 상태 +
   단일 세션 Task 소유/cancel) + 확인 드래프트 상태 `AddDraft`(항목별 편집 + 신규/기존
   매칭 불변식, 다건 일괄 저장 — `ItemEditorModel.save` 패턴 재사용). 엔진의 `Sendable`
   경계(`LanguageModelSession` 격리)는 구현 첫 컴파일에서 확정.
6. **확인 드래프트 화면 = 신규 `screen-09`**: [[Capture]] 가 소유하는 push 화면
   (`navigationDestination`). 항목별 확인/수정/삭제, 신규 vs 기존 매칭 시각 구분, 다건
   배열. 저장 완료 시 시트 dismiss. `ItemEditor` 다건 확장은 비채택(에디터는 단건
   불변식 특화 — 행 탭 시 단건 편집 재사용은 가능).

## 대안 / 폐기한 선택지

- **음성 독립 파서/엔진** — STT 결정에서 이미 폐기(입력 경로 이원화는 폴백·유지 복잡).
  텍스트·음성은 같은 텍스트 → 같은 파서로 수렴.
- **자동 저장(확인 단계 없음)** — 소형 모델 오인식(수량·위치) 위험. **확인 드래프트
  단계를 필수 안전망**으로 둔다.
- **위치/분류를 순수 `@Generable` enum 으로 강제** — 후보가 동적(사용자 데이터)이라
  부적합. 후보 주입 + 사후 정규화 매칭을 기본으로.
- **서버 LLM / 외부 API** — 서버 없는 로컬 앱 정체성에 반함. 비용·프라이버시·오프라인
  불리. 온디바이스 채택.
- **`ItemEditor` 다건 확장으로 확인 화면 대체** — 단건 에디터 불변식 오염. 별 화면(screen-09).

## 영향

- 영향받는 화면: [[Capture]] (add() 분기), 신규 확인 드래프트(screen-09)
- 영향받는 모델: **`@Model` 스키마 변경 없음** — 기존 `Item`/`Space`/`Area`/`Spot`/
  `ItemCategory`/`Tag` 로만 grounding·저장. `Item.normalize(_:)` 재사용.
- 의존성: 신규 `import FoundationModels`. 권한 키 불필요. 빌드 후 `tuist generate`.
- 한계: **시뮬레이터는 실제 추론 불가 가능성**(STT 와 동일) → 빌드·UI·폴백·매칭까지만
  시뮬레이터 검증, 추론 품질·한국어 정확도·모델 가용성은 실기기 필수.
- 잔여(`docs/follow-ups.md`): "받아쓰기 텍스트 → AI 파서 공용 경로" 해소 예정,
  모델 다운로드 유도 UX·자연어 검색·find/add 의도판별·영수증 OCR 은 후속([[AI-적용-후보]]).
