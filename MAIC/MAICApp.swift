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
            Group {
                if env.hasOnboarded {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            }
            .environment(env)
            .preferredColorScheme(scheme)
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
