---
aliases: [next-task, 다음 할 일]
tags: [doc/code, tasks]
created: 2026-06-12
updated: 2026-06-12
status: draft
---

# 다음 할 일

UI 우선 1차(시안 C 화면 골격: 5탭·장소·레시피·홈·추가 시트) 완료 후의 다음 후보.
보류 상세는 `docs/follow-ups.md`.

## 다음 후보 (우선순위순 제안)

1. **AI 자연어 추가** — Foundation Models `@Generable` 로 문장 → 구조화 드래프트
   (물건·장소·수량·분류). 기존 위치/카테고리 grounding, 확인 단계, 없으면생성/있으면매핑.
   `CaptureSheet` 에 연결. (제품 방향: [[제품-방향-재고-레시피-AI]])
2. **검색 동작** — 홈/장소/레시피 검색바를 실제 필터로. `Item.normalizedName` 기반
   이름 검색 → 결과에 위치 경로. (이후 자연어 검색으로 확장)
3. **음성 입력(STT)** — SpeechAnalyzer/받아쓰기 → 텍스트 → 1번 파서 경로 재사용.
   마이크 버튼 실연동.
4. **물건 상세 / 레시피 상세** — 장소 상세 행·레시피 카드 탭 → 상세(수정·이동·삭제,
   레시피 재료/단계/보유 표시).
5. **기기 게이팅 + 한국어/폴백** — AI 미지원 환경 처리.

## 진행 메모

- 빌드 검증: `tuist generate` → `xcodebuild ... -scheme HomePinApp`.
- 테스트는 후반 단계(`CLAUDE.md` "테스트 정책").
