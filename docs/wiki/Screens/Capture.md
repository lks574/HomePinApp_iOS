---
aliases: [Capture, NL 추가, 빠른 추가]
tags: [screen, screen/item]
created: 2026-06-12
updated: 2026-06-17
status: in-progress
screen-id: screen-01
related-tasks: [screen-01, screen-04, screen-09, screen-12, screen-16]
---

# Capture (검색-우선 통합 시트)

자연어 텍스트 또는 음성으로 물건·레시피를 찾거나 추가하는 단일 입력 시트. 탭바 중앙 ✨(AI, `sparkles`) 슬롯에서 열린다. **[추가|검색] 모드 토글이 없는 검색-우선 통합** UX — 단일 입력 필드 하나에 입력하면 기존 항목을 실시간 검색해 보여주고, 결과 아래 항상 `+ "{입력어}" 추가하기` 행을 둔다. 검색은 항상 일어나고, 추가는 사용자가 이 행을 **명시적으로 누를 때만** 일어난다(AI 가 추가/검색 의도를 자동 추측하지 않음 — 오분류 데이터 오염 방지). 추가 입력은 온디바이스 AI 파서로 구조화해 [[DraftReview]] 확인 화면으로 넘기고, 미가용·실패·취소 시 이름 draft 로 [[ItemEditor]] 에 넘기는 단건 스텁으로 폴백한다.

## 역할

- 단일 입력 필드(타이핑·음성 받아쓰기 공용)를 제공한다. 음성은 같은 입력 필드를 채우는 입력기일 뿐, 텍스트 경로는 항상 살아 있어 음성 불가용 시 폴백된다.
- 검색(항상): 물건은 이름·위치 경로·장소·세부위치·분류·태그·메모·수량을, 레시피는 제목·요약·cuisine/dishType 라벨·태그·재료명/단위/메모를 정규화 부분 일치로 필터해 입력 즉시 결과를 **물건/레시피 섹션**으로 구분 표시. 자연어 문장은 로컬 규칙(`CaptureSearchQuery`)으로 조사·불용어를 제거한 토큰 전체 일치 + 속성 플래그(임박/만료/위치 없음/지금 만들 수 있음/부족 재료)로 보강한다. 물건 결과 탭 시 [[ItemEditor]] `edit` 모드로 진입하고, 레시피 결과 탭 시 시트를 닫고 레시피 탭 상세([[RecipeDetail]])로 push(`AppRouter.openRecipe`).
- 검색 정교화(`screen-16`, `Shared/Search/`):
  - **랭킹 정렬**(`SearchRanking`·`MatchTier`): 결과를 정확>접두>부분 등급으로, 동등급은 상태 가중치(물건=임박 우선·위치없음 후순, 레시피=지금 가능·임박 재료 우선), 그 다음 이름순으로 정렬한다(`@Query` 이름순이 안정 정렬로 동점을 가른다).
  - **초성 검색**(`Hangul`): 질의가 전부 호환 자모 초성 자음일 때만 활성. 필드 초성열에 부분 일치하면 최하위 `.choseong` 등급으로 매칭한다(일반 텍스트 질의는 기존 경로, 회귀 0).
  - **편집거리 fallback**(`Levenshtein`): 정상 매칭 결과가 **하나도 없을 때만**, 전체 물건에 대해 토큰별 음절 편집거리 임계(길이≤3→1, 그 외 2) 이내 근사 매칭으로 `.fuzzy` 등급 폴백. `hasConcreteSignal` 가드를 유지해 빈 토큰 질의에서는 작동하지 않는다.
  - **추천 칩**(빈 입력): 최근 검색어(`@AppStorage("recentSearches")` JSON, 최대 8·최신우선·정규화 중복제거) + 임박 물건 상위. 칩 탭은 입력 필드만 채우고(자동 검색/추가 없음), 기록은 결과 탭·추가 진입 등 검색의도 확정 시점에 적재.
  - 위 모든 경로는 `hasConcreteSignal` 가드와 `normalizedName` 단일 매칭키를 우회하지 않는다.
- 추가(명시적): 결과 목록 아래 항상 노출되는 `+ "{입력어}" 추가하기` 행을 눌러야만 추가가 일어난다. 입력 텍스트(타이핑·받아쓰기 공용)를 가용 시 AI 파서(`NLParseViewModel`)로 구조화 드래프트로 바꿔 [[DraftReview]] 로 push, 미가용·실패·취소·빈 결과면 이름 draft 로 [[ItemEditor]] `create` 단건 스텁 폴백. 텍스트·음성 공용 단일 파서 경로. 파서 추론 중에는 추가 행이 진행 표시로 바뀐다.
- 중복 추가 가드(`screen-16`): 추가 진입 시 같은 `normalizedName` 의 기존 물건이 있으면 "수량 합치기 / 새로 추가 / 취소" 를 `confirmationDialog` 로 **제안**한다(자동 합치기·자동 저장 없음). "합치기"는 그 기존 물건의 [[ItemEditor]] `edit` 로 진입(수량 가산은 에디터에서 사용자가 직접 저장), "새로 추가"는 기존 파서/스텁 경로로 진행. 동등 비교는 `normalizedName` 동등만(부분일치 아님).

## 연결된 화면

- 들어옴 ←: 탭바 중앙 ✨(AI) 슬롯
- 이동 →: [[DraftReview]] — AI 파싱 성공 시 push(확인 드래프트). 저장 완료 시 시트 dismiss.
- 이동 →: [[ItemEditor]] — 추가 폴백은 `create(initialName:)`, 검색 결과 탭은 `edit(item)`
- 이동 →: [[RecipeDetail]] — 검색 레시피 결과 탭(시트 닫고 레시피 탭 push). `AppRouter.openRecipe(recipe)`
- 이동 →: [[RecipeCapture]] — 항상 노출되는 **명시적 "Add a recipe" 행**으로 레시피 전용 NL 입력 화면을 시트로 띄운다(검색어와 무관, 의도 자동추측 없음). 물건 빠른 추가와 레시피(긴 재료·단계 텍스트)의 입력 형태가 달라 별도 입력 공간으로 분기.

## 사용 모델

- 읽기: [[Item]] (`@Query` 로 검색 대상 전체를 받아 이름·위치·분류·태그·메모 등 정규화 키 + `CaptureSearchQuery` 자연어 토큰/속성으로 in-memory 필터).
- 읽기: [[Recipe]] (`@Query(sort: \Recipe.title)`, 제목·요약·분류·태그·재료 세부 텍스트 정규화 키 + `CaptureSearchQuery` 자연어 토큰/속성으로 in-memory 필터).
- AI 파서 grounding: `AddDraftResolver` 가 [[Space]]/[[Area]]/[[Spot]]/[[ItemCategory]]/[[Tag]] 이름을 모아 프롬프트에 주입(엔진은 SwiftData 무지).
- 쓰기 직접 없음. AI 추가 저장은 [[DraftReview]] 가 `AddDraftResolver` 로 [[Item]] + 신규 위치/분류/태그 일괄 insert, 폴백 저장은 [[ItemEditor]] 가 수행.

## AI 자연어 추가 (파서 경로)

- 가용성 게이트: `SystemLanguageModel.default.availability == .available` 이면 파서 경로, 아니면 단건 스텁 폴백. 시뮬레이터·미지원 기기는 미가용으로 떨어져 폴백 검증됨.
- `NLItemParser`(`Shared/AI/`, 비-MainActor, **추출만**): `LanguageModelSession` + `@Generable ParsedItemList/ParsedItem`(이름·수량·공간·구역·세부위치·분류·태그 문자열). SwiftData 접근 없음. 인스턴스를 메서드 스코프로 한정해 공유 가변 상태 없음(`Sendable` 강제 불필요).
- `NLParseViewModel`(@MainActor @Observable): 파싱 상태(idle/parsing/drafts/unavailable/failed) + 단일 세션 Task 소유/cancel(STT `SpeechDictationViewModel` 패턴). 추론 중 진행 표시 + 취소.
- `AddDraftResolver`(도메인 경계): grounding 수집 → 추출 문자열을 `Item.normalize` 정규화 매칭(없으면생성/있으면매핑) → `AddDraft` 생성 → 다건 일괄 저장(같은 신규 이름은 세션 내 1회만 생성, 위치 불변식 `spot.area == area` 유지).
- 텍스트·음성 공용: 받아쓰기 결과도 단일 입력 필드를 채운 뒤 `추가하기` 행을 누르면 같은 `add()` 파서 경로로 합류.

## 상태 관리

- 직결 읽기(`@Query allItems`/`allRecipes`) + 저장 위임. 비영속 UI 상태는 `@State` 로 보관 —
  단일 입력 `query`, 에디터 라우팅 `editorRoute`, 확인 화면 라우팅 `reviewRoute`.
  모드 토글(`CaptureMode`)·이중 입력(`text`/`searchText`)은 검색-우선 통합으로 제거됨.
- AI 파싱은 얇은 `@Observable` `NLParseViewModel` 을 `@State` 로 보유(비영속 UI 상태 +
  단일 세션 Task). `parser.state` 변화를 `.onChange` 으로 받아 성공이면 [[DraftReview]]
  push, 미가용·실패면 단건 스텁 폴백. 시트 종료 시 `reset()`.
- 음성 입력은 얇은 `@Observable` 컨트롤러 `SpeechDictationViewModel` 을 `@State` 로
  보유한다(비영속 UI 상태 + 단일 세션 Task 소유). `dictation.transcript` 변화를
  `.onChange` 으로 받아 단일 입력 필드(`query`)에 주입하고, 시트 종료 시 `reset()`.
  호출부 시그니처(`transcript`/`state`/`toggle()`/`reset()`)는 이전과 동일하다.
- 무음 자동 종료: `.recording` 진입 시 ViewModel 이 3초 무음 타이머를 무장하고
  `transcript` 가 실제로 바뀔 때마다 리셋한다. 3초간 텍스트 변화가 없으면 `stop()`
  으로 녹음을 자동 종료(엔진 teardown → `.idle`, transcript 누적분 보존)한다.
  `.preparing` 중에는 무장하지 않는다(모델 다운로드 시간 보호).
- 권한/오디오/모델 처리는 비-MainActor `SpeechDictationEngine` 으로 분리돼
  `DictationEvent` 스트림을 경계로 ViewModel 과 통신한다(actor 경계 분리). 시스템
  콜백을 MainActor 밖에서 만들어 격리 트랩을 피하고, 엔진 자원은 세션 Task cancel→
  스트림 종료 teardown 으로 정리한다.
- 녹음 중 오디오 인터럽션(전화·Siri·타 앱 점유) 시 엔진이 `AVAudioSession`
  `interruptionNotification` 을 구조적 동시성 AsyncSequence 로 감시하다가 `.began`
  에서 입력 스트림을 닫아 세션을 끝낸다. 스트림 자연 종료 경로로 ViewModel `state`
  가 `.idle` 로 복귀(마이크 버튼 stop 고착 해소)하고 transcript 누적분은 보존한다.
  `.ended` 에서 자동 재개하지 않으며 사용자가 마이크를 다시 눌러 재시작한다.

## 권한 / 받아쓰기 플로우

- `SpeechDictation` 이 마이크(`AVAudioApplication.requestRecordPermission`)와 음성
  인식(`SFSpeechRecognizer.requestAuthorization`) 권한을 순차 확보한다. 둘 다 허용 시
  iOS 26 `SpeechTranscriber`(ko-KR) + `SpeechAnalyzer` 온디바이스 받아쓰기를 구동.
- 모델 미설치 시 `AssetInventory` 로 확인/설치, 미지원·거부 시 `state` 를
  `.unavailable`/`.denied` 로 떨어뜨리고 시트는 안내 + 텍스트 폴백을 노출한다.
- Info.plist 권한 키(`NSMicrophoneUsageDescription`,
  `NSSpeechRecognitionUsageDescription`)는 `Project.swift` 공유 Info.plist 에 둔다(양
  플랫폼 공통).
- **macOS 분기(screen-17)**: STT 는 macOS 공통(audio-input entitlement 로 마이크 접근).
  `AVAudioSession` 설정만 `#if os(iOS)` 로 건너뛴다(macOS 는 세션 개념 없음). 텍스트·검색·
  AI 추가 경로는 양 플랫폼 동일. 결정: [[2026-06-17-macOS-네이티브-타깃-추가]].

## 관련 태스크 / 결정

- `[screen-01]`, `[screen-04]`, `[screen-09]`, `[screen-12]`, `[screen-16]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-네비게이션-UI구조]], [[2026-06-15-음성입력-STT-아키텍처]], [[2026-06-15-NL-추가-파서-FoundationModels]], [[2026-06-16-레시피-NL파서-ParsedRecipe]], [[2026-06-17-검색-랭킹-초성-편집거리]], [[2026-06-17-자연어-규칙-외부화]]

## 메모

- 코드: `HomePinApp/Sources/Features/Capture/CaptureSheet.swift`
- 검색 정교화(`screen-16`, `HomePinApp/Sources/Shared/Search/`):
  - `SearchRules.swift` — 조사·불용어·의미단어 규칙을 번들 `HomePinApp/Resources/SearchRules.json` 에서 1회 로드(누락 시 `preconditionFailure`).
  - `SearchRanking.swift` — `MatchTier`(exact/prefix/contains/choseong/fuzzy)·`SearchRank`·필드별 등급 계산.
  - `Hangul.swift` — 완성형 음절→초성 변환(유니코드 산술)·초성 질의 판별.
  - `Levenshtein.swift` — 음절 단위 2행 DP 편집거리·길이별 임계.
  - `RecentSearches.swift` — 최근 검색어 JSON 코덱(최신우선·중복제거·최대 8).
  - 직전 추가 위치 prefill 은 [[ItemEditor]](`@AppStorage("lastAreaID"/"lastSpotID")`)에서 처리.
- AI 자연어 추가:
  - 파서 엔진(추출만, 비-MainActor): `HomePinApp/Sources/Shared/AI/NLItemParser.swift`
  - 파싱 상태/세션 소유: `HomePinApp/Sources/Features/Capture/NLParseViewModel.swift`
  - 드래프트 상태: `HomePinApp/Sources/Features/Capture/AddDraft.swift`
  - 도메인 매칭/저장: `HomePinApp/Sources/Features/Capture/AddDraftResolver.swift`
  - 확인 화면(screen-09): `HomePinApp/Sources/Features/Capture/CaptureDraftReviewView.swift` ([[DraftReview]])
- 음성 입력기(actor 경계 분리, `HomePinApp/Sources/Shared/Speech/`):
  - UI 상태/세션 소유: `SpeechDictationViewModel.swift`
  - 권한/오디오/모델/변환: `SpeechDictationEngine.swift`
  - 이벤트 경계: `DictationEvent.swift`
- 잔여: 실기기 추론·한국어 품질 검증, 모델 다운로드 유도 UX. (find/add 의도 자동판별은 검색-우선 통합 UX 로 대체·불필요.)
