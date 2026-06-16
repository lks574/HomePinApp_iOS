---
aliases: [follow-ups, 후속 항목]
tags: [doc/code, followups]
created: 2026-06-12
updated: 2026-06-16
status: draft
---

# 후속 항목

리뷰 스코프 외 지적·검증 대기 항목을 누적한다.

## 데이터 / 영속화

- [ ] **이름 중복 방지(앱 로직)** — `@Attribute(.unique)` 는 upsert 의미라 사용자 입력
  이름엔 안 씀. 한 공간 내 구역명·한 구역 내 세부위치명·전역 카테고리/태그명 중복을
  **쓰기 로직에서 검증**해야 한다. (모델: [[Space]]/[[Area]]/[[Spot]]/[[ItemCategory]]/[[Tag]],
  결정: `docs/wiki/Decision/2026-06-12-위치-물건-데이터모델.md`)
- [ ] 첫 릴리스 시 `VersionedSchema`(`SchemaV1`) + `SchemaMigrationPlan` 도입
  (`AppModelContainer` 에 연결). 결정: `docs/wiki/Decision/2026-06-12-swiftdata-마이그레이션-방침.md`
- [ ] `Item.name` 직접 수정 경로 금지 — `ItemEditor` 는 `name` 변경 시
  `normalizedName` 을 함께 갱신한다. 향후 다른 쓰기 경로가 생기면 같은 규칙을 반드시
  적용해야 한다.

## UI 1차 이후 보류 (의도된 미구현)

UI 우선 1차(시안 C 화면 골격)에서 의도적으로 뒤로 미룬 것들.

- [x] **AI 자연어 파싱 연동 완료(1차)** — 추가 시트(`CaptureSheet`)가 입력 텍스트를
  온디바이스 Foundation Models 파서(`NLItemParser` `@Generable`)로 구조화하고 확인
  드래프트(`CaptureDraftReviewView`, screen-09)에서 다건 확인/수정 후 `AddDraftResolver`
  가 없으면생성/있으면매핑(`Item.normalize`)으로 일괄 저장. 가용성 게이트·실패·취소 시
  단건 스텁 폴백. (결정: `docs/wiki/Decision/2026-06-15-NL-추가-파서-FoundationModels.md`)
  잔여: 실기기 추론·한국어 품질 검증, 모델 다운로드 유도 UX, 유통기한·메모·find/add 의도.
- [x] **음성(STT) 입력기 연동 완료** — `SpeechDictation`(iOS 26 `SpeechAnalyzer` +
  `SpeechTranscriber` 온디바이스 받아쓰기)을 `CaptureSheet` 마이크 버튼에 실연동.
  받아쓰기 결과를 활성 모드 필드(추가=`text`, 검색=`searchText`)에 주입, 권한·불가용·
  거부 시 텍스트 폴백. (결정: `docs/wiki/Decision/2026-06-15-음성입력-STT-아키텍처.md`)
  잔여는 아래 3개 항목으로 분리.
- [x] **음성 → AI 파서 경로 재사용 완료** — 받아쓰기로 채운 텍스트가 타이핑 텍스트와
  같은 `CaptureSheet.add()` 파서 경로로 합류한다(추가 모드). 텍스트·음성 공용 단일 파서.
- [ ] **한국어 받아쓰기 모델 다운로드 UX** — 현재는 모델 미설치·미지원 시 `state`
  를 `.unavailable` 로 떨어뜨려 텍스트 폴백만 안내. 진행률·다운로드 동의 UI 미구현
  (`AssetInventory.assetInstallationRequest` 진행률 노출).
- [ ] **음성 입력 기기 게이팅** — `SpeechTranscriber.isAvailable`·로케일 지원으로
  마이크 진입 자체를 사전 차단/안내하는 게이팅은 미구현(현재는 시작 시점 판단).
- [ ] **음성 받아쓰기 실기기 검증** — actor 경계 분리 리팩터(`SpeechDictationViewModel`
  + `SpeechDictationEngine` ↔ `DictationEvent`) + 오디오 세션 인터럽션 처리(인터럽션
  `.began` 시 세션 종료 → `.idle` 복귀, transcript 보존, 자동 재개 없음) 후 빌드 green·
  시뮬레이터 불가용 폴백 경로(텍스트 입력)까지 확인. 실제 권한 프롬프트·한국어 모델
  다운로드·온디바이스 인식 정확도·녹음 중 재토글/모드전환 시 자원 정리·**인터럽션
  실동작(전화/Siri/타 앱 점유 시 마이크 버튼 `.idle` 복귀)** 은 시뮬레이터로 검증
  불가(인터럽션은 `.recording` 진입 전 시뮬레이터에서 빠짐) → 실기기 확인 필요.
  **무음 자동 종료(3초 텍스트 무변화 시 `stop()` 자동 종료, transcript 보존)** 도
  같은 이유로 시뮬레이터 인식 불가 → 실기기에서 발화 멈춤 후 3초 자동 종료·재무장
  (말 이어가면 안 끊김)·`.preparing`(모델 다운로드) 중 미종료 확인 필요.
- [ ] **검색 동작 미구현** — 홈/장소/레시피의 검색바는 정적 placeholder. 실제 필터·
  자연어 검색(`#Predicate`) 연결 필요.
- [ ] **물건 고급 편집·레시피 상세 화면 없음** — 물건 기본 추가/편집은 `ItemEditor`
  로 연결됨. 삭제, 카테고리·태그·사진, 레시피 카드 탭 상세는 미구현.
- [ ] **Pretendard 미번들** — 우선 시스템 폰트. 폰트 파일 번들 + 적용 필요.
- [ ] **비주얼 미세조정** — `음성 플로우` 시안은 컴포넌트 픽셀 미확인(개념 기준 구성).
  실기기 렌더 후 중앙 마이크 위치·탭바 여백·세이프에어리어 조정 필요.
- [ ] **NL 추가 파서 실기기 검증** — 빌드 green·시뮬레이터 폴백 경로(미가용 → 단건
  스텁 → `ItemEditor` 이름 prefill)·UI·매칭/저장 로직까지 시뮬레이터 검증 완료. 실제
  온디바이스 추론·한국어 추출 품질(다건 분리·수량·위치 grounding 정확도)·`@Generable`
  스키마 준수·확인 화면 신규/기존 매칭·다건 일괄 저장은 Apple Intelligence 가용 실기기
  필수(시뮬레이터 `availability` 미가용). 결정: `docs/wiki/Decision/2026-06-15-NL-추가-파서-FoundationModels.md`
- [ ] **Apple Intelligence 기기 게이팅 / 한국어 모델 다운로드 / fallback UX** — 미가용
  기기·언어 처리(텍스트·단건 폴백은 구조상 확보). 잔여: 모델 미설치 시 다운로드 동의·
  진행률 UI, 추가 진입 전 사전 게이팅 안내(현재는 `add()` 시점 가용성 판단).
- [ ] **Space 단일 가정** — UI 가 "장소"=Area 만 노출(단일 "우리집"). 멀티홈 필요 시
  Space 스위처 노출.
- [ ] **레시피 dish 필터 정적** — cuisine 필터만 동작, dish(국·찌개/볶음…) 필터는
  장식. 모델에 dish 분류 추가 여부 포함 검토.
- [ ] **홈 "장소 바로가기" 탭 동작 없음** — `HomeView.placeShortcuts` 가 단순
  `VStack`(배지+이름)이라 탭해도 [[PlaceDetail]] 로 이동하지 않는 죽은 상호작용.
  탭 시 해당 장소 상세로 진입 연결 필요(장소 탭 `NavigationStack` 경유 방법 검토).

## 다국어(i18n) 후속

i18n 1차(screen-10, en/ko 시스템 추종) 완료 후 남은 항목. 결정:
`docs/wiki/Decision/2026-06-16-i18n-다국어화-방침.md`.

- [ ] **STT 인식 locale 시스템 추종 검토** — `SpeechDictationEngine` 의 인식 locale 이
  `Locale("ko-KR")` 로 한국어 고정. 영어 사용자도 한국어 인식기로 받아쓰기된다.
  시스템 언어(en/ko)에 맞춰 인식 locale 을 고르고, 미지원 시 폴백 안내를 다듬어야 한다.
  (현재 i18n 범위 밖으로 분리. STT 권한·불가용·오류 표시 문구는 이미 현지화됨.)
- [ ] **영어 NL 추출 품질 검증** — `NLItemParser` 프롬프트·`@Guide` 가 한국어 문장
  추출 기준이라 영어 입력의 다건 분리·수량·위치 grounding 정확도가 미검증. 영어 입력
  품질 확인 후 필요 시 프롬프트를 언어별로 다루는 방안 검토(시뮬레이터 추론 불가 →
  Apple Intelligence 가용 실기기 필요).
