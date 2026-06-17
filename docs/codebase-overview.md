---
aliases: [codebase-overview, 코드베이스 개요]
tags: [doc/code, overview]
created: 2026-06-12
updated: 2026-06-17
status: draft
---

# 코드베이스 개요

> [!note] 작성 예정 (placeholder)
> 코드가 생기면 빌드·구조·Feature·Dependency·위젯·테스트 전체 지도를 작성한다.

## Feature 모듈 메모 (점증 기록)

- `Features/DataTransfer/` — 전체 데이터 백업/가져오기 + CSV 대량 입력(screen-15).
  - `BackupDTO.swift` — 9 `@Model` 대응 Codable DTO(관계 UUID 참조, `RecipeStep` 인라인, 사진 `photoFile` 경로 참조) + `BackupBundle`(schemaVersion 메타).
  - `BackupCodec.swift` — 모델→DTO 변환 + JSON 인코더/디코더(ISO8601) + 패키지 레이아웃 상수(`BackupBundleLayout`).
  - `BackupUpsertEngine.swift` — id 기준 2-pass upsert(pass-1 필드, pass-2 관계). 불변식·normalizedName·stockCredited 강제.
  - `BackupArchive.swift` — 디렉터리 패키지(`.homepinbackup`) export/import I/O(`FileManager` 만, 외부 의존성 없음) + schemaVersion 가드 + 사진 복원.
  - `CSV.swift` — RFC4180 최소 자체 파서/직렬화(따옴표·콤마·개행 이스케이프).
  - `CSVSchema.swift` — `items.csv`·`recipes.csv`·`recipe_ingredients.csv` 컬럼 정의 + 템플릿.
  - `CSVImporter.swift` — CSV→`@Model` upsert(id/normalizedName/title 키, 이름 조회→없으면 생성 캐시, 행 단위 스킵).
  - `DataTransferResult.swift` — `ImportSummary`/`ExportSummary`/`DataTransferStatus`.
  - `BackupDocument.swift` — `fileExporter` 용 `FileDocument`(백업 패키지 `FileWrapper(url:)` · CSV 텍스트).
  - `DataTransferModel.swift` — 얇은 `@Observable` 오케스트레이션(비영속 UI 상태 + 다단계 쓰기) + `UTType.homePinBackup`.
  - `DataTransferView.swift` — `Settings > Data > Backup & Import` push 화면(`fileExporter`/`fileImporter` + 결과 요약).
  - 진입: `Features/Settings/SettingsView.swift` 데이터 섹션 `NavigationLink`.
