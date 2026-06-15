---
aliases: [next-task, 다음 할 일]
tags: [doc/code, tasks]
created: 2026-06-12
updated: 2026-06-15
status: draft
---

# 다음 할 일

UI 우선 1차(시안 C 화면 골격: 5탭·장소·레시피·홈·추가 시트) 완료 후의 다음 후보.
보류 상세는 `docs/follow-ups.md`.

## 다음 후보 (우선순위순 제안)

1. **AI 자연어 추가** — Foundation Models `@Generable` 로 문장 → 구조화 드래프트
   (물건·장소·수량·분류). 기존 위치/카테고리 grounding, 확인 단계, 없으면생성/있으면매핑.
   `CaptureSheet` 에 연결. (제품 방향: [[제품-방향-재고-레시피-AI]])
2. **검색 동작** — 중앙 버튼 시트 [추가 | 검색] 모드 토글로 1차 완료(`screen-04`):
   `Item.normalizedName` 부분 일치 → 결과에 위치 경로, 결과 탭 시 `ItemEditor` 편집.
   잔여: 홈/장소/레시피 검색바 실연동, 자연어 검색 확장.
3. **음성 입력(STT)** — 입력기 완료(`SpeechDictation`: iOS 26 `SpeechAnalyzer` +
   `SpeechTranscriber` 온디바이스 받아쓰기 → 활성 모드 필드, 마이크 버튼 실연동,
   권한·불가용·거부 폴백). 잔여: 1번 AI 파서 경로 재사용(받아쓰기 텍스트 → 구조화),
   기기/모델 게이팅·한국어 모델 다운로드 UX(현재는 불가용 시 텍스트 폴백).
4. **물건/레시피 고급 편집** — 물건 추가/편집/삭제는 `ItemEditor` 로 연결됨.
   레시피 상세(`screen-03`)·CRUD(`screen-07`)·시드 10개 완료 — 카드 → `RecipeDetail`,
   "레시피 추가" → `RecipeEditor`, 재료/단계 동적 편집 + 재료 이름→보유 물건 매칭.
   남은 범위는 물건 카테고리·태그·사진, 레시피 cuisine 분류/dish 칩 실제 필터.
   (장소 CRUD `screen-05`·세부위치 CRUD `screen-06` 완료 — 추가/편집은 `PlaceEditor`/`SpotEditor`, 삭제는 확인 다이얼로그.)
   장소/세부위치 에디터 확장(아이콘·Space 선택), 정렬 변경(drag) 이 후속.
5. **기기 게이팅 + 한국어/폴백** — AI 미지원 환경 처리.

## 진행 메모

- 빌드 검증: `tuist generate` → `xcodebuild ... -scheme HomePinApp`.
- 테스트는 후반 단계(`CLAUDE.md` "테스트 정책").
