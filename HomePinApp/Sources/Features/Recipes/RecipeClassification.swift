import Foundation

/// 레시피 분류(요리권 cuisine · 종류 dishType)의 표시 라벨 매핑.
///
/// 저장값(raw)은 현행 한국어 그대로 유지한다(SwiftData 스키마/마이그레이션 변경 금지,
/// 필터 동등 비교 키도 raw 유지). 화면에 보이는 라벨만 시스템 언어로 매핑한다.
/// 필터·에디터 칩의 프리셋 raw 키 목록도 단일 소스로 여기서 제공한다.
enum RecipeClassification {
  /// 요리권 프리셋(저장/비교용 raw 키, 한국어 고정).
  static let cuisineKeys = ["한식", "일식", "중식", "양식", "분식"]

  /// 요리 종류 프리셋(저장/비교용 raw 키, 한국어 고정).
  static let dishTypeKeys = ["국·찌개", "볶음", "구이", "조림", "밥·면", "반찬"]

  /// 요리권 raw 키 → 표시 라벨(시스템 언어). 미등록 raw 는 원본을 그대로 보여준다.
  static func cuisineLabel(_ raw: String) -> String {
    switch raw {
    case "한식": String(localized: "cuisine.korean", defaultValue: "Korean")
    case "일식": String(localized: "cuisine.japanese", defaultValue: "Japanese")
    case "중식": String(localized: "cuisine.chinese", defaultValue: "Chinese")
    case "양식": String(localized: "cuisine.western", defaultValue: "Western")
    case "분식": String(localized: "cuisine.snack", defaultValue: "Street Food")
    default: raw
    }
  }

  /// 요리 종류 raw 키 → 표시 라벨(시스템 언어). 미등록 raw 는 원본을 그대로 보여준다.
  static func dishTypeLabel(_ raw: String) -> String {
    switch raw {
    case "국·찌개": String(localized: "dish.soupStew", defaultValue: "Soup & Stew")
    case "볶음": String(localized: "dish.stirFry", defaultValue: "Stir-fry")
    case "구이": String(localized: "dish.grilled", defaultValue: "Grilled")
    case "조림": String(localized: "dish.braised", defaultValue: "Braised")
    case "밥·면": String(localized: "dish.riceNoodle", defaultValue: "Rice & Noodles")
    case "반찬": String(localized: "dish.sideDish", defaultValue: "Side Dish")
    default: raw
    }
  }
}
