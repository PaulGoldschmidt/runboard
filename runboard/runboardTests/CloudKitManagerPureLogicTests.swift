//
//  CloudKitManagerPureLogicTests.swift
//  runboardTests
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import Testing
import Foundation
@testable import runboard

struct CloudKitManagerPureLogicTests {

    @Test func currentWeekStartIsMonday() {
        let weekStart = CloudKitManager.currentWeekStart()
        let calendar = Calendar(identifier: .iso8601)
        let weekday = calendar.component(.weekday, from: weekStart)
        // In ISO 8601 calendar, Monday is weekday 2
        #expect(weekday == 2)
    }

    @Test func currentWeekStartIsNotInTheFuture() {
        let weekStart = CloudKitManager.currentWeekStart()
        #expect(weekStart <= Date())
    }

    @Test func currentWeekStartIsWithinSevenDays() {
        let weekStart = CloudKitManager.currentWeekStart()
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        #expect(weekStart > sevenDaysAgo)
    }

    @Test func currentWeekStartHasMidnightTime() {
        let weekStart = CloudKitManager.currentWeekStart()
        let calendar = Calendar(identifier: .iso8601)
        let components = calendar.dateComponents([.hour, .minute, .second], from: weekStart)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }
}
