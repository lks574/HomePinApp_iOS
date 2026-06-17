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
// 여기에는 영문 source 만 둔다. 플랫폼 전용 항목(iOS 의 씬/카메라, macOS 의 entitlements)은
// 각 타깃에서 덧붙인다.
let sharedInfoPlist: [String: Plist.Value] = [
  "CFBundleDevelopmentRegion": "en",
  "CFBundleLocalizations": ["en", "ko"],
  // 마이크·음성인식은 양 플랫폼 공통(STT). 카메라·사진은 iOS 전용이라 iOS Info.plist 에만 둔다.
  "NSMicrophoneUsageDescription": "Used to quickly add and search items by voice.",
  "NSSpeechRecognitionUsageDescription": "Used to transcribe what you say into text.",
]

let iOSInfoPlist: [String: Plist.Value] = sharedInfoPlist.merging([
  "UILaunchScreen": ["UIColorName": ""],
  "UIApplicationSceneManifest": [
    "UIApplicationSupportsMultipleScenes": false,
  ],
  // 카메라·사진은 iOS 전용 진입점이라 iOS Info.plist 에만 둔다.
  "NSCameraUsageDescription": "Used to scan a recipe from a cookbook or note into text.",
  "NSPhotoLibraryUsageDescription": "Used to read recipe text from a photo or screenshot.",
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

let project = Project(
  name: "HomePinApp",
  options: .options(
    automaticSchemesOptions: .enabled(
      targetSchemesGrouping: .singleScheme,
      codeCoverageEnabled: false,
      testingOptions: [],
    ),
    developmentRegion: "en",
  ),
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
      resources: ["HomePinApp/Resources/**"],
      dependencies: [],
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
