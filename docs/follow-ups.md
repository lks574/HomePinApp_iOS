---
aliases: [follow-ups, 후속 항목]
tags: [doc/code, followups]
created: 2026-06-12
updated: 2026-06-12
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

- [ ] **AI 자연어 파싱 미연동** — 추가 시트(`CaptureSheet`)는 텍스트를 이름 draft 로
  `ItemEditor` 에 넘기는 스텁. Foundation Models `@Generable` 로 물건·장소·분류 추출 +
  확인 드래프트 + 없으면생성/있으면매핑은 미구현. (제품 방향: [[제품-방향-재고-레시피-AI]])
- [ ] **음성(STT) 미연동** — 마이크 버튼은 안내만 표시. SpeechAnalyzer/받아쓰기 →
  텍스트 → 같은 파서 경로 필요. (텍스트+음성 2-입력, 음성 v1 결정)
- [ ] **검색 동작 미구현** — 홈/장소/레시피의 검색바는 정적 placeholder. 실제 필터·
  자연어 검색(`#Predicate`) 연결 필요.
- [ ] **물건 고급 편집·레시피 상세 화면 없음** — 물건 기본 추가/편집은 `ItemEditor`
  로 연결됨. 삭제, 카테고리·태그·사진, 레시피 카드 탭 상세는 미구현.
- [ ] **Pretendard 미번들** — 우선 시스템 폰트. 폰트 파일 번들 + 적용 필요.
- [ ] **비주얼 미세조정** — `음성 플로우` 시안은 컴포넌트 픽셀 미확인(개념 기준 구성).
  실기기 렌더 후 중앙 마이크 위치·탭바 여백·세이프에어리어 조정 필요.
- [ ] **Apple Intelligence 기기 게이팅 / 한국어 지원 / fallback UX** — AI 연동 시
  미지원 기기·언어 처리(텍스트 폴백은 구조상 확보).
- [ ] **Space 단일 가정** — UI 가 "장소"=Area 만 노출(단일 "우리집"). 멀티홈 필요 시
  Space 스위처 노출.
- [ ] **레시피 dish 필터 정적** — cuisine 필터만 동작, dish(국·찌개/볶음…) 필터는
  장식. 모델에 dish 분류 추가 여부 포함 검토.
