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

## 빌드 타깃 / 스킴

- **타깃 2개**(멀티플랫폼, 소스·리소스 한 벌 공유 — [[2026-06-17-macOS-네이티브-타깃-추가]]):
  - `HomePinApp` — iOS, `.iOS("26.5")`, bundleId `com.sro.homepinappios`.
  - `HomePinApp-macOS` — 네이티브 macOS, `.macOS("26.0")`, bundleId
    `com.sro.homepinappmac`, entitlements `Tuist/Support/HomePinApp-macOS.entitlements`
    (app-sandbox·files.user-selected.read-write·device.audio-input·CloudKit).
  - `HomePinApp` — iOS entitlements `Tuist/Support/HomePinApp-iOS.entitlements`
    (CloudKit).
- **스킴**: `automaticSchemesOptions` `targetSchemesGrouping: .notGrouped` 로 타깃별
  스킴 분리 → `HomePinApp`(iOS) / `HomePinApp-macOS`(macOS). 한 스킴에 묶으면
  (`.singleScheme`) macOS 빌드 시 iOS 타깃까지 끌려와 서명 오류가 나서 분리했다.
- 명령은 `docs/development.md` 참고.

## Sync / CloudKit

- `Features/Sync/CloudSyncPreference.swift` — iCloud sync 설정 키와 CloudKit container
  ID(`iCloud.com.sro.homepinapp`), Settings 계정 상태 확인 모델.
- `Persistence/AppModelContainer.swift` — `cloudSync.isEnabled` 가 켜져 있으면
  SwiftData `ModelConfiguration` 을 `.private("iCloud.com.sro.homepinapp")` 로 만들고,
  아니면 `.none` 으로 로컬 저장소만 사용한다.
- Settings 의 `iCloud Sync` 토글은 다음 앱 시작부터 CloudKit private DB 구성을 적용한다.
  가족 공유는 Phase B(`CKShare` 초대 기반)로 분리한다.

## 공용 / 플랫폼 추상화 (`Shared/`)

- `Shared/Platform/`(신규, [[2026-06-17-플랫폼-이미지-추상화]]):
  - `PlatformImage.swift` — `PlatformImage`(UIImage/NSImage) typealias + `from(data:)`·
    `platformCGImage`·`platformCGImageOrientation`(macOS `.up` 고정) + `Image(platformImage:)`.
  - `View+PlatformNav.swift` — iOS 전용 modifier 를 한 곳에서 분기(macOS no-op):
    `compactNavTitle`/`hideNavBar`/`plainTextInput`/`numericKeyboard`.
- `Shared/DesignSystem/Color+Hex.swift` — 동적 색 provider 를 UIColor/NSColor 로 분기.
- `Shared/OCR/CameraImagePicker.swift` — `CameraImagePicker`(`#if os(iOS)`) +
  `cameraCaptureCover` 헬퍼(macOS no-op). `TextRecognizer` 의 `CGImage`/orientation
  추출은 `PlatformImage` 로 이관.
- `Shared/Speech/SpeechDictationEngine.swift` — `AVAudioSession` 설정만 `#if os(iOS)`
  (macOS 는 세션 개념 없음, audio-input entitlement 로 마이크 접근).

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
