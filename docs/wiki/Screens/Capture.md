---
aliases: [Capture, NL 추가, 빠른 추가]
tags: [screen, screen/item]
created: 2026-06-12
updated: 2026-06-15
status: in-progress
screen-id: screen-01
---

# Capture (NL 추가 시트)

자연어 텍스트 또는 음성으로 물건을 빠르게 추가·검색하는 입력 시트. 탭바 중앙 🎤 슬롯에서 열린다. [추가 | 검색] 모드 토글 + 공용 음성 입력기를 제공한다. AI 파싱은 후속이며, 지금은 추가 입력 텍스트를 이름 draft 로 [[ItemEditor]] 에 넘긴다.

## 역할

- 텍스트 입력과 음성 받아쓰기(2-입력)를 제공한다. 음성은 텍스트를 채우는 입력기일 뿐, 텍스트 경로는 항상 살아 있어 음성 불가용 시 폴백된다.
- 추가 모드: 입력 텍스트를 이름 draft 로 삼아 [[ItemEditor]] 의 `create` 모드로 넘긴다.
- 검색 모드: `Item.normalizedName` 부분 일치로 결과를 보여주고, 결과 탭 시 [[ItemEditor]] `edit` 모드로 진입한다.

## 연결된 화면

- 들어옴 ←: 탭바 중앙 🎤 슬롯
- 이동 →: [[ItemEditor]] — 추가는 `create(initialName:)`, 검색 결과 탭은 `edit(item)`

## 사용 모델

- 읽기: [[Item]] (`@Query` 로 검색 대상 전체를 받아 정규화 키로 in-memory 필터).
- 쓰기 직접 없음. 저장은 [[ItemEditor]] 가 [[Item]] 으로 수행.

## 상태 관리

- 직결 읽기(`@Query allItems`) + 저장 위임. 비영속 UI 상태는 `@State` 로 보관 —
  모드 `mode`, 입력 `text`/`searchText`, 에디터 라우팅 `editorRoute`.
- 음성 입력은 얇은 `@Observable` 컨트롤러 `SpeechDictationViewModel` 을 `@State` 로
  보유한다(비영속 UI 상태 + 단일 세션 Task 소유). `dictation.transcript` 변화를
  `.onChange` 으로 받아 활성 모드 필드에 주입하고, 모드 전환·시트 종료 시 `reset()`.
  호출부 시그니처(`transcript`/`state`/`toggle()`/`reset()`)는 이전과 동일하다.
- 권한/오디오/모델 처리는 비-MainActor `SpeechDictationEngine` 으로 분리돼
  `DictationEvent` 스트림을 경계로 ViewModel 과 통신한다(actor 경계 분리). 시스템
  콜백을 MainActor 밖에서 만들어 격리 트랩을 피하고, 엔진 자원은 세션 Task cancel→
  스트림 종료 teardown 으로 정리한다.
- 녹음 중 오디오 인터럽션(전화·Siri·타 앱 점유) 시 엔진이 `AVAudioSession`
  `interruptionNotification` 을 구조적 동시성 AsyncSequence 로 감시하다가 `.began`
  에서 입력 스트림을 닫아 세션을 끝낸다. 스트림 자연 종료 경로로 ViewModel `state`
  가 `.idle` 로 복귀(마이크 버튼 stop 고착 해소)하고 transcript 누적분은 보존한다.
  `.ended` 에서 자동 재개하지 않으며 사용자가 마이크를 다시 눌러 재시작한다.

## 권한 / 받아쓰기 플로우

- `SpeechDictation` 이 마이크(`AVAudioApplication.requestRecordPermission`)와 음성
  인식(`SFSpeechRecognizer.requestAuthorization`) 권한을 순차 확보한다. 둘 다 허용 시
  iOS 26 `SpeechTranscriber`(ko-KR) + `SpeechAnalyzer` 온디바이스 받아쓰기를 구동.
- 모델 미설치 시 `AssetInventory` 로 확인/설치, 미지원·거부 시 `state` 를
  `.unavailable`/`.denied` 로 떨어뜨리고 시트는 안내 + 텍스트 폴백을 노출한다.
- Info.plist 권한 키(`NSMicrophoneUsageDescription`,
  `NSSpeechRecognitionUsageDescription`)는 `Project.swift` 에서 추가.

## 관련 태스크 / 결정

- `[screen-01]`, `[screen-04]` (docs/screen-implementation-tasks.md)
- 관련 결정: [[2026-06-12-네비게이션-UI구조]], [[2026-06-15-음성입력-STT-아키텍처]]

## 메모

- 코드: `HomePinApp/Sources/Features/Capture/CaptureSheet.swift`
- 음성 입력기(actor 경계 분리, `HomePinApp/Sources/Shared/Speech/`):
  - UI 상태/세션 소유: `SpeechDictationViewModel.swift`
  - 권한/오디오/모델/변환: `SpeechDictationEngine.swift`
  - 이벤트 경계: `DictationEvent.swift`
- 받아쓰기 텍스트를 AI 파서에 흘려 위치/수량/유통기한까지 structured draft 로
  채우는 것(텍스트·음성 공용 파서)이 후속.
