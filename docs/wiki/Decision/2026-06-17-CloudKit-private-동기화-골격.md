---
aliases: [CloudKit private 동기화 골격, iCloud Sync]
tags: [decision, decision/data]
created: 2026-06-17
updated: 2026-06-17
status: accepted
---

# 2026-06-17 CloudKit private 동기화 골격

## 맥락

사용자가 Settings 에서 iCloud 동기화를 켜고, 이후 가족에게 데이터를 공유할 수 있기를
요청했다. 기존 로컬 SwiftData 구조는 서버 없이 기기 내부 저장이 기본이지만, iPhone ↔ Mac
동기화와 가족 공유는 CloudKit 이 필요하다.

## 결정

- CloudKit 도입은 **Phase A private 동기화 → Phase B 공유**로 나눈다.
- Phase A 에서 SwiftData `ModelConfiguration` 의 `cloudKitDatabase` 를 설정한다.
  - 기본값은 `.none`.
  - Settings 의 `iCloud Sync` 토글이 켜진 다음 앱 시작부터
    `.private("iCloud.com.sro.homepinapp")` 를 사용한다.
- Settings 토글은 “즉시 수동 동기화”가 아니라 **동기화 저장소 사용 여부를 켜는
  설정**이다. SwiftData + CloudKit 의 실제 업로드/다운로드 타이밍은 시스템이 관리한다.
- iCloud 계정 상태 확인은 Settings 에서 `CKContainer.accountStatus()` 로 제공한다.
- iOS/macOS 양 타깃에 CloudKit container entitlement 를 둔다.
  - iOS 는 `UIBackgroundModes = remote-notification` 도 추가한다.
  - macOS 는 iCloud entitlement 때문에 일반 실행 빌드에 Apple Development 서명이 필요하다.
    서명 없는 컴파일 검증은 `CODE_SIGNING_ALLOWED=NO` 로 수행한다.

## 선행 정리

- 전 `@Model` 의 `id` `.unique` 제약 제거.
- CloudKit 호환을 위해 to-many 관계를 optional 관계(`[T]?`)로 전환.

## 가족 공유

가족 공유는 Phase A 안정화 후 별도 구현한다. Apple 가족 그룹 자동 연동이 아니라 CloudKit
`CKShare` 초대 기반 공유로 다룬다.

## 검증

- `tuist generate`
- iOS simulator build: green
- macOS compile build: green with `CODE_SIGNING_ALLOWED=NO`
- macOS signed build: 개발 서명 설정 전에는 iCloud entitlement 때문에 실패 가능

## 관련

- [[CloudKit-동기화-가족공유-도입검토]]
- [[2026-06-12-swiftdata-마이그레이션-방침]]
- [[2026-06-17-macOS-네이티브-타깃-추가]]
