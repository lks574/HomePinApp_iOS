import ProjectDescription

// HomePinApp — iOS 26.5+ / Swift 6.2(언어 모드 6, strict concurrency) / SwiftData.
// 서버 없이 기기 내부에 저장하는 로컬 앱. 단일 앱 타깃으로 시작한다.
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
      infoPlist: .extendingDefault(with: [
        "UILaunchScreen": ["UIColorName": ""],
        "UIApplicationSceneManifest": [
          "UIApplicationSupportsMultipleScenes": false,
        ],
        "CFBundleDevelopmentRegion": "en",
        "CFBundleLocalizations": ["en", "ko"],
        // 권한 설명은 InfoPlist.xcstrings(en/ko) 로 현지화한다. 여기에는 영문 source 만 둔다.
        "NSMicrophoneUsageDescription": "Used to quickly add and search items by voice.",
        "NSSpeechRecognitionUsageDescription": "Used to transcribe what you say into text.",
        "NSCameraUsageDescription": "Used to scan a recipe from a cookbook or note into text.",
        "NSPhotoLibraryUsageDescription": "Used to read recipe text from a photo or screenshot.",
      ]),
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
  ],
)
