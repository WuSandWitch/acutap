import SwiftUI

struct RootTabView: View {
    @State private var selection: Tab = .daily

    enum Tab: Hashable { case daily, ar, ai }

    var body: some View {
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
