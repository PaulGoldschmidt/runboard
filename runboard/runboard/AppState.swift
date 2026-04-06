//
//  AppState.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import Foundation
import Observation
import WidgetKit

@Observable
final class AppState {
    let healthKit = HealthKitManager()
    let cloudKit = CloudKitManager()

    var hasCompletedOnboarding: Bool {
        cloudKit.hasBoard
    }

    func refreshAndSync() async {
        await healthKit.refreshAll()
        await cloudKit.updateMyStats(
            vo2Max: healthKit.vo2Max,
            weeklyKilometers: healthKit.weeklyRunningKilometers
        )
        await cloudKit.fetchBoardMembers()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
