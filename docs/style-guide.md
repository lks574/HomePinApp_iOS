---
aliases: [style-guide, 스타일 가이드]
tags: [doc/code, style]
created: 2026-06-12
updated: 2026-06-15
status: draft
---

# 스타일 가이드

Swift/SwiftUI 스타일은 Airbnb Swift Style Guide 를 기본으로 따른다. 아래는 이
프로젝트에서 추가로 합의한 컨벤션이다.

## SwiftUI 컴포넌트 분리 (과분리 금지)

UI 를 작은 컴포넌트로 **과도하게 쪼개지 않는다.** 분리는 비용(정의로 점프해야
읽힘, 파라미터·클로저 전달)이 있으므로, 그 비용을 정당화할 때만 분리한다.

**기준 — 사용 횟수로 판단한다.**

- **1회만 쓰는 뷰는 별도 `struct` 로 추출하지 않는다.** `struct` 추출은 비용이
  크다(별도 타입, `@Binding`·focus 등 파라미터 전달, 정의로 점프, 부모 상태 직접
  접근 불가). 호출 지점에 인라인하거나, 부모 `View` 의 `private` 멤버로 둔다.
- **같은 `View` 안의 `private` 계산 프로퍼티/함수로 `body` 를 이름 붙여 분해하는
  것은 1회용이어도 허용**한다(가독성 도구, 비용 작음). 단 **단위는 "섹션"**으로
  맞춘다 — `body` 가 직접 조합하는 카드/영역(예: `basicInfoCard`, `headerRow`).
- **한 섹션 안에서만 쓰는 1회용 "잎(leaf) 행" 은 별도 멤버로 빼지 말고 그 섹션에
  인라인**한다(예: `basicInfoCard` 안의 수량 행). `body` 분해 ≠ 모든 작은 행을
  멤버로 만들기.
- **2회 이상 재사용**되거나(예: `AppEditorSelectionRow` 2회), **여러 파일에서
  공용**(`Shared/DesignSystem/Components/` 의 `App*`)이거나, **리스트
  아이템 뷰**(`ForEach` 행, 예: `placeCard`·`recipeSoonCard`)면 `private func`·
  `struct` 로 둔다.
- **의미상 독립적인 화면**(예: `.sheet` 로 띄우는 picker, 자체 `NavigationStack`·
  `dismiss` 보유)은 1회만 써도 별도 타입으로 둔다.

**예시.**

- `ItemEditorView` 의 `AppEditorTextField`(1회) → 인라인. `AppEditorSelectionRow`
  (2회)·`appEditorCard`(3회) → 유지.
- `RecipesView` 의 `RecipeSoonCard`·`RecipeCompactRow`·`FlowChips`(각 1회) →
  부모의 `private` 멤버/인라인으로 접음. `PlacesListView` 의 `PlaceCard`(1회) → 동일.
- `AreaPickerSheet`·`SpotPickerSheet` 는 1회지만 독립 시트라 유지.

> 요점: "재사용 또는 독립성" 이 있을 때만 컴포넌트를 만든다. 1회용 래퍼는
> 인라인이 더 읽기 쉽다.

## 디자인 토큰

색·타이포·표면 스타일은 `Shared/DesignSystem` 의 토큰을 쓰고, 화면에 원시값을
흩지 않는다.

- **색**: `AppColor` (`AppTheme.swift`). `Color(hex:)` 를 화면에 직접 쓰지 않는다.
- **타이포**: `Font` 토큰 (`AppTheme.swift`, `.appScreenTitle`·`.appRowLabel`·
  `.appBadge` 등). **2회 이상 반복되는 역할만 토큰화**하고, 1회용 크기(splash 등)는
  원시 `.system(size:)` 로 둔다(과토큰화 방지). 토큰 값은 기존 스펙과 1:1.
- **표면/컴포넌트**: `appCard`·`appEditorSaveBar` 모디파이어, `App*` 컴포넌트
  (`Shared/DesignSystem/Components/` — 역할별 파일: `Buttons`·`Chips`·`SearchBar`·
  `Badge`·`SectionTitle`·`Banner`·`EditorComponents`).
- 새 반복 패턴(색·폰트·뷰)이 **2회 이상** 생기면 토큰/컴포넌트로 올린다(위 분리 기준).
