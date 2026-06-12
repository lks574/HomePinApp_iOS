---
description: HomePin iOS 하루치 세션(커밋+트랜스크립트) 정리·문서 갱신 (hpi:daily)
argument-hint: <선택: 대상 날짜 또는 비움(오늘 KST)>
---

먼저 `daily-extractor` 서브에이전트로 오늘 KST 트랜스크립트의 4종 후보(폐기한 접근·논의만 한 버그/리스크·미룬 결정·다음 작업 단서)를 격리 추출해. 그다음 `CLAUDE.md`의 `hpi:daily` 규약과 `docs/agents/daily.md`의 4단계 파이프라인·출력 매핑 표·라벨 규칙·검토 게이트를 따라 데일리 노트와 코드 문서 초안을 만든다. 자동 커밋·푸시는 하지 않고, 모든 문서 쓰기 전 사용자 확인을 받는다.

요청: $ARGUMENTS
