---
aliases: [notes-guide, 위키 규약]
tags: [moc, guide]
created: 2026-06-12
updated: 2026-06-12
status: stable
---

# 위키 노트 규약

이 위키는 **엔티티(화면·모델) 단위** 지식 지도다. 모든 노트는 아래 규약을 따른다.
규약·템플릿의 단일 기준은 이 문서다.

## 공통 frontmatter

모든 노트(코드 문서 포함)는 YAML frontmatter 를 갖는다.

```yaml
---
aliases: [영문명, 한글명]   # 위키링크 별칭 (예: [ItemEditor, 아이템 편집])
tags: [screen]             # 노트 유형 태그 (아래 참고)
created: 2026-06-12        # 생성일 (KST, 고정)
updated: 2026-06-12        # 마지막 갱신일 (변경 시 함께 수정)
status: planned            # planned | in-progress | done | stable | superseded
---
```

## 태그 체계

- `#screen` — 화면 노트. 도메인 하위태그 병기: `#screen/home`, `#screen/storage` 등.
- `#model` — SwiftData `@Model` 노트.
- `#decision` — 비가역 결정(ADR). `#decision/data`, `#decision/nav` 등.
- `#research` — 외부 조사·자료.
- `#idea` — 임시 아이디어.
- 보조: `#moc`(지도 노트), `#guide`.

## 링크 규약 (적극 사용)

- 다른 노트는 항상 `[[노트명]]` 위키링크로 잇는다(평문 나열 금지).
- **연결은 양방향으로 표기**한다 — 화면 A 가 화면 B 로 이동하면 A 의 "연결된 화면"
  과 B 의 "연결된 화면" 양쪽에 링크를 둔다. 화면↔모델도 마찬가지(화면의 "사용 모델"
  ↔ 모델의 "사용 화면").
- 화면 구현 태스크는 `[screen-XX]` ID 로 참조하고, 본문에서 해당 화면 노트로 링크.
- 별칭(`aliases`)을 활용해 한글 표기로도 `[[아이템 편집]]` 처럼 링크되게 한다.

## 파일 배치

```txt
docs/wiki/
  index.md            # MOC 허브
  notes-guide.md      # 이 문서
  Screens/<화면>.md    # 화면 노트 (#screen)
  Models/<모델>.md     # 모델 노트 (#model)
  Decision/<날짜-제목>.md   # ADR (#decision)
  Research/<제목>.md   # 조사 (#research)
  Idea/<제목>.md       # 아이디어 (#idea)
  */_template.md      # 각 유형 템플릿 (복사해서 시작)
```

## 템플릿

### 화면 (`Screens/_template.md`)

생성일·역할·연결된 화면·사용 모델·관련 태스크를 담는다. 새 화면을 만든 `developer`
가 코드와 함께 생성·갱신한다.

### 모델 (`Models/_template.md`)

생성일·역할·보유 데이터·`@Relationship` 관계·사용 화면을 담는다.

각 폴더의 `_template.md` 를 복사해 새 노트를 시작한다. `created` 는 생성일로 고정하고,
이후 변경 때 `updated` 만 바꾼다.
