import SwiftUI

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selection: Tab = .daily
    @State private var auth = AuthService.shared

    enum Tab: Hashable { case daily, ar, ai }

    var body: some View {
        Group {
            switch auth.state {
            case .unknown:
                // 正在檢查 Keychain 中是否有 token
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            case .authenticated:
                mainTabs
                    .onAppear { syncGoogleName() }
                    .task { await env.initialize() }
            case .unauthenticated:
                LoginView()
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func syncGoogleName() {
        if let name = auth.userName, !name.isEmpty {
            env.profile = UserProfile(
                name: name,
                birthYear: Calendar.current.component(.year, from: Date()) - 25,
                constitution: [.balanced: 1.0]
            )
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selection) {
            DailyView(goToAR: { selection = .ar })
                .tag(Tab.daily)
                .tabItem { Label("每日點穴", systemImage: "sun.haze.fill") }

            ARAcupointView()
                .tag(Tab.ar)
                .tabItem { Label("AR 穴位", systemImage: "camera.viewfinder") }

            AIAssistantView()
                .tag(Tab.ai)
                .tabItem { Label("AI 助手", systemImage: "sparkles") }
        }
        .tint(Theme.teal)
    }
}

#Preview {
    RootTabView().environment(AppEnvironment())
}
