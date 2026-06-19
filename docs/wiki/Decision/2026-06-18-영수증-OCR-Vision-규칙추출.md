---
aliases: [영수증 OCR, 영수증 스캔, receipt OCR, Vision 영수증, 영수증 품목 추출]
tags: [decision, decision/data, decision/screen]
created: 2026-06-18
updated: 2026-06-18
status: removed
---

# 2026-06-18 영수증 OCR — 카메라 권한 재추가 + Vision OCR + 규칙 필터 (screen-22)

> [!warning] 영수증 스캔 기능 제거됨(규칙 포맷 한계·LLM OCR 깨짐/게이팅 비용) — 2026-06-18.
> 아래 결정은 이력 보존용이며 더 이상 코드에 반영되지 않는다. screen-22 코드·권한·UI 키는 전부 제거됐다(screen-21 스타터 템플릿·칩 staging 코어는 유지).

> [[Capture]] 물건 추가에 **영수증 스캔 입력 어댑터**를 더한다. 카메라/사진으로 받은
> 영수증 이미지를 온디바이스 Vision 으로 읽고, **보수적 규칙 필터**로 품목명 후보만
> 추려 칩 staging 으로 합류시킨다. 영수증 이미지는 저장하지 않는다. FoundationModels 는
> 쓰지 않는다(확정). 새 화면·신규 `@Model` 을 만들지 않는다.

## 맥락

- 장 본 직후 영수증을 한 장 찍으면 여러 물건을 한 번에 재고로 넣을 수 있다 — 텍스트/
  음성/템플릿에 이은 또 하나의 **입력 어댑터**다. 출력은 [[2026-06-18-area-생략-캡처-허용-및-멀티-추가]]
  의 칩 staging 코어(`ItemBulkAddModel`)로 합류한다.
- 레시피 OCR([[2026-06-16-레시피-OCR-VisionKit]])이 동일한 **Vision + 카메라/사진 권한**
  패턴을 썼다. 그러나 그 레시피 사진/카메라 OCR 코드(`RecipeOCRViewModel`·`TextRecognizer`·
  `CameraImagePicker`·권한 문구)는 이후 **제거됐다**(레시피는 텍스트/음성만, screen-13
  removed). 따라서 이번엔 그 ADR 의 **권한·Vision·비-MainActor 패턴을 계승하되 코드는
  현재 상태에서 신규로 재추가**한다(과거 코드 부활이 아님).

## 결정

### 1. 권한 재추가 (비가역) + tuist generate

- `Project.swift` `sharedInfoPlist` 에 `NSCameraUsageDescription`·
  `NSPhotoLibraryUsageDescription` 추가, 문구는 `InfoPlist.xcstrings`(en source + ko)
  현지화. **추가 후 `tuist generate` 재실행** 필수(Info.plist 는 manifest 생성물).
- 권한은 양 플랫폼 공유 Info.plist 에 두되, 카메라 UI 는 iOS 만 노출한다(아래 6).

### 2. OCR 엔진 = 온디바이스 Vision (Sendable, 비-MainActor)

- `Shared/OCR/ReceiptTextRecognizer`(Sendable) — `VNRecognizeTextRequest`,
  `recognitionLevel = .accurate`, `usesLanguageCorrection = true`,
  `recognitionLanguages = ["ko-KR", "en-US"]`. `canImport(Vision)` 가드.
- 인식은 무거운 추론이라 비-MainActor(`Task.detached`)에서 수행하고 **텍스트만 MainActor**
  로 가져온다. **영수증 이미지는 영속화하지 않는다**(인식 입력으로만 쓰고 버린다).
- **FoundationModels 는 안 쓴다(확정)** — 영수증 라인 정리는 결정론적 규칙 필터로 충분하고,
  온디바이스 LLM 의 비용·표류·가용성 게이팅을 피한다.

### 3. 카메라 래퍼 (격리 트랩 회피)

- `Shared/OCR/CameraImagePicker`(`#if os(iOS)`) — `UIImagePickerController(.camera)`
  SwiftUI 래퍼. Coordinator 는 **nonisolated NSObject 로 분리**하고, delegate 콜백
  안에서만 `Task { @MainActor in }` 으로 hop 한다. `@MainActor` 타입 안에 시스템 콜백
  클로저를 두면 런타임 격리 트랩으로 크래시하는 함정을 피한다(프로젝트에 기록된 트랩).

### 4. 상태 모델

- `ReceiptScanViewModel`(@MainActor @Observable) — `idle`/`recognizing`/`recognized`/
  `empty`/`failed` + 단일 인식 Task 소유·cancel(STT·기존 OCR VM 의 "단일 소비 Task"
  생명주기). OCR + 필터는 `Task.detached` 비-MainActor, 결과(텍스트)만 MainActor.

### 5. 라인 필터 = 보수적 규칙 (과추론 금지)

- `Shared/OCR/ReceiptLineFilter` — OCR 줄 단위로:
  (1) 숫자·통화기호·합계 키워드(합계/소계/부가세/총액/total/subtotal 등)만 있는 줄,
  (2) 날짜/시간, (3) 사업자번호·전화·카드승인 패턴, (4) 줄 끝 가격(`숫자원`/`₩숫자`)을
  제거한 뒤 글자 신호가 남는 줄을 품목명 후보로 본다 → `ItemQuickAddParser.parse(multiline:)`
  통과. **상호/주소 정교 분류는 하지 않는다**(애매하면 통과 → 사용자가 칩에서 지운다).
- **추출 0건/실패 → 빈 staging + "품목을 찾지 못했어요, 직접 추가하세요" 안내 폴백**
  (크래시·차단 없음).

### 6. 진입점 + macOS

- [[Capture]] bulk `adapterRow` 의 "Scan receipt" 버튼(iOS) → `ReceiptScanSheet`.
  `UIImagePickerController.isSourceTypeAvailable(.camera)` 게이팅(시뮬레이터는 카메라
  숨김) + `PhotosPicker` 폴백. 카메라 권한 거부는 graceful(시스템 시트, 사진/수동 경로
  유지). OCR 결과 라인은 `bulkModel.appendChips(from:)` 로 칩 합류.
- **macOS**: ③는 iOS 우선. 카메라/UIImagePicker 는 `#if os(iOS)` 로 비노출, macOS 는
  `PhotosPicker`(NSImage→CGImage) 만. 신규 카메라 entitlement 는 iOS 만. macOS 영수증
  UX 는 follow-up.

## 영향

- 신규: `Shared/OCR/`(`ReceiptTextRecognizer`·`ReceiptLineFilter`·`CameraImagePicker`·
  `ReceiptScanViewModel`), `Features/Capture/ReceiptScanSheet`,
  `CaptureSheet.InitialMode.receiptScan` + adapterRow. 권한 2종(en/ko).
- 무변경: `Item` 스키마/모델, 칩 staging 코어(`ItemBulkAddModel`·`bulkInsert` 불변식).
- 화면 노트: [[Capture]]. 관련 결정: [[2026-06-16-레시피-OCR-VisionKit]](권한·Vision
  패턴 계승, 단 그 코드는 제거됨), [[2026-06-18-area-생략-캡처-허용-및-멀티-추가]],
  [[2026-06-18-스타터-템플릿-칩합류]].
