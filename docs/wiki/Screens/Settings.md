---
aliases: [Settings, 설정]
tags: [screen, screen/settings]
created: 2026-06-12
updated: 2026-06-17
status: in-progress
screen-id: screen-08
---

# Settings (설정)

표시(테마) · 데이터(현황·iCloud Sync·백업/가져오기·전체 정리) · 정보 3개 섹션의 설정 탭.

## 역할

- **표시**: 테마(시스템/라이트/다크) 선택. `@AppStorage` 로 저장, 루트에서
  `preferredColorScheme` 적용 → 앱 전체 반영. **언어**(시스템 따름/English/한국어)
  선택. `AppLanguagePreference` `@AppStorage` 로 저장, 루트에서 `.environment(\.locale)`
  적용 → 앱 재시작 없이 즉시 전환(시스템 따름이면 환경 locale 강제 안 함).
- **데이터**: 저장 현황(물건·장소·레시피 개수) 표시 + **iCloud Sync** 토글/계정
  상태 확인 + **백업/가져오기·CSV**([[DataTransfer]] push) + **전체 데이터 정리**
  (확인 다이얼로그 후 전 모델 일괄 삭제, 앱 동작 위해 기본 [[Space]] "우리집" 복구).
- **정보**: 버전(번들)·저장 위치·앱 소개 + 로컬 저장 안내.

## 연결된 화면

- 들어옴 ←: 탭바 (5-슬롯 중 설정 탭)
- 이동 →: [[DataTransfer]] — 데이터 섹션 `Backup & Import` `NavigationLink`

## 사용 모델

- [[Item]]·[[Area]]·[[Recipe]] — 읽기 `@Query`(저장 현황 개수)
- 전체 정리: [[ShoppingItem]]·[[Item]]·[[RecipeIngredient]]·[[Recipe]]·[[Spot]]·
  [[Area]]·[[ItemCategory]]·[[Tag]]·[[Space]] 를 `modelContext.delete(model:)` 로
  일괄 삭제(9종 = 백업 export 대상과 일치).

## 상태 관리

- 직결(View ↔ SwiftData) + 테마·언어·iCloud Sync 설정은 `@AppStorage`.
- 비영속 UI 상태: 전체 정리 확인 `showingClearConfirm`, iCloud 계정 상태 확인용
  `CloudSyncStatusModel`.

## 관련 태스크 / 결정

- `[screen-08]` (docs/screen-implementation-tasks.md)
- 테마/다크: [[2026-06-12-네비게이션-UI구조]] §3(디자인 토큰).
- 언어 선택: [[2026-06-16-i18n-다국어화-방침]] (시스템 추종 기본 + 설정 수동 오버라이드).
- 백업/CSV: [[2026-06-17-데이터-백업-번들포맷]], [[2026-06-17-CSV-대량입력-스키마]] (`[screen-15]`).
- CloudKit: [[2026-06-17-CloudKit-private-동기화-골격]] (`[screen-19]`).

## 메모

- 코드: `HomePinApp/Sources/Features/Settings/SettingsView.swift`,
  `App/AppRootView.swift`(테마·언어 적용), `Shared/DesignSystem/AppThemePreference.swift`,
  `Shared/DesignSystem/AppLanguagePreference.swift`,
  `Features/Sync/CloudSyncPreference.swift`
- 후속: CloudKit 실기기 동기화 검증, 가족공유 초대 UI, 유통기한 알림, AI/입력 토글.
