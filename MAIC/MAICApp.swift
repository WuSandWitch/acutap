//
//  MAICApp.swift
//  MAIC
//
//  Created by Luis on 2026/5/30.
//

import SwiftUI

@main
struct MAICApp: App {
    @State private var env = AppEnvironment()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboarding_completed")
    @AppStorage("appearance") private var appearance: String = "system"

    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView { userName in
                    // 儲存使用者名稱
                    UserDefaults.standard.set(userName, forKey: "user_name")
                    UserDefaults.standard.set(true, forKey: "onboarding_completed")
                    // 更新 AppEnvironment profile
                    env.profile = UserProfile(
                        name: userName,
                        birthYear: Calendar.current.component(.year, from: Date()) - 25,
                        constitution: [.balanced: 1.0]
                    )
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showOnboarding = false
                    }
                }
                .environment(env)
                .preferredColorScheme(scheme)
            } else {
                RootTabView()
                    .environment(env)
                    .tint(Theme.teal)
                    .preferredColorScheme(scheme)
                    .task {
                        await env.initialize()
                    }
            }
        }
    }

    private var scheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}
