---
aliases: [DataTransfer, 백업/가져오기, 데이터 전송]
tags: [screen, screen/settings]
created: 2026-06-17
updated: 2026-06-17
status: in-progress
screen-id: screen-15
---

# DataTransfer (백업/가져오기·CSV)

전체 데이터 백업/가져오기와 CSV 대량 입력을 한 화면에서 다룬다.
[[Settings]] 데이터 섹션의 `Backup & Import` 행에서 push 로 진입한다.

## 역할

- **전체 백업 export**: 9개 `@Model` 전체 + 아이템 사진을 디렉터리 패키지
  (`.homepinbackup`)로 내보낸다. `fileExporter` 시스템 modal 로 저장 위치를 고른다.
- **전체 백업 import**: `fileImporter` 로 고른 패키지를 읽어 id(UUID) 기준
  **2-pass upsert** 으로 병합/덮어쓴다. schemaVersion 가드, 엔티티 단위 실패 스킵,
  결과 요약 표시.
- **CSV 대량 입력**: [[Item]]·[[Recipe]] 를 3개 CSV(`items.csv`·`recipes.csv`·
  `recipe_ingredients.csv`)로 가져온다. 각 CSV 템플릿 export 제공. 행 단위 실패
  스킵 + 결과 요약.

## 연결된 화면

- 들어옴 ←: [[Settings]] — 데이터 섹션 `Backup & Import` `NavigationLink`
- 이동 →: 없음(시스템 `fileExporter`/`fileImporter` modal 만)

## 사용 모델

전체 백업은 9종 전부 읽기(export)·쓰기(import)한다. CSV 는 Item·Recipe 중심.

- [[Item]]·[[ShoppingItem]] — `normalizedName` 동반 갱신, `stockCredited` 보존(쓰기)
- [[Space]]·[[Area]]·[[Spot]]·[[ItemCategory]]·[[Tag]] — 백업 복원·CSV 이름 조회→생성(쓰기)
- [[Recipe]]·[[RecipeIngredient]] — 백업/CSV 복원(쓰기). 불변식 `spot→area` 강제.

## 상태 관리

- 얇은 `@Observable` `DataTransferModel`. 두 조건 모두 충족해 정당:
  1. 비영속 UI 상태 — 파일 선택/진행/결과(`DataTransferStatus`)·시트 표시 플래그.
  2. 다단계 쓰기 오케스트레이션 — 백업 2-pass upsert(`BackupUpsertEngine`)·CSV
     다단계 import(`CSVImporter`).
- 실제 영속 쓰기·파일 I/O 는 `BackupArchive`·`BackupUpsertEngine`·`CSVImporter`
  (모두 `@MainActor`)에 위임. 사용자 데이터 텍스트는 `Text(verbatim:)`.

## 다국어(i18n)

[[2026-06-16-i18n-다국어화-방침|i18n 방침]] 적용(en/ko). UI 텍스트는
`Localizable.xcstrings`(source=en) 자동 현지화, `String` 타입 상태/결과/에러 메시지
(`DataTransferStatus`·`ImportSummary.headline`·`BackupArchive.ArchiveError`)는
`String(localized:)` 로 해소. 사용자 데이터(물건명·메모·레시피 내용)는 비대상
(`Text(verbatim:)`). 패키지 타입 설명 `HomePin Backup` 은 `InfoPlist.xcstrings` 로
현지화.

## 관련 태스크 / 결정

- `[screen-15]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-17-데이터-백업-번들포맷]], [[2026-06-17-CSV-대량입력-스키마]]

## 메모

- 외부 의존성 없음(`FileManager` 만). 디렉터리 패키지 UTType 은 `Project.swift`
  `UTExportedTypeDeclarations` 에 선언(iOS `com.sro.homepinappios.backup` / macOS
  `com.sro.homepinappmac.backup`, 둘 다 `.homepinbackup`).
- **macOS 분기(screen-17)**: 파일 Import/Export 는 sandbox
  entitlement `files.user-selected.read-write` 로 동작(`fileExporter`/`fileImporter`
  공통 코드, 분기 없음). 결정: [[2026-06-17-macOS-네이티브-타깃-추가]]. 실기 검증은
  follow-up(AC-005).
- 잔여(`docs/follow-ups.md`): 사진 downsampling/압축, `VersionedSchema` 연동,
  macOS 파일 Import/Export 실기 검증(AC-005).
