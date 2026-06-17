---
aliases: [wiki, MOC, 위키 허브]
tags: [moc]
created: 2026-06-12
updated: 2026-06-18
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
- 탭: [[Home]] · [[Places]] · [[Capture]] (✨ AI) · [[Recipes]] · [[Settings]]
- [[Places]] → [[PlaceDetail]] → [[ItemEditor]]
- [[Places]] · [[PlaceDetail]] → [[PlaceEditor]] — 장소 추가/편집
- [[PlaceDetail]] → [[SpotEditor]] — 세부위치 추가/편집
- [[Home]] · [[Capture]] → [[ItemEditor]] — 물건 추가/편집 공용 에디터(AI 미가용·실패 폴백)
- [[Capture]] → [[DraftReview]] — AI 자연어 파싱 결과 확인 드래프트(다건 일괄 저장)
- [[Capture]] → [[RecipeDetail]] — AI 검색 레시피 결과 탭(레시피 탭 전환 + push)
- [[Capture]] → [[RecipeCapture]] → [[RecipeEditor]] — 레시피 자연어 추가(NL 입력 → AI 파싱 → prefill 확인)
- [[Home]] → [[Shopping]] — 장보기 요약 섹션 탭(살 것 추가·체크·삭제)
- [[Recipes]] → [[RecipeDetail]] → [[RecipeEditor]] — 레시피 상세·추가/편집
- [[Settings]] → iCloud Sync / Share Home Data — CloudKit private 동기화 설정·계정 상태 확인·가족공유 초대
- [[Settings]] → [[DataTransfer]] — 전체 백업/가져오기·CSV 대량 입력

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
- 장보기: [[ShoppingItem]] (살 것 체크리스트, 후속 [[RecipeIngredient]] 연동 훅)

## 결정 / 조사 / 아이디어

- 제품 방향: [[제품-방향-재고-레시피-AI]] `#idea`
- AI 적용 후보: [[AI-적용-후보]] `#idea`
- 레시피 간편 추가: [[레시피-간편-추가]] `#idea`
- 결정: [[2026-06-12-위치-물건-데이터모델]] · [[2026-06-12-식재료-모델-Item-통합]] · [[2026-06-12-swiftdata-마이그레이션-방침]] · [[2026-06-15-에디터-상태-소유-패턴]] · [[2026-06-15-음성입력-STT-아키텍처]] · [[2026-06-15-NL-추가-파서-FoundationModels]] · [[2026-06-16-장보기-데이터모델]] · [[2026-06-16-레시피-NL파서-ParsedRecipe]] · [[2026-06-17-데이터-백업-번들포맷]] · [[2026-06-17-CSV-대량입력-스키마]] · [[2026-06-17-자연어-규칙-외부화]] · [[2026-06-17-검색-랭킹-초성-편집거리]] · [[2026-06-17-CloudKit-private-동기화-골격]] · [[2026-06-18-CloudKit-가족공유-1차-스냅샷]]
- 외부 조사·자료: `Research/` `#research` — [[CloudKit-동기화-가족공유-도입검토]] (active)
- 임시 아이디어: `Idea/` `#idea`

## 연결 문서

- 코드 규칙·아키텍처: [[../../CLAUDE|CLAUDE.md]] · `docs/architecture.md`
- 화면 진도(단일 진실 소스): `docs/screen-implementation-tasks.md`
- 화면 맵: `docs/screen-map.md`
