---
aliases: [wiki, MOC, 위키 허브]
tags: [moc]
created: 2026-06-12
updated: 2026-06-12
status: stable
---

# HomePin iOS 위키

이 vault 는 앱의 **구조 지식 지도**다. 시간 기반 데일리/주간 노트는 두지 않고,
**화면·모델 단위 노트**로 "무엇이 언제 생겼고, 무슨 역할이며, 무엇과 연결되는지" 를
기록한다. 링크(`[[..]]`)와 태그(`#screen`/`#model`/...)를 적극 써서 그래프 뷰에서
앱 구조가 한눈에 보이게 한다.

규약·템플릿은 [[notes-guide]] 를 단일 기준으로 한다.

## 화면 `#screen`

각 화면 노트는 `Screens/` 에 둔다. 새 화면을 만들면 [[notes-guide]] 의 화면 템플릿으로
노트를 생성한다.

```dataview
TABLE status, created, file.outlinks AS "연결"
FROM #screen
SORT created ASC
```
<!-- Dataview 플러그인이 없으면 위 블록은 무시된다. 수동 목록은 아래에 둔다. -->

- [[Splash]] → [[Home]] (루트 흐름)

## 모델 `#model`

각 SwiftData `@Model` 노트는 `Models/` 에 둔다.

```dataview
TABLE status, created
FROM #model
SORT created ASC
```

- 위치: [[Space]] ⊃ [[Area]] ⊃ [[Spot]]
- 물건: [[Item]] — 분류 [[ItemCategory]] · 태그 [[Tag]]
- 레시피: [[Recipe]] ⊃ [[RecipeIngredient]] (재고 [[Item]] 매칭)

## 결정 / 조사 / 아이디어

- 제품 방향: [[제품-방향-재고-레시피-AI]] `#idea`
- 결정: [[2026-06-12-위치-물건-데이터모델]] · [[2026-06-12-식재료-모델-Item-통합]] · [[2026-06-12-swiftdata-마이그레이션-방침]]
- 외부 조사·자료: `Research/` `#research`
- 임시 아이디어: `Idea/` `#idea`

## 연결 문서

- 코드 규칙·아키텍처: [[../../CLAUDE|CLAUDE.md]] · `docs/architecture.md`
- 화면 진도(단일 진실 소스): `docs/screen-implementation-tasks.md`
- 화면 맵: `docs/screen-map.md`
