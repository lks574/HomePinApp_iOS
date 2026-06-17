---
aliases: [CloudKit 동기화·가족공유 검토, iCloud 동기화, 가족공유]
tags: [research, decision/data]
created: 2026-06-17
updated: 2026-06-17
status: active
---

# CloudKit 동기화·가족공유 도입 검토

> `feat/icloud-sync` 브랜치에서 착수 검토 중. 실제 CloudKit capability 적용 전에는
> 데이터 모델 호환화와 iCloud container 확정이 먼저 필요하다. 동기화·공유는
> persistence 구조를 바꾸는 비가역 결정이므로 Decision 노트 승격 후 구현한다.

## 요약

- 목표: **같은 사용자가 아이폰 ↔ 맥에서 같은 데이터**를 보고, 나아가 **가족 구성원이
  데이터를 공유**한다.
- 수단은 둘 다 **CloudKit** (Apple 서버리스 백엔드). 자체 서버는 두지 않는다 →
  "서버 없이" 라는 기존 아키텍처 철학과는 부합하나, **persistence·동기화 구조를 바꾸는
  비가역 결정**이다.
- **전제: 유료 Apple Developer Program($99/년) 필수.** iCloud/CloudKit entitlement 는
  무료(personal team) 계정으로 활성화 불가.
- **선행 필수: 데이터 모델 개편.** 기존 10개 `@Model` 전부가 `id` 에 `.unique` 를
  선언해 CloudKit 동기화 제약을 위반했다. "CloudKit 켜기"가 아니라 **스키마 마이그레이션이
  본체**다.

## 2026-06-17 착수 메모

- 작업 브랜치: `feat/icloud-sync` (`feat/admob` HEAD 에서 분기).
- 사용자 목표:
  1. Settings 에서 iCloud 동기화를 켤 수 있게 한다.
  2. iCloud 공유를 통해 가족에게 데이터를 공유할 수 있게 한다.
- 구현 해석:
  - Settings 의 버튼은 "즉시 한 번 동기화"가 아니라 **iCloud sync 활성화/상태/안내**
    진입점으로 설계한다. SwiftData + CloudKit 은 `ModelContainer` 구성이 동기화 경로를
    결정하고, 실제 sync 는 시스템이 자동 수행한다.
  - 가족 공유는 Apple 가족 그룹 자동 연동이 아니라 **CloudKit `CKShare` 초대 기반 공유**
    로 다룬다.
- 현재 코드 확인:
  - `AppModelContainer` 는 로컬 `ModelConfiguration(schema:isStoredInMemoryOnly:)` 만 사용한다.
  - iOS 타깃에는 entitlements 파일이 없고, macOS entitlements 는 sandbox/file/audio 권한만
    있다.
  - 모든 영속 모델의 `id` `.unique` 제거가 CloudKit 호환 마이그레이션의 첫 작업이다.

## 범위 (2단계로 분리)

### Phase A — Private 동기화 (1인, 아이폰 ↔ 맥)
- SwiftData ↔ CloudKit **Private DB** 통합:
  `ModelConfiguration(..., cloudKitDatabase: .private("iCloud.<container>"))`.
- iOS·macOS 두 타깃에 iCloud capability + CloudKit 컨테이너 + 백그라운드(원격 알림)
  entitlement 추가. ([[2026-06-17-macOS-네이티브-타깃-추가]] 로 macOS 타깃은 이미 존재 →
  entitlements 확장.)
- 난이도: **중** (SwiftData 가 기본 지원하는, 비교적 닦인 경로).

### Phase B — 가족공유 (가족 구성원이 같은 데이터)
- CloudKit **Shared DB / `CKShare`**: 구성원은 각자 iCloud 계정, 데이터는 공유 zone 에
  두고 **초대 기반**으로 참여.
- ⚠️ SwiftData 의 CKShare 지원은 private 동기화보다 미성숙 → 공유 초대 UI·참여자
  관리·권한은 CloudKit API 로 직접 내려가야 하는 부분이 큼.
- ⚠️ Apple "가족 공유 그룹" 과 CloudKit 공유는 **자동 연동되지 않는다.** "내 가족과
  공유" 토글 같은 건 없고, 공유는 초대로 이뤄진다.
- 난이도: **상** (구조·UI 모두 추가 작업 큼). Phase A 안정화 후 별도 착수 권장.

## 선행 필수: 데이터 모델 개편

CloudKit 동기화(NSPersistentCloudKitContainer 계열) 제약과 현재 모델의 충돌:

| 현재 (`HomePinApp/Sources/Models/`) | CloudKit 제약 | 조치 |
| --- | --- | --- |
| 전 모델 `@Attribute(.unique) var id: UUID` (Item·Area·Space·Spot·Recipe·RecipeIngredient·ItemCategory·Tag·ShoppingItem 등) | **`.unique` 제약 미지원** | `.unique` 제거. 유일성은 앱 로직으로 보장. 중복 이름 합치기([screen-16]) 로직과 연동 재점검 |
| `#Index<Item>([\.name],[\.normalizedName],[\.expiresAt])` | 인덱스 제약 비호환 가능 | 재검토/제거 후 검색 성능 영향 확인 ([[2026-06-17-검색-랭킹-초성-편집거리]]) |
| 비옵셔널 속성 다수 | **기본값 또는 optional 필수** | 전 속성 감사 |
| 관계 (`@Relationship` inverse 보유) | **모든 관계 optional + inverse 필수** | optional 보장 점검. `.cascade`/`.nullify` 는 허용, `.deny` 금지 |
| `@Attribute(.externalStorage) photoData` (Item) | CKAsset 매핑(동기화 비용·용량↑) | 사진 동기화 정책 결정(동기화 제외 옵션 포함) |

> 관련 마이그레이션 방침: [[2026-06-12-swiftdata-마이그레이션-방침]].
> `.unique` 제거는 무료 계정·로컬 상태에서도 **미리 진행 가능**(전환 비용 선납).

## 영향

- 영향받는 모델: 전 `@Model` (Item·Area·Space·Spot·Recipe·RecipeIngredient·RecipeStep·
  ItemCategory·Tag·ShoppingItem).
- 영향받는 화면: 전 목록·상세·편집 화면(동기화 상태·충돌 처리 UI 추가 여지),
  특히 추가/합치기([screen-16])·백업([[2026-06-17-데이터-백업-번들포맷]]).
- 백업 기능과의 관계: 로컬 `.homepinbackup` 수동 백업은 그대로 유지(오프라인·내보내기
  용도). CloudKit 은 "실시간 동기화", 백업은 "스냅샷 이전" 으로 역할 분리.

## 대안 / 비고 (무료 계정으로 가능한 우회)

- **iCloud 기기 백업**: 앱 데이터(기본 컨테이너의 SwiftData store)는 OS iCloud Backup 에
  자동 포함 → 재설치·기기 이전 시 복원. **개발자 계정·entitlement 불필요.** 단 "여러
  기기 동시 사용 / 가족 공유" 는 불가(복원 전용).
- **수동 백업파일을 iCloud Drive 에 저장**: 현재 `fileExporter` 로 사용자가 저장 위치를
  iCloud Drive 로 선택 가능. 무료. 단 자동 동기화 아님.
- → 위 둘은 "능동적 실시간 동기화 + 가족 공유" 요구를 충족하지 못하므로, 본 목표에는
  CloudKit(유료) 이 불가피.

## 착수 전 체크리스트

1. [ ] 유료 Apple Developer Program 가입
2. [ ] hpi:plan 으로 Phase A/B 분리 기획 + Decision 노트 승격(데이터모델·동기화 비가역)
3. [ ] 모델 CloudKit 호환 마이그레이션(`.unique` 제거 등) — 무료 상태에서 선행 가능
4. [ ] iCloud 컨테이너 생성·iOS/macOS entitlement 확장
5. [ ] Phase A(private) 구현·검증 → 안정화 후 Phase B(가족공유) 착수

## 적용

- 관련 결정: [[2026-06-12-swiftdata-마이그레이션-방침]],
  [[2026-06-17-데이터-백업-번들포맷]], [[2026-06-17-macOS-네이티브-타깃-추가]]
- 상태: **draft (보류)** — 확정·착수 시 Decision 노트로 승격하고 status 갱신.
