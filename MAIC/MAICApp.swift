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
    @AppStorage("appearance") private var appearance: String = "system"

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(env)
                .tint(Theme.teal)
                .preferredColorScheme(scheme)
                .task {
                    // 啟動時初始化 HealthKit + 載入後端資料
                    await env.initialize()
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
