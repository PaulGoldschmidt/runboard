//
//  CloudKitManagerPureLogicTests.swift
//  runboardTests
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import Testing
import Foundation
import CloudKit
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

// MARK: - Apply Stats Update Tests

struct ApplyStatsUpdateTests {

    private func makeRecord(vo2Max: Double? = nil) -> CKRecord {
        let record = CKRecord(recordType: "BoardMember", recordID: CKRecord.ID(recordName: "test-member"))
        if let vo2Max { record["vo2Max"] = vo2Max }
        return record
    }

    @Test func nilVo2DoesNotClearExistingServerValue() {
        let record = makeRecord(vo2Max: 52.5)
        CloudKitManager.applyStatsUpdate(to: record, vo2Max: nil, weeklyKilometers: 12.0, weekStart: CloudKitManager.currentWeekStart())
        #expect(record["vo2Max"] as? Double == 52.5)
        #expect(record["weeklyKilometers"] as? Double == 12.0)
    }

    @Test func nonNilVo2UpdatesServerValue() {
        let record = makeRecord(vo2Max: 52.5)
        CloudKitManager.applyStatsUpdate(to: record, vo2Max: 54.0, weeklyKilometers: 12.0, weekStart: CloudKitManager.currentWeekStart())
        #expect(record["vo2Max"] as? Double == 54.0)
    }

    @Test func vo2SetOnRecordThatNeverHadOne() {
        let record = makeRecord()
        CloudKitManager.applyStatsUpdate(to: record, vo2Max: 48.0, weeklyKilometers: 5.0, weekStart: CloudKitManager.currentWeekStart())
        #expect(record["vo2Max"] as? Double == 48.0)
    }

    @Test func historyStillRecordsWeekWhenVo2IsNil() {
        let record = makeRecord(vo2Max: 50.0)
        CloudKitManager.applyStatsUpdate(to: record, vo2Max: nil, weeklyKilometers: 20.0, weekStart: CloudKitManager.currentWeekStart())
        let history = [WeeklySnapshot].decodedHistory(fromJSON: record["statsHistory"] as? String)
        #expect(history.count == 1)
        #expect(history[0].weeklyKilometers == 20.0)
    }

    @Test func lastUpdatedAlwaysStamped() {
        let record = makeRecord()
        CloudKitManager.applyStatsUpdate(to: record, vo2Max: nil, weeklyKilometers: 0.0, weekStart: CloudKitManager.currentWeekStart())
        #expect(record["lastUpdated"] as? Date != nil)
    }
}

// MARK: - Retry Replay Policy Tests

struct RetryReplayPolicyTests {

    private let thisWeek = Date(timeIntervalSince1970: 2_000_000_000)
    private var lastWeek: Date { thisWeek.addingTimeInterval(-7 * 86_400) }

    private func entry(week: Date, km: Double) -> PendingUpload {
        PendingUpload(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), vo2Max: nil, weeklyKilometers: km, weekStart: week)
    }

    @Test func picksNewestCurrentWeekEntry() {
        let entries = [entry(week: thisWeek, km: 5), entry(week: lastWeek, km: 55), entry(week: thisWeek, km: 9)]
        let picked = BackgroundSyncCoordinator.newestCurrentWeekEntry(in: entries, currentWeek: thisWeek)
        #expect(picked?.weeklyKilometers == 9)
    }

    @Test func ignoresEntriesFromOtherWeeks() {
        let entries = [entry(week: lastWeek, km: 55)]
        #expect(BackgroundSyncCoordinator.newestCurrentWeekEntry(in: entries, currentWeek: thisWeek) == nil)
    }

    @Test func emptyQueueYieldsNil() {
        #expect(BackgroundSyncCoordinator.newestCurrentWeekEntry(in: [], currentWeek: thisWeek) == nil)
    }

    @Test func toleratesTimezoneShiftedWeekStart() {
        let sixHoursOff = thisWeek.addingTimeInterval(-6 * 3_600)
        let entries = [entry(week: sixHoursOff, km: 7)]
        let picked = BackgroundSyncCoordinator.newestCurrentWeekEntry(in: entries, currentWeek: thisWeek)
        #expect(picked?.weeklyKilometers == 7)
    }
}
