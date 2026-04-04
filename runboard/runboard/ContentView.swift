//
//  ContentView.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                DashboardView()
            } else {
                BoardSetupView()
            }
        }
        .task {
            await appState.healthKit.requestAuthorization()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
