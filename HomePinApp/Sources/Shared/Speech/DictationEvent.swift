import Foundation

/// 받아쓰기 엔진(`SpeechDictationEngine`)이 단일 소비 Task 로 흘려 보내는 이벤트.
///
/// 엔진은 권한/모델/오디오/변환 같은 비-MainActor 작업을 수행하고, UI 가 해석할 수 있는
/// 의미 단위만 이벤트로 emit 한다. ViewModel(`SpeechDictationViewModel`)이 이 스트림을
/// 소비해 `State`/`transcript` 로 매핑한다. 음성은 텍스트를 채우는 입력기일 뿐이라,
/// `permissionDenied`/`unavailable` 은 항상 텍스트 폴백으로 이어진다.
enum DictationEvent: Sendable {
  /// 권한·모델 준비 시작(녹음 직전).
  case preparing
  /// 오디오 엔진이 떠서 실제 받아쓰기 중.
  case recording
  /// 부분(volatile) 인식 결과. 다음 partial/final 로 대체된다.
  case partialTranscript(String)
  /// 확정(finalized) 인식 결과. 누적된다.
  case finalTranscript(String)
  /// 마이크 또는 음성 인식 권한이 거부됨. ViewModel 이 `.denied` 로 매핑한다.
  case permissionDenied
  /// 기기/모델/시뮬레이터 등으로 받아쓰기를 사용할 수 없음. ViewModel 이
  /// `.unavailable(reason:)` 로 매핑한다.
  case unavailable(reason: String)
}
