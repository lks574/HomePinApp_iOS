import SwiftUI

/// 설정 — 우선 정보 위주의 stub.
struct SettingsView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("정보") {
          LabeledContent("버전", value: "0.1.0")
          LabeledContent("저장", value: "이 기기 (SwiftData)")
        }
        Section {
          Text("HomePin — 집 안 물건을 위치에 핀하고, 말로 넣고 찾는 로컬 앱.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("설정")
    }
  }
}
