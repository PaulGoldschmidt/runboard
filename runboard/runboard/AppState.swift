//
//  AppState.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import Foundation
import Observation

@Observable
final class AppState {
    let healthKit = HealthKitManager()
    let cloudKit = CloudKitManager()
    let seeded: Bool

    var hasCompletedOnboarding: Bool {
        cloudKit.hasBoard
    }

    init() {
        seeded = CommandLine.arguments.contains("--seeded")
        if seeded {
            ScreenshotData.seed(cloudKit: cloudKit)
        }
    }

    func refreshAndSync() async {
        guard !seeded else { return }

        // Read HealthKit into the UI-facing observable so DashboardView reflects
        // current values, then delegate the authoritative CloudKit upload to the
        // coordinator. The coordinator also refreshes board members + reloads the
        // widget timeline on completion.
        await healthKit.refreshAll()
        await BackgroundSyncCoordinator.shared.runUploadCycle(trigger: .foreground)
        await cloudKit.fetchBoardMembers()
    }
}
