import ProjectDescription

// HomePinApp — iOS 26.5+ / Swift 6.2(언어 모드 6, strict concurrency) / SwiftData.
// 서버 없이 기기 내부에 저장하는 로컬 앱. iOS 앱 타깃과 네이티브 macOS 앱 타깃을 둔다.
// 두 타깃은 소스·리소스 경로를 공유하고, 플랫폼 차이는 코드의 `#if os(macOS)` 로 흡수한다.
let baseSettings: SettingsDictionary = [
  "MARKETING_VERSION": "0.0.9",
  "CURRENT_PROJECT_VERSION": "1",
  // SWIFT_VERSION 은 "언어 모드"다. 6.0 = Swift 6 언어 모드(strict concurrency).
  // 툴체인 자체는 Xcode 26 의 Swift 6.2 를 쓴다.
  "SWIFT_VERSION": "6.0",
  "SWIFT_STRICT_CONCURRENCY": "complete",
  "IPHONEOS_DEPLOYMENT_TARGET": "26.5",
  "ENABLE_PREVIEWS": "YES",
  "CODE_SIGN_STYLE": "Automatic",
  "CODE_SIGN_IDENTITY": "Apple Development",
  "DEVELOPMENT_TEAM": "D9BK789354",
  "PROVISIONING_PROFILE_SPECIFIER": "",
]

// 두 타깃이 공유하는 Info.plist 항목. 권한 설명은 InfoPlist.xcstrings(en/ko) 로 현지화하고
// 여기에는 영문 source 만 둔다. 플랫폼 전용 항목(iOS 의 씬, macOS 의 entitlements)은
// 각 타깃에서 덧붙인다.
let sharedInfoPlist: [String: Plist.Value] = [
  "CFBundleDevelopmentRegion": "en",
  "CFBundleLocalizations": ["en", "ko"],
  // 사용자 표시 이름(브랜드). 영문 기본은 "HomePin", ko 로케일은 InfoPlist.xcstrings 의
  // CFBundleDisplayName(ko="홈핀")으로 현지화된다. 지정하지 않으면 타깃명(HomePinApp 등)이
  // 홈 화면·Siri 발화에 노출되어 어색하다("HomePinApp에 물건 추가").
  "CFBundleDisplayName": "HomePin",
  // 버전은 빌드 세팅(MARKETING_VERSION·CURRENT_PROJECT_VERSION)을 단일 소스로 쓴다.
  // Tuist 기본 Info.plist 는 CFBundleShortVersionString 을 리터럴 "1.0" 으로 박으므로,
  // 빌드 변수를 참조하도록 명시 매핑해 baseSettings 의 버전이 실제 번들에 반영되게 한다.
  "CFBundleShortVersionString": "$(MARKETING_VERSION)",
  "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
  "CKSharingSupported": true,
  "NSMicrophoneUsageDescription": "Used to quickly add and search items by voice.",
  "NSSpeechRecognitionUsageDescription": "Used to transcribe what you say into text.",
]

// AdMob(SKAdNetwork) 광고 어트리뷰션용 네트워크 식별자. Google 권장 목록(iOS).
// 광고 표시 자체는 P2/P3 에서 하지만, 어트리뷰션 메타는 SDK 도입(P1) 시 함께 넣는다.
let adSKAdNetworkItems: [Plist.Value] = [
  "cstr6suwn9", "4fzdc2evr5", "2fnua5tdw4", "ydx93a7ass", "p78axxw29g",
  "v72qych5uu", "ludvb6z3bs", "cp8zw746q7", "3sh42y64q3", "c6k4g5qg8m",
  "s39g8k73mm", "wg4vff78zm", "3qy4746246", "f38h382jlk", "hs6bdukanm",
  "mlmmfzh3r3", "v4nxqhlyqp", "wzmmz9fp6w", "su67r6k2v3", "yclnxrl5pm",
  "t38b2kh725", "7ug5zh24hu", "gta9lk7p23", "vutu7akeur", "y5ghdn5j9k",
  "v9wttpbfk9", "n38lu8286q", "47vhws6wlr", "kbd757ywx3", "9t245vhmpl",
  "a2p9lx4jpn", "22mmun2rn5", "44jx6755aq", "k674qkevps", "4468km3ulz",
  "2u9pt9hc89", "8s468mfl3y", "klf5c3l5u5", "ppxm28t8ap", "kbmxgpxpgc",
  "uw77j35x4d", "578prtvx9j", "4dzt52r2t5", "tl55sbb4fm", "c3frkrj4fj",
  "e5fvkxwrpn", "8c4e2ghe7u", "3rd42ekr43", "97r2b46745", "3qcr597p9d",
].map { .dictionary(["SKAdNetworkIdentifier": .string("\($0).skadnetwork")]) }

let iOSInfoPlist: [String: Plist.Value] = sharedInfoPlist.merging([
  "UILaunchScreen": ["UIColorName": ""],
  "UIApplicationSceneManifest": [
    "UIApplicationSupportsMultipleScenes": false,
  ],
  // AdMob(P1: SDK 골격, 광고 미표시). 계정 없음 → Google 공식 테스트 앱 ID 만 사용한다.
  // 실광고 앱 ID 는 출시 직전 교체. 결정: docs/wiki/Decision/2026-06-17-AdMob-광고-수익화-도입.md
  "GADApplicationIdentifier": "ca-app-pub-3940256099942544~1458002511",
  // ATT — 비개인화 광고 동의 안내(IDFA 접근 전 사용자 추적 권한 설명). 현지화는
  // InfoPlist.xcstrings(en/ko), 여기엔 영문 source 만 둔다.
  "NSUserTrackingUsageDescription": "Used to show you more relevant ads. You can still use the app if you decline.",
  "SKAdNetworkItems": .array(adSKAdNetworkItems),
  // SwiftData + CloudKit private sync. 실제 sync 는 ModelContainer 구성에 의해 자동 수행되고,
  // Settings 의 토글은 다음 앱 시작부터 이 컨테이너를 사용하도록 설정한다.
  "UIBackgroundModes": ["remote-notification"],
  // 백업 번들 = 디렉터리 패키지(.homepinbackup). 외부 의존성 없이 FileManager 로 다룬다.
  // 결정: docs/wiki/Decision/2026-06-17-데이터-백업-번들포맷.md
  "UTExportedTypeDeclarations": [
    [
      "UTTypeIdentifier": "com.sro.homepinappios.backup",
      "UTTypeDescription": "HomePin Backup",
      "UTTypeConformsTo": ["com.apple.package"],
      "UTTypeTagSpecification": [
        "public.filename-extension": ["homepinbackup"],
      ],
    ],
  ],
]) { _, new in new }

let macOSInfoPlist: [String: Plist.Value] = sharedInfoPlist.merging([
  // 표시 이름을 명시한다. 지정하지 않으면 타깃명(HomePinApp-macOS)이 노출되고, Xcode 가
  // 공유 InfoPlist.xcstrings 를 그 값으로 덮어쓴다. 사용자 표시 이름(브랜드)은 "HomePin"
  // 으로 두고, ko 로케일은 공유 InfoPlist.xcstrings 의 CFBundleDisplayName(ko="홈핀")으로 현지화된다.
  "CFBundleDisplayName": "HomePin",
  "CFBundleName": "HomePin",
  // macOS 도 백업 번들 UTType 을 선언한다(파일 Import/Export 로 .homepinbackup 을 다룬다).
  "UTExportedTypeDeclarations": [
    [
      "UTTypeIdentifier": "com.sro.homepinappmac.backup",
      "UTTypeDescription": "HomePin Backup",
      "UTTypeConformsTo": ["com.apple.package"],
      "UTTypeTagSpecification": [
        "public.filename-extension": ["homepinbackup"],
      ],
    ],
  ],
]) { _, new in new }

// 외부 의존성. AdMob 수익화(P1: SDK + 동의/ATT 골격)용 Google Mobile Ads SDK 와
// UMP(User Messaging Platform, 동의 폼) SDK 를 SPM 으로 가져온다. 첫 외부 의존성이라
// 재현성 우선으로 `.exact` 로 핀한다. GMA 13.5.0(2026-06-09 최신)은 UMP 를 내부 의존성으로
// 끌고 오지만, `import UserMessagingPlatform` 를 쓰려면 product 가 직접 링크돼야 해 UMP
// 패키지(3.1.0)도 명시적으로 추가한다. SDK 는 iOS 전용(macOS 미지원) → iOS 타깃에만 링크하고
// macOS 타깃은 `dependencies: []` 를 유지한다(추가 시 macOS 빌드가 깨진다).
// 결정: docs/wiki/Decision/2026-06-17-AdMob-광고-수익화-도입.md
//
// Firebase(SPM `firebase-ios-sdk` 12.15.0, 2026 최신 안정)도 동일하게 `.exact` 로 핀한다.
// AdMob 과 달리 Firebase 는 macOS 를 지원하므로 **iOS·macOS 두 타깃 모두에 링크**한다.
// 범위: Analytics(간단 분석) · Crashlytics(크래시) · RemoteConfig(앱 버전 게이트).
// 실제 동작에는 `GoogleService-Info.plist` 가 필요하다(타깃별로 다른 파일). 이 코드 단계에서는
// 코드만 먼저 들어가고 plist 는 비커밋(.gitignore)으로 로컬에서 주입한다. plist 가 없으면
// `FirebaseBootstrap` 가 구성을 skip 해 앱은 정상 동작한다(차단 없음).
// 결정: docs/wiki/Decision/2026-06-18-Firebase-analytics-crashlytics-remoteconfig.md
let packages: [Package] = [
  .remote(
    url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
    requirement: .exact("13.5.0")
  ),
  .remote(
    url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
    requirement: .exact("3.1.0")
  ),
  .remote(
    url: "https://github.com/firebase/firebase-ios-sdk.git",
    requirement: .exact("12.15.0")
  ),
]

// iOS 타깃에만 링크할 광고 SDK product.
let iOSAdDependencies: [TargetDependency] = [
  .package(product: "GoogleMobileAds"),
  .package(product: "GoogleUserMessagingPlatform"),
]

// iOS·macOS 공통으로 링크할 Firebase product (Firebase 는 macOS 지원).
let firebaseDependencies: [TargetDependency] = [
  .package(product: "FirebaseAnalytics"),
  .package(product: "FirebaseCrashlytics"),
  .package(product: "FirebaseRemoteConfig"),
]

// Crashlytics dSYM 업로드(빌드 후). SPM 체크아웃의 `run` 스크립트와 번들 내
// `GoogleService-Info.plist` 가 둘 다 있을 때만 실행하고, 없으면 조용히 skip 한다
// (코드만 먼저 들어간 단계에서 plist 부재로 빌드가 깨지지 않게 — 빌드 green 유지).
let crashlyticsUploadScript: TargetScript = .post(
  script: """
  RUN_SCRIPT="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
  PLIST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"
  if [ -f "$RUN_SCRIPT" ] && [ -f "$PLIST" ]; then
    "$RUN_SCRIPT"
  else
    echo "Crashlytics: run 스크립트 또는 GoogleService-Info.plist 없음 → dSYM 업로드 skip"
  fi
  """,
  name: "Upload Crashlytics dSYMs",
  inputPaths: [
    "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}",
    "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist",
  ],
  basedOnDependencyAnalysis: false
)

let project = Project(
  name: "HomePinApp",
  options: .options(
    // 타깃별로 스킴을 따로 생성한다(.notGrouped). .singleScheme 은 iOS·macOS 두 타깃을 한
    // 스킴에 묶어, macOS 데스티네이션 빌드 시 iOS 타깃까지 끌려와 프로비저닝 서명 오류가 났다.
    // 분리하면 `HomePinApp`(iOS) / `HomePinApp-macOS`(macOS) 스킴이 각각 노출된다.
    automaticSchemesOptions: .enabled(
      targetSchemesGrouping: .notGrouped,
      codeCoverageEnabled: false,
      testingOptions: [],
    ),
    developmentRegion: "en",
  ),
  packages: packages,
  settings: .settings(base: baseSettings),
  targets: [
    .target(
      name: "HomePinApp",
      destinations: .iOS,
      product: .app,
      bundleId: "com.sro.homepinappios",
      deploymentTargets: .iOS("26.5"),
      infoPlist: .extendingDefault(with: iOSInfoPlist),
      sources: ["HomePinApp/Sources/**"],
      // 공유 Resources + iOS 전용 리소스(`Resources-iOS/**`). 프라이버시 매니페스트
      // (AdMob 추적 도메인·required reason API)와 iOS용 `GoogleService-Info.plist` 가 여기 있다.
      // glob(`**`)이라 plist 가 없어도(코드만 먼저) 빌드가 깨지지 않고, 있으면 자동 번들된다.
      // 커밋된 `GoogleService-Info.sample.plist` 는 형식 안내용 템플릿(실 plist 는 .gitignore).
      resources: ["HomePinApp/Resources/**", "HomePinApp/Resources-iOS/**"],
      entitlements: "Tuist/Support/HomePinApp-iOS.entitlements",
      scripts: [crashlyticsUploadScript],
      dependencies: iOSAdDependencies + firebaseDependencies,
      settings: .settings(
        base: [
          "TARGETED_DEVICE_FAMILY": "1,2",
          "SUPPORTS_MACCATALYST": "NO",
          "ENABLE_BITCODE": "NO",
        ]
      ),
    ),
    .target(
      name: "HomePinApp-macOS",
      destinations: .macOS,
      product: .app,
      bundleId: "com.sro.homepinappmac",
      deploymentTargets: .macOS("26.0"),
      infoPlist: .extendingDefault(with: macOSInfoPlist),
      sources: ["HomePinApp/Sources/**"],
      // 공유 Resources + macOS 전용 `GoogleService-Info.plist`(`Resources-macOS/**`).
      // iOS 와 다른 bundleId 라 Firebase plist 도 타깃별로 분리한다. AdMob 은 macOS 미지원이라
      // 광고 SDK 는 링크하지 않고(아래 `firebaseDependencies` 만), 광고 코드는 #if 가드로 no-op.
      resources: ["HomePinApp/Resources/**", "HomePinApp/Resources-macOS/**"],
      entitlements: "Tuist/Support/HomePinApp-macOS.entitlements",
      scripts: [crashlyticsUploadScript],
      dependencies: firebaseDependencies,
      settings: .settings(
        base: [
          "ENABLE_BITCODE": "NO",
        ]
      ),
    ),
  ],
)
