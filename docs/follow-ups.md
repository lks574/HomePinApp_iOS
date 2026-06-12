---
aliases: [follow-ups, 후속 항목]
tags: [doc/code, followups]
created: 2026-06-12
updated: 2026-06-12
status: draft
---

# 후속 항목

리뷰 스코프 외 지적·검증 대기 항목을 누적한다.

## 열린 항목

- [ ] **이름 중복 방지(앱 로직)** — `@Attribute(.unique)` 는 upsert 의미라 사용자 입력
  이름엔 안 씀. 한 공간 내 구역명·한 구역 내 세부위치명·전역 카테고리/태그명 중복을
  **쓰기 로직에서 검증**해야 한다. (모델: [[Space]]/[[Area]]/[[Spot]]/[[ItemCategory]]/[[Tag]],
  결정: `docs/wiki/Decision/2026-06-12-위치-물건-데이터모델.md`)
- [ ] 첫 릴리스 시 `VersionedSchema`(`SchemaV1`) + `SchemaMigrationPlan` 도입
  (`AppModelContainer` 에 연결). 결정: `docs/wiki/Decision/2026-06-12-swiftdata-마이그레이션-방침.md`
