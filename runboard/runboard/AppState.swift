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
        await healthKit.refreshAll()
        await cloudKit.updateMyStats(
            vo2Max: healthKit.vo2Max,
            weeklyKilometers: healthKit.weeklyRunningKilometers
        )
        await cloudKit.fetchBoardMembers()
    }
}
