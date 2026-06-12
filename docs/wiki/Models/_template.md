---
aliases: [ModelName, 모델 한글명]
tags: [model]
created: 2026-06-12
updated: 2026-06-12
status: planned
---

# ModelName (모델 한글명)

> 이 파일은 템플릿이다. 복사해서 `Models/<ModelName>.md` 로 새 노트를 만든다.

## 역할

이 `@Model` 이 무엇을 표현하는지 1~3문장. (도메인에서의 의미.)

## 보유 데이터

주요 프로퍼티와 의미. 매크로 사용(`@Attribute`/`@Transient` 등)도 표기.

| 프로퍼티 | 타입 | 비고 (매크로·제약) |
| --- | --- | --- |
| `id` | `UUID` | `@Attribute(.unique)` |
| ... | ... | ... |

## 관계 (`@Relationship`)

- → [[OtherModel]] — `deleteRule: .cascade` / `.nullify`, to-one/to-many, inverse

## 사용 화면

이 모델을 읽거나 쓰는 화면. 양방향으로 표기한다.

- [[ScreenName]] — 읽기 / 쓰기

## 관련 결정

- [[Decision/...]] — 이 모델 구조에 영향을 준 결정

## 메모

- 자유 메모.
