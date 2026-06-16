---
aliases: [레시피 OCR, Vision OCR, 사진 레시피 추가, 스크린샷 레시피]
tags: [decision, decision/data]
created: 2026-06-16
updated: 2026-06-16
status: accepted
---

# 2026-06-16 레시피 OCR — 온디바이스 Vision (사진·카메라)

[[RecipeCapture]] 입력 화면에 **사진/스크린샷 OCR 입력 소스**를 더하는 비가역 결정
(OCR 프레임워크 + 권한 + 텍스트 합류 방식 + 인식 언어). [[레시피-간편-추가]] 아이디어
§Phase 2(입력 소스 #3 사진·#4 스크린샷)를 구체화한다. 코어/확인/저장은
[[2026-06-16-레시피-NL파서-ParsedRecipe]] 의 텍스트 경로를 그대로 재사용하고, OCR 은
"텍스트를 얻는 또 하나의 방법" 만 더한다(중복 구현 없음).

## 맥락

레시피는 요리책·메모(촬영)·블로그/메신저 스크린샷(사진 라이브러리)에 텍스트로 흔히
존재한다. 이 텍스트를 손으로 다시 옮기는 마찰을 줄이려면 이미지→텍스트 추출이 필요하다.
이미 단계 1 에서 `여러 줄 텍스트 입력 → "Sort with AI" 파싱 → 확인 에디터` 경로가 있어,
OCR 은 그 입력 필드를 채우기만 하면 합류한다. 서버 없는 로컬 앱(서버리스 원칙)이므로
온디바이스 OCR 이어야 한다. 인식 언어·권한·자동 파싱 여부는 되돌리기 어려운 표면이라
확정이 필요했다.

## 결정

1. **온디바이스 Apple Vision (`VNRecognizeTextRequest`) 채택.** `recognitionLevel = .accurate`,
   `usesLanguageCorrection = true`, `recognitionLanguages = ["ko-KR", "en-US"]`(한국어+영어).
   - `ImageAnalyzer`/`DataScannerViewController`(라이브 스캐너) 대신 Vision 을 고른 이유:
     이번 용례는 "고른 정지 이미지 한 장에서 텍스트를 뽑는다" 이고, Vision 은 인식 언어·
     레벨·언어교정을 직접 제어할 수 있어 `CGImage`(사진/카메라 공통)에 그대로 맞는다.
   - 네트워크/서버 호출 없음. 인식은 무거운 동기 추론이라 비-MainActor(`Task.detached`)에서
     수행하고 결과 문자열만 MainActor 로 가져온다.
2. **카메라 + 사진 라이브러리 둘 다 진입(D3).** 카메라 즉석 촬영(요리책·메모) +
   사진 라이브러리(스크린샷·기존 사진). 카메라는 `UIImagePickerController`(`.camera`)
   래퍼, 사진은 SwiftUI 네이티브 `PhotosPicker`. 카메라는 시뮬레이터 미지원이라
   `UIImagePickerController.isSourceTypeAvailable(.camera)` 로 가용할 때만 노출한다.
3. **권한 신규 (비가역).** `Project.swift` `infoPlist` 에 `NSCameraUsageDescription`·
   `NSPhotoLibraryUsageDescription` 추가, 문구는 `InfoPlist.xcstrings`(en source + ko)
   로 현지화(마이크/음성 권한 선례). 권한 추가 후 `tuist generate` 재실행.
   - 권한 거부 시 graceful: 시스템 시트/`PhotosPicker` 가 직접 안내하고, 텍스트 입력
     경로는 항상 살아 있어 폴백된다.
4. **OCR 결과는 입력 필드에 채울 뿐, 자동 파싱·자동 저장 안 함.** 기존 입력이 있으면
   개행으로 append, 비어 있으면 그대로 채운다. 사용자가 보고 고친 뒤 "Sort with AI" 로
   파싱한다 — OCR 인식은 부정확할 수 있으니 확인 단계를 유지한다.

## 구현 메모

- `TextRecognizer`(`Shared/OCR/`, `Sendable` 값 타입, 비-MainActor): 이미지→텍스트.
  관찰 박스 세로 위치로 정렬해 읽기 순서 복원, 줄바꿈 보존. 회전 메타데이터(카메라
  사진) 대비 `UIImage.imageOrientation → CGImagePropertyOrientation` 변환.
- `RecipeOCRViewModel`(@MainActor @Observable): 인식 상태(idle/recognizing/recognized/
  failed/empty) + 단일 세션 Task 소유/cancel([[Capture]] STT/파서 패턴 동일). 결과는
  `recognizedText` 일회성 채널로 emit, 호출 측이 `.onChange` 으로 받아 채운 뒤 비운다.
- `CameraImagePicker`(`Shared/OCR/`): `UIImagePickerController` 래퍼. 델리게이트
  콜백은 메인 큐 보장이 약해 `@MainActor` 타입 안에 두면 런타임 격리 트랩으로 크래시날
  수 있으므로, `Coordinator` 를 nonisolated `NSObject` 로 분리하고 콜백 안에서만
  `Task { @MainActor in }` 으로 hop 한다([[2026-06-15-음성입력-STT-아키텍처]] 의 시스템
  콜백 격리 분리 원칙과 같은 결).

## 영향 / 폴백

- 코어/확인/저장 경로 변경 없음. `@Model` 스키마 변경 없음(신규는 비영속 처리뿐).
- 텍스트 입력은 항상 폴백: 권한 거부·OCR 실패·빈 결과 모두 현지화 안내 + 직접 입력 유지.
- 카메라 실기기 촬영·한국어/손글씨 OCR 품질은 시뮬레이터로 검증 불가 → follow-up.

## 대안 (기각)

- **라이브 스캐너(`DataScannerViewController`)**: 실시간 화면 위 텍스트 인식에 강하나,
  사진 라이브러리 정지 이미지·스크린샷에는 부적합. 인식 언어·레벨 제어도 Vision 이 명확.
- **OCR 결과 자동 파싱·자동 저장**: 인식 오류가 그대로 저장 오염으로 이어진다. 확인
  단계 유지 원칙([[2026-06-16-레시피-NL파서-ParsedRecipe]])과 충돌해 기각.
