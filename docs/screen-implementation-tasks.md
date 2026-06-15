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

## 후속 후보

- `screen-03` RecipeDetail — 레시피 재료/단계/보유 표시.
- `screen-04` 검색 결과 — 홈/장소/레시피 검색바 실제 필터 및 위치 경로 결과.
- 장소 에디터 확장 — 아이콘·Space(공간) 선택. (현재는 이름만, Space 는 첫 공간 자동 배정)
