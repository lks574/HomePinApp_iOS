import ProjectDescription

// HomePinApp — iOS 26.5+ / Swift 6.2(언어 모드 6, strict concurrency) / SwiftData.
// 서버 없이 기기 내부에 저장하는 로컬 앱. iOS 앱 타깃과 네이티브 macOS 앱 타깃을 둔다.
// 두 타깃은 소스·리소스 경로를 공유하고, 플랫폼 차이는 코드의 `#if os(macOS)` 로 흡수한다.
let baseSettings: SettingsDictionary = [
  "MARKETING_VERSION": "0.1.0",
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
  "CKSharingSupported": true,
  "NSMicrophoneUsageDescription": "Used to quickly add and search items by voice.",
  "NSSpeechRecognitionUsageDescription": "Used to transcribe what you say into text.",
  // 영수증 스캔(screen-22) — 카메라로 영수증을 찍고, 사진 보관함에서 영수증 이미지를 골라
  // 글자를 읽어 품목으로 적재한다. 영수증 이미지 자체는 저장하지 않는다. 현지화는
  // InfoPlist.xcstrings(en/ko), 여기엔 영문 source 만 둔다.
  "NSCameraUsageDescription": "Used to scan a receipt and read item names from it.",
  "NSPhotoLibraryUsageDescription": "Used to read item names from a receipt photo you choose.",
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
  // 공유 InfoPlist.xcstrings 를 그 값으로 덮어쓴다. iOS 앱과 동일하게 "HomePinApp" 로 둔다.
  "CFBundleDisplayName": "HomePinApp",
  "CFBundleName": "HomePinApp",
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
let packages: [Package] = [
  .remote(
    url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
    requirement: .exact("13.5.0")
  ),
  .remote(
    url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
    requirement: .exact("3.1.0")
  ),
]

// iOS 타깃에만 링크할 광고 SDK product.
let iOSAdDependencies: [TargetDependency] = [
  .package(product: "GoogleMobileAds"),
  .package(product: "GoogleUserMessagingPlatform"),
]

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
      // 공유 Resources + iOS 전용 프라이버시 매니페스트. AdMob 추적 도메인·required reason
      // API 선언은 iOS(광고 SDK 링크 타깃)에만 의미가 있어 공유 glob 밖에 두고 iOS 타깃에만
      // 포함한다. AdMob SDK 동봉 매니페스트와 빌드시 병합된다.
      resources: ["HomePinApp/Resources/**", "HomePinApp/Resources-iOS/PrivacyInfo.xcprivacy"],
      entitlements: "Tuist/Support/HomePinApp-iOS.entitlements",
      dependencies: iOSAdDependencies,
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
      resources: ["HomePinApp/Resources/**"],
      entitlements: "Tuist/Support/HomePinApp-macOS.entitlements",
      dependencies: [],
      settings: .settings(
        base: [
          "ENABLE_BITCODE": "NO",
        ]
      ),
    ),
  ],
)
