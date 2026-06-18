---
aliases: [DraftReview, 확인 드래프트, AI 추가 확인]
tags: [screen, screen/item]
created: 2026-06-15
updated: 2026-06-18
status: removed
screen-id: screen-09
---

# DraftReview (확인 드래프트)

> [!warning] 제거됨 (2026-06-18)
> [[Capture]] 의 물건 추가 경로가 규칙 기반 `ItemQuickAddParser → ItemEditor.create(initialName:)` 로 교체되면서, 이 화면과 물건 AI NL 파서 플로우는 어떤 live View 에서도 도달되지 않는 self-contained island 로 남아 코드·문서에서 제거되었다. 삭제된 코드: `NLParseViewModel`·`CaptureDraftReviewView`·`AddDraftResolver`·`AddDraft`·`DraftTaxonomyPickerSheets`·`Shared/AI/NLItemParser`(`ParsedItemList`/`ParsedItem`/`NLParseGrounding` 포함). 결정 supersede: [[2026-06-15-NL-추가-파서-FoundationModels]]. 레시피 NL 파서([[RecipeCapture]])·STT 는 영향 없음. 아래는 제거 시점의 설계 기록(historical)으로만 보존한다.

AI 자연어 파서([[Capture]] 의 `NLParseViewModel`)가 뽑은 추가 물건 목록을 사용자가 확인·수정·삭제한 뒤 일괄 저장하는 push 화면. [[Capture]] 가 소유하며(`navigationDestination`), 자동 저장 대신 **확인 단계를 필수 안전망**으로 둔다(소형 모델 오인식 방어).

## 역할

- 파서가 추출한 다건 물건을 항목 카드로 보여준다 — 이름·수량·장소(구역)·세부위치·분류·태그.
- 각 항목을 인라인 수정(이름/수량 편집, 장소·세부위치 피커로 교체)·삭제할 수 있다.
- **신규 vs 기존 매칭을 시각 구분**한다 — 기존 엔티티에 매칭되면 일반 칩, 이번에 새로 만들어질 이름은 ‘신규’ 칩(테라코타)으로 표시.
- 앱 위치 규칙(최소 Area 소속): 장소가 빈 항목은 채워야 저장 가능. 저장 버튼은 모든 항목이 `canSave` 일 때만 활성.
- 저장 시 다건 일괄 insert + 신규 위치/분류/태그 생성을 `AddDraftResolver` 에 위임하고, 완료되면 시트 전체를 dismiss.

## 연결된 화면

- 들어옴 ←: [[Capture]] — AI 파싱 성공(`parser.state == .drafts`) 시 push.
- 피커 시트: `AreaPickerSheet`/`SpotPickerSheet`([[ItemEditor]] 와 공용) — 기존 장소/세부위치로 교체.
- 저장 완료 → [[Capture]] 시트 dismiss.

## 사용 모델

- 읽기: [[Area]] (`@Query` 로 장소 피커 후보), 매칭 후보는 `AddDraftResolver` 가 [[Space]]/[[Area]]/[[Spot]]/[[ItemCategory]]/[[Tag]] 에서 수집.
- 쓰기: [[Item]] 다건 insert + 신규 [[Area]]/[[Spot]]/[[ItemCategory]]/[[Tag]] 생성(`AddDraftResolver.save`). 위치 불변식 `spot.area == area` 유지, 같은 신규 이름은 세션 내 1회만 생성.

## 상태 관리

- 비영속 UI 상태(저장 전 draft)는 항목당 얇은 `@Observable` `AddDraft` 가 소유(이름·수량·`NameMatch` 매칭). 화면은 `@State drafts: [AddDraft]` 로 배열을 보유하고 행 삭제·인라인 편집을 직접 반영.
- `NameMatch<Model>` 열거형으로 신규(`.new(이름)`)/기존(`.existing(엔티티)`)을 표현 — 화면 시각 구분과 저장 분기를 둘 다 이 한 값으로 처리.
- 도메인 매칭/생성(여러 `@Model` 트랜잭션)은 화면이 아니라 `AddDraftResolver`(도메인 경계)가 전담. 화면은 확인/편집 + 저장 트리거만 한다.

## 관련 태스크 / 결정

- `[screen-09]`, `[screen-04]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-15-NL-추가-파서-FoundationModels]]

## 메모

- 코드: `HomePinApp/Sources/Features/Capture/CaptureDraftReviewView.swift`
- 드래프트 상태: `AddDraft.swift` (`NameMatch` 포함)
- 매칭/저장: `AddDraftResolver.swift` (`match`/`newMatch` 는 인라인 편집 시트가 재사용하도록 `internal`)
- 분류·태그 인라인 편집: `DraftTaxonomyPickerSheets.swift`(`DraftCategoryPickerSheet`·`DraftTagPickerSheet`). insert 없이 `NameMatch` 만 갱신 — 생성·연결은 저장 시 `AddDraftResolver.save` 전담. 값이 비어도 분류·태그 행을 항상 노출(편집 진입), 태그 칩별 제거(x)·“+ Tag” 추가 칩. 자유 입력이 grounding 과 정규화 일치하면 `.existing`(일반칩), 불일치면 `.new`(테라코타 ‘New’ 칩).
- AI 자동추론 억제: 파서(`NLItemParser`)가 분류·태그를 용도 추론으로 지어내지 않고 문장에 단서가 있을 때만 채운다. grounding 후보도 단서가 있을 때만 매칭. 입력 언어 무관 적용. (결정 보강: [[2026-06-15-NL-추가-파서-FoundationModels]])
- 잔여: 유통기한·메모, 실기기 추론·한국어 품질 검증.
