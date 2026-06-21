//
//  ContentView.swift
//  MAIC
//
//  Created by Luis on 2026/5/30.
//

import SwiftUI

// Legacy placeholder retained to keep Xcode group references stable.
// The app entry point is `MAICApp` -> `OnboardingView` / `RootTabView`.
struct ContentView: View {
    var body: some View {
        RootTabView().environment(AppEnvironment())
    }
}

#Preview {
    ContentView()
}
