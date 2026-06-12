import Foundation

/// 탭바 목적지. 중앙 마이크(NL 추가)는 탭이 아니라 시트라 여기에 없음.
enum AppTab: Hashable, CaseIterable {
  case home
  case places
  case recipes
  case settings
}
