---
aliases: [screen-tasks, 화면 구현 태스크]
tags: [doc/code, screens, tasks]
created: 2026-06-12
updated: 2026-06-15
status: draft
---

# 화면 구현 태스크

화면별 구현 진도(단일 진실 소스)를 `screen-XX` ID로 관리한다.

| ID | 화면 | 상태 | 메모 |
| --- | --- | --- | --- |
| screen-01 | 시안 C 5탭 셸·홈·장소·레시피·추가 시트 | done | UI 우선 1차. 검색/AI/STT는 후속. |
| screen-02 | ItemEditor | in-progress | 물건 추가/편집 공용 에디터. 이름·수량·장소·세부위치·유통기한·메모 지원. |
| screen-05 | PlaceEditor (장소 CRUD) | in-progress | 장소(Area) 추가/편집 공용 에디터 + 목록·상세에서 삭제(확인). 삭제 시 Spot cascade, 물건은 nullify 보존. |
| screen-06 | SpotEditor (세부위치 CRUD) | in-progress | 세부위치(Spot) 추가/편집 공용 에디터 + 상세에서 삭제(확인). 추가·편집은 상세 ⋯/카드 메뉴, 삭제 시 물건은 nullify 로 ‘수납공간 미지정’ 이동. |
| screen-03 | RecipeDetail (레시피 상세) | in-progress | 레시피 카드 → 상세 push. 헤더(메타·요약)·재고 요약·재료 목록(보유/임박/없음 칩)·조리 단계. 상단 ⋯ 로 편집/삭제(확인). |
| screen-07 | RecipeEditor (레시피 CRUD) | in-progress | 레시피 추가/편집 공용 시트 + 상세에서 삭제. 기본정보(제목·종류·인분·시간·요약) + 재료/단계 동적 행 편집. 저장 시 재료 이름→보유 물건 매칭으로 재고 상태 연동. |
| screen-08 | Settings (설정 고도화) | in-progress | 표시(테마 시스템/라이트/다크, `@AppStorage`+`preferredColorScheme`) · 데이터(저장 현황 + 전체 데이터 정리, 기본 Space 복구) · 정보. 다크는 디자인 토큰 라이트/다크 동적화로 앱 전체 적용. |
| screen-04 | 검색 (중앙 시트) | in-progress | 중앙 버튼 시트에 [추가 \| 검색] 모드 토글 + 공용 음성 입력(받아쓰기→활성 모드 필드, STT 후속). 검색은 `Item.normalizedName` 부분 일치 → 결과에 위치 경로, 결과 탭 시 `ItemEditor` 편집 진입. 홈/장소/레시피 검색바 실연동·자연어 검색은 후속. |

## 후속 후보

- `screen-04` 검색 결과(잔여) — 홈/장소/레시피 검색바 실제 필터 연동, 자연어 검색 확장.
- 장소/세부위치 에디터 확장 — 아이콘·Space(공간) 선택. (현재는 이름만, Space 는 첫 공간 자동 배정)
