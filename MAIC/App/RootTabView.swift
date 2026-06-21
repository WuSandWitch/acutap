import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "house.fill") }
            BodyTapView()
                .tabItem { Label("AR 按摩指引", systemImage: "figure.stand") }
            LearnView()
                .tabItem { Label("教學", systemImage: "book.fill") }
        }
        .tint(.accentColor)
    }
}
