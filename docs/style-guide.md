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

- **1회만 쓰는 뷰는 별도 `struct` 로 추출하지 않는다.** 호출 지점에 인라인하거나,
  부모 `View` 의 `private` 계산 프로퍼티/함수(예: `private var fooCard: some View`,
  `private func fooRow(_:) -> some View`)로 둔다. 후자는 별도 타입·파라미터 전달 없이
  부모의 상태·헬퍼를 그대로 쓸 수 있어 더 단순하다.
- **2회 이상 재사용**되거나, **여러 파일에서 공용**으로 쓰면 `struct` 컴포넌트로
  분리한다. (공용 컴포넌트는 `Shared/DesignSystem/AppComponents.swift` 의 `App*`.)
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
