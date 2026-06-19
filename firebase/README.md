# Firebase RemoteConfig 템플릿

앱 버전 게이트(`VersionGateService`)가 읽는 RemoteConfig 파라미터 템플릿이다.
Firebase 프로젝트: `homepin-1c94d` (iOS `com.sro.homepinappios` / macOS `com.sro.homepinappmac`).

- 템플릿: [`remoteconfig.template.json`](remoteconfig.template.json)
- 배포 설정: 루트 [`../firebase.json`](../firebase.json)

## 파라미터

| 키 | 타입 | 기본값 | 의미 |
| --- | --- | --- | --- |
| `latest_app_version` | String | `0.1.0` | 현재 < 이 값 → **선택** 업데이트(1회 알럿) |
| `min_required_app_version` | String | `0.0.0` | 현재 < 이 값 → **강제** 업데이트(차단 화면) |
| `update_store_url` | String | 플레이스홀더 | 업데이트 버튼이 여는 스토어 URL |

- 비교는 `CFBundleShortVersionString` 과 `.numeric`(`1.10.0` > `1.9.0`).
- 판정 우선순위: 강제 → 선택 → 최신.
- 기본값은 **아무 알럿도 안 뜨는 안전값**(현재 앱 버전 `0.1.0` 기준). 실제로 안내를 띄우려면
  `latest_app_version`/`min_required_app_version` 을 올린다.
- iOS·macOS **공통 키**. 플랫폼별로 다르게 하려면 콘솔에서 condition 을 추가해 분기한다.

## 방법 A — Firebase CLI 로 배포(권장)

```bash
# 1) firebase-tools 설치(최초 1회)
npm install -g firebase-tools

# 2) 로그인
firebase login

# 3) 이 저장소 루트에서 배포 (firebase.json 이 템플릿을 가리킨다)
firebase deploy --only remoteconfig --project homepin-1c94d
```

배포 후 콘솔(Remote Config)에서 값이 들어갔는지 확인한다. 이후 값만 바꿔
재배포하거나 콘솔에서 직접 수정해도 된다.

> 현재 콘솔 값을 거꾸로 내려받아 이 파일을 갱신하려면:
> `firebase remoteconfig:get -o firebase/remoteconfig.template.json --project homepin-1c94d`

## 방법 B — 콘솔에서 수동 입력

Firebase 콘솔 → Remote Config → "매개변수 추가" 로 위 표의 3개 키를 그대로 만든다
(키 이름·타입 String·기본값). 그런 다음 "변경사항 게시".

## 출시 후 할 일

- `update_store_url` 을 실제 App Store 링크로 교체(앱 미출시라 현재는 플레이스홀더).
- 새 버전 낼 때마다 `latest_app_version` 갱신, 강제 차단이 필요하면
  `min_required_app_version` 을 올린다.
