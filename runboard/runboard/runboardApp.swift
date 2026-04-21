//
//  runboardApp.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import SwiftUI

@main
struct runboardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    init() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        UserDefaults.standard.set("\(version) (\(build))", forKey: "version_preference")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
