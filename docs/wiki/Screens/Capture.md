---
aliases: [Capture, NL 추가, 빠른 추가]
tags: [screen, screen/item]
created: 2026-06-12
updated: 2026-06-15
status: in-progress
screen-id: screen-01
---

# Capture (NL 추가 시트)

자연어 텍스트(후속: 음성)로 물건을 빠르게 추가하는 입력 시트. 탭바 중앙 🎤 슬롯에서 열린다. UI 우선이라 STT/AI 파싱은 후속이며, 지금은 입력 텍스트를 이름 draft 로 [[ItemEditor]] 에 넘긴다.

## 역할

- 텍스트 입력과 음성 진입 버튼(2-입력)을 제공한다.
- 입력한 텍스트를 이름 draft 로 삼아 [[ItemEditor]] 의 `create` 모드로 넘긴다.
- 사용자가 위치/수량 등을 확인·보정한 뒤 저장한다.

## 연결된 화면

- 들어옴 ←: 탭바 중앙 🎤 슬롯
- 이동 →: [[ItemEditor]] — 텍스트 확인 후 `create(initialName:)` 모드

## 사용 모델

- 직접 읽기/쓰기 없음. 저장은 [[ItemEditor]] 가 [[Item]] 으로 수행.

## 상태 관리

- 직결 없음(저장 위임). 비영속 UI 상태만 `@State` 로 보관 — 입력 `text`,
  마이크 힌트 `showMicHint`, 에디터 라우팅 `editorRoute`.

## 관련 태스크 / 결정

- `[screen-01]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-네비게이션-UI구조]]

## 메모

- 코드: `HomePinApp/Sources/Features/Capture/CaptureSheet.swift`
- 음성(STT)·AI 파싱으로 위치/수량/유통기한까지 structured draft 채우는 것이 후속.
