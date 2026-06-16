---
aliases: [next-task, 다음 할 일]
tags: [doc/code, tasks]
created: 2026-06-12
updated: 2026-06-16
status: draft
---

# 다음 할 일

UI 우선 1차(시안 C 화면 골격: 5탭·장소·레시피·홈·추가 시트) 완료 후의 다음 후보.
보류 상세는 `docs/follow-ups.md`.

> 최근 완료: **설정 언어 선택(screen-08/10)** — 시스템 추종 기본 + 설정 > 표시 > 언어에서
> 시스템/English/한국어 수동 오버라이드. `AppLanguagePreference`(`@AppStorage`, 테마
> 선례) + 루트 `AppRootView` `.environment(\.locale)` 즉시 전환(재시작 불필요, ko-KR
> 시스템에서 English 강제·그 반대 모두 런타임 확인). ADR(언어 선택 UI 없음 → 수동
> 오버라이드 허용)·screen tasks·Settings 노트 갱신.
> 이전: **다국어(i18n, screen-10)** — 영어/한국어 + 시스템 언어 추종(기본 en).
> UI 텍스트 String Catalog, 권한 문구 InfoPlist 카탈로그, cuisine/dishType 저장값 유지·
> 표시만 매핑, 시드 언어 분기(`SeedText`). 잔여는 `docs/follow-ups.md` "다국어(i18n) 후속"
> (STT 인식 locale 시스템 추종, 영어 NL 추출 품질). 결정:
> `docs/wiki/Decision/2026-06-16-i18n-다국어화-방침.md`.

## 다음 후보 (우선순위순 제안)

1. **AI 자연어 추가** — 1차 구현 완료(screen-09). Foundation Models `@Generable`
   (`NLItemParser`, 추출만·비-MainActor) → `NLParseViewModel`(@MainActor, 가용성
   게이트·단일 세션 Task) → 확인 드래프트(`CaptureDraftReviewView`) → `AddDraftResolver`
   다건 저장(grounding·없으면생성/있으면매핑·`Item.normalize` 매칭). `CaptureSheet.add()`
   가 가용 시 파싱→확인, 미가용·실패·취소 시 단건 스텁 폴백. 텍스트·음성 공용 단일 경로.
   잔여: 실기기 추론·한국어 품질 검증(시뮬레이터 미가용), 모델 다운로드 유도 UX(#5),
   유통기한·메모·find/add 의도판별은 후속. (제품 방향: [[제품-방향-재고-레시피-AI]],
   결정: [[2026-06-15-NL-추가-파서-FoundationModels]])
2. **검색 동작** — 중앙 버튼 시트 [추가 | 검색] 모드 토글로 1차 완료(`screen-04`):
   `Item.normalizedName` 부분 일치 → 결과에 위치 경로, 결과 탭 시 `ItemEditor` 편집.
   잔여: 홈/장소/레시피 검색바 실연동, 자연어 검색 확장.
3. **음성 입력(STT)** — 입력기 완료 + actor 경계 분리 리팩터 완료
   (`SpeechDictationViewModel`(UI 상태/단일 세션 Task) + `SpeechDictationEngine`
   (비-MainActor 권한/오디오/모델) ↔ `DictationEvent` 스트림 경계. iOS 26
   `SpeechAnalyzer` + `SpeechTranscriber` 온디바이스 받아쓰기 → 활성 모드 필드,
   권한·불가용·거부 폴백, tap 버퍼 복사·고아 자원 누수 버그 해소). 잔여: 1번 AI 파서
   경로 재사용(받아쓰기 텍스트 → 구조화), 기기/모델 게이팅·한국어 모델 다운로드 UX,
   실기기 인식 정확도 검증(시뮬레이터 불가).
4. **물건/레시피 고급 편집** — 물건 추가/편집/삭제는 `ItemEditor` 로 연결됨.
   레시피 상세(`screen-03`)·CRUD(`screen-07`)·시드 10개 완료 — 카드 → `RecipeDetail`,
   "레시피 추가" → `RecipeEditor`, 재료/단계 동적 편집 + 재료 이름→보유 물건 매칭.
   남은 범위는 물건 카테고리·태그·사진, 레시피 cuisine 분류/dish 칩 실제 필터.
   (장소 CRUD `screen-05`·세부위치 CRUD `screen-06` 완료 — 추가/편집은 `PlaceEditor`/`SpotEditor`, 삭제는 확인 다이얼로그.)
   장소/세부위치 에디터 확장(아이콘·Space 선택), 정렬 변경(drag) 이 후속.
5. **기기 게이팅 + 한국어/폴백** — AI 미지원 환경 처리. NL 추가 파서의 가용성 게이트
   (`SystemLanguageModel.default.availability`)·단건 스텁 폴백은 #1 에서 구현됨. 잔여는
   한국어 모델 다운로드/Apple Intelligence 미설치 유도 UX(진행률·동의), 시작 전 사전
   게이팅(마이크/추가 진입 시 미가용 사전 안내), 실기기 한국어 인식·추론 정확도 검증.

## 진행 메모

- 빌드 검증: `tuist generate` → `xcodebuild ... -scheme HomePinApp`.
- 테스트는 후반 단계(`CLAUDE.md` "테스트 정책").
