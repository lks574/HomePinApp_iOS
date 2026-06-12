---
aliases: [SwiftData 마이그레이션 방침, migration policy]
tags: [decision, decision/data]
created: 2026-06-12
updated: 2026-06-12
status: accepted
---

# 2026-06-12 SwiftData 마이그레이션 방침

로컬 전용 SwiftData 앱의 스키마 마이그레이션 방침. 프리릴리스(0.1.0) 시점, 실사용자
데이터 없음, 초기 스키마 churn 큼 — 단계를 나눠 운영한다.

## 결정

### ① 개발 단계 (지금 ~ 1.0 전): 파괴적 리셋

- **`VersionedSchema` 를 만들지 않는다.** 모델은 평범한 `@Model` 로 두고, 호환 안
  되는 변경이 나오면 로컬 스토어를 **지우고 재생성**한다(테스트 데이터뿐).
- **`ModelContainer` 생성을 한 곳(팩토리)으로 모은다** (예: `AppModelContainer`).
  스키마(모델 목록)·설정·리셋 로직을 여기 둔다 → 릴리스 때 버전드 전환이 1파일 수정.
- **dev 리셋 트리거**: `DEBUG` 빌드에서 `ModelContainer` init 이 스키마 불일치로
  실패하면 스토어 파일을 삭제하고 재생성한다. **릴리스 빌드에선 절대 자동 삭제하지
  않는다**(데이터 보호). 재빌드만으로 개발 계속.

### ② 첫 릴리스 (실사용자 데이터 발생) 시점: VersionedSchema 도입

- 그 시점 스키마를 **`SchemaV1` 으로 동결**한다.
- 이후 모든 스키마 변경 = 새 `VersionedSchema`(V2, V3 …) + `SchemaMigrationPlan`
  스테이지.
- **가능한 한 lightweight 스테이지** (필드 추가·옵셔널화·모델 추가는 자동). 데이터
  변환이 필요할 때만 **custom 스테이지**(`willMigrate`/`didMigrate`).
- 컨테이너 팩토리에서 `migrationPlan:` 만 연결하면 된다(①에서 한 곳에 모았으므로).

### ③ 처음부터 지키는 규칙 (미래 마이그레이션 비용 최소화)

- **가산적(additive) 변경 우선** — 새 필드는 옵셔널 또는 기본값. 그래야 대부분
  lightweight 로 끝난다.
- 필드 삭제·필수화·타입 변경은 신중히(custom 마이그레이션 유발).
- **이름 변경은 `@Attribute(originalName:)`** — 저장 컬럼은 유지하고 코드 식별자만
  바꿔 lightweight 를 유지한다(컬럼 rename 이 custom 으로 번지지 않게).

## 영향 / 후속

- 구현 시 `AppModelContainer` 팩토리 한 곳에 스키마·DEBUG 리셋·(추후) migrationPlan.
- 시드 데이터가 생기면 이 팩토리에서 최초 1회 주입 여부를 다룬다.
- 관련: [[2026-06-12-위치-물건-데이터모델]]
