//
//  SharedModelsTests.swift
//  runboardTests
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import Testing
import Foundation
@testable import runboard

// MARK: - WeeklySnapshot Tests

struct WeeklySnapshotTests {

    @Test func codableRoundtrip() throws {
        let original = WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 1_000_000), weeklyKilometers: 42.5, vo2Max: 55.3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WeeklySnapshot.self, from: data)
        #expect(decoded == original)
    }

    @Test func codableRoundtripWithNilVO2Max() throws {
        let original = WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 2_000_000), weeklyKilometers: 10.0, vo2Max: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WeeklySnapshot.self, from: data)
        #expect(decoded == original)
        #expect(decoded.vo2Max == nil)
    }

    @Test func identifiableReturnsWeekStart() {
        let date = Date(timeIntervalSince1970: 3_000_000)
        let snapshot = WeeklySnapshot(weekStart: date, weeklyKilometers: 5.0, vo2Max: nil)
        #expect(snapshot.id == date)
    }

    @Test func equalityWithDifferentKilometers() {
        let a = WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 1_000_000), weeklyKilometers: 10.0, vo2Max: 50.0)
        let b = WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 1_000_000), weeklyKilometers: 20.0, vo2Max: 50.0)
        #expect(a != b)
    }
}

// MARK: - BoardMember Tests

struct BoardMemberTests {

    @Test func codableRoundtrip() throws {
        let history = [
            WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 1_000_000), weeklyKilometers: 30.0, vo2Max: 48.0)
        ]
        let original = BoardMember(
            id: "member-1",
            displayName: "Alice",
            vo2Max: 52.0,
            weeklyKilometers: 35.5,
            lastUpdated: Date(timeIntervalSince1970: 5_000_000),
            isCurrentUser: true,
            statsHistory: history
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BoardMember.self, from: data)
        #expect(decoded == original)
    }

    @Test func codableRoundtripWithDefaults() throws {
        let original = BoardMember(
            id: "member-2",
            displayName: "Bob",
            vo2Max: nil,
            weeklyKilometers: 0.0,
            lastUpdated: Date(timeIntervalSince1970: 6_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BoardMember.self, from: data)
        #expect(decoded == original)
        #expect(decoded.isCurrentUser == false)
        #expect(decoded.statsHistory.isEmpty)
    }

    @Test func identifiableReturnsId() {
        let member = BoardMember(
            id: "test-id-123",
            displayName: "Charlie",
            vo2Max: nil,
            weeklyKilometers: 0.0,
            lastUpdated: Date()
        )
        #expect(member.id == "test-id-123")
    }

    @Test func equalityDifferentDisplayName() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let a = BoardMember(id: "same", displayName: "Alice", vo2Max: nil, weeklyKilometers: 0.0, lastUpdated: date)
        let b = BoardMember(id: "same", displayName: "Bob", vo2Max: nil, weeklyKilometers: 0.0, lastUpdated: date)
        #expect(a != b)
    }
}

// MARK: - StatType Tests

struct StatTypeTests {

    @Test func rawValues() {
        #expect(StatType.weeklyKm.rawValue == "WEEKLY KM")
        #expect(StatType.vo2Max.rawValue == "VO2 MAX")
    }

    @Test func caseIterableCount() {
        #expect(StatType.allCases.count == 2)
    }

    @Test func initFromRawValue() {
        #expect(StatType(rawValue: "WEEKLY KM") == .weeklyKm)
        #expect(StatType(rawValue: "VO2 MAX") == .vo2Max)
        #expect(StatType(rawValue: "invalid") == nil)
    }
}

// MARK: - BoardError Tests

struct BoardErrorTests {

    @Test func errorDescription() {
        #expect(BoardError.boardNotFound.errorDescription == "No board found with that code.")
    }

    @Test func localizedErrorConformance() {
        let error: any LocalizedError = BoardError.boardNotFound
        #expect(error.errorDescription == "No board found with that code.")
    }
}

// MARK: - Active Members Tests

struct ActiveMembersTests {

    private let now = Date(timeIntervalSince1970: 100_000_000)

    private func makeMember(id: String, lastUpdated: Date, isCurrentUser: Bool = false) -> BoardMember {
        BoardMember(
            id: id,
            displayName: id,
            vo2Max: nil,
            weeklyKilometers: 0,
            lastUpdated: lastUpdated,
            isCurrentUser: isCurrentUser
        )
    }

    @Test func keepsRecentlyUpdatedMembers() {
        let members = [
            makeMember(id: "fresh", lastUpdated: now.addingTimeInterval(-3 * 86_400)),
            makeMember(id: "justNow", lastUpdated: now)
        ]
        #expect(members.activeMembers(asOf: now).map(\.id) == ["fresh", "justNow"])
    }

    @Test func hidesMembersStaleForOverTwoWeeks() {
        let members = [
            makeMember(id: "stale", lastUpdated: now.addingTimeInterval(-15 * 86_400)),
            makeMember(id: "fresh", lastUpdated: now.addingTimeInterval(-86_400))
        ]
        #expect(members.activeMembers(asOf: now).map(\.id) == ["fresh"])
    }

    @Test func hidesMemberAtExactlyTwoWeeks() {
        let members = [makeMember(id: "boundary", lastUpdated: now.addingTimeInterval(-14 * 86_400))]
        #expect(members.activeMembers(asOf: now).isEmpty)
    }

    @Test func keepsMemberJustUnderTwoWeeks() {
        let members = [makeMember(id: "almost", lastUpdated: now.addingTimeInterval(-14 * 86_400 + 1))]
        #expect(members.activeMembers(asOf: now).map(\.id) == ["almost"])
    }

    @Test func alwaysKeepsCurrentUser() {
        let members = [
            makeMember(id: "me", lastUpdated: now.addingTimeInterval(-30 * 86_400), isCurrentUser: true),
            makeMember(id: "stale", lastUpdated: now.addingTimeInterval(-30 * 86_400))
        ]
        #expect(members.activeMembers(asOf: now).map(\.id) == ["me"])
    }

    @Test func customWindow() {
        let members = [makeMember(id: "m", lastUpdated: now.addingTimeInterval(-10 * 86_400))]
        #expect(members.activeMembers(within: 7, asOf: now).isEmpty)
        #expect(members.activeMembers(within: 21, asOf: now).map(\.id) == ["m"])
    }
}

// MARK: - Decoded History Tests

struct DecodedHistoryTests {

    @Test func roundtripSortedAscending() throws {
        let snapshots = [
            WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 2_000_000), weeklyKilometers: 20, vo2Max: nil),
            WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 1_000_000), weeklyKilometers: 10, vo2Max: 50),
        ]
        let json = String(data: try JSONEncoder().encode(snapshots), encoding: .utf8)
        let decoded = [WeeklySnapshot].decodedHistory(fromJSON: json)
        #expect(decoded.map(\.weeklyKilometers) == [10, 20])
    }

    @Test func nilAndGarbageYieldEmpty() {
        #expect([WeeklySnapshot].decodedHistory(fromJSON: nil).isEmpty)
        #expect([WeeklySnapshot].decodedHistory(fromJSON: "not json").isEmpty)
    }
}

// MARK: - VO2 Backfill Tests

struct Vo2BackfillTests {

    private func makeMember(vo2Max: Double?, history: [WeeklySnapshot]) -> BoardMember {
        BoardMember(
            id: "m",
            displayName: "M",
            vo2Max: vo2Max,
            weeklyKilometers: 0,
            lastUpdated: Date(timeIntervalSince1970: 1_000_000),
            statsHistory: history
        )
    }

    @Test func fillsMissingVo2FromNewestHistoryEntry() {
        let history = [
            WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 1_000_000), weeklyKilometers: 10, vo2Max: 48.0),
            WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 2_000_000), weeklyKilometers: 12, vo2Max: 51.5),
            WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 3_000_000), weeklyKilometers: 8, vo2Max: nil),
        ]
        let filled = makeMember(vo2Max: nil, history: history).backfillingVo2FromHistory()
        #expect(filled.vo2Max == 51.5)
    }

    @Test func keepsExistingFlatVo2() {
        let history = [WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 1_000_000), weeklyKilometers: 10, vo2Max: 48.0)]
        let member = makeMember(vo2Max: 52.0, history: history).backfillingVo2FromHistory()
        #expect(member.vo2Max == 52.0)
    }

    @Test func staysNilWithoutAnyHistoryVo2() {
        let history = [WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 1_000_000), weeklyKilometers: 10, vo2Max: nil)]
        #expect(makeMember(vo2Max: nil, history: history).backfillingVo2FromHistory().vo2Max == nil)
        #expect(makeMember(vo2Max: nil, history: []).backfillingVo2FromHistory().vo2Max == nil)
    }
}

// MARK: - Current Week Kilometers Tests

struct CurrentWeekKilometersTests {

    private let weekStart = BoardMember.weekStart(containing: Date(timeIntervalSince1970: 1_800_000_000))
    private var midWeek: Date { weekStart.addingTimeInterval(3 * 86_400) }

    private func makeMember(km: Double, lastUpdated: Date) -> BoardMember {
        BoardMember(id: "m", displayName: "M", vo2Max: nil, weeklyKilometers: km, lastUpdated: lastUpdated)
    }

    @Test func countsKmPushedThisWeek() {
        let member = makeMember(km: 42.0, lastUpdated: weekStart.addingTimeInterval(3_600))
        #expect(member.currentWeekKilometers(asOf: midWeek) == 42.0)
    }

    @Test func zeroesKmPushedBeforeThisWeek() {
        let member = makeMember(km: 55.0, lastUpdated: weekStart.addingTimeInterval(-3_600))
        #expect(member.currentWeekKilometers(asOf: midWeek) == 0.0)
    }

    @Test func countsKmPushedExactlyAtWeekStart() {
        let member = makeMember(km: 12.0, lastUpdated: weekStart)
        #expect(member.currentWeekKilometers(asOf: midWeek) == 12.0)
    }

    @Test func weekStartIsStableWithinWeek() {
        #expect(BoardMember.weekStart(containing: midWeek) == weekStart)
    }
}
