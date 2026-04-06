//
//  SharedDataStoreTests.swift
//  runboardTests
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import Testing
import Foundation
@testable import runboard

@Suite(.serialized)
struct SharedDataStoreTests {

    private func withTestDefaults(_ body: () throws -> Void) rethrows {
        let testSuite = "test.runboard.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        let original = SharedDataStore.defaults
        SharedDataStore.defaults = testDefaults
        defer {
            SharedDataStore.defaults = original
            testDefaults.removePersistentDomain(forName: testSuite)
        }
        try body()
    }

    @Test func cacheMembersRoundtrip() throws {
        try withTestDefaults {
            let members = [
                BoardMember(id: "a", displayName: "Alice", vo2Max: 50.0, weeklyKilometers: 30.0, lastUpdated: Date(timeIntervalSince1970: 1_000_000)),
                BoardMember(id: "b", displayName: "Bob", vo2Max: nil, weeklyKilometers: 15.5, lastUpdated: Date(timeIntervalSince1970: 2_000_000)),
            ]
            SharedDataStore.cacheMembers(members)
            let loaded = SharedDataStore.loadCachedMembers()
            #expect(loaded == members)
        }
    }

    @Test func loadCachedMembersReturnsEmptyWhenNoCache() throws {
        try withTestDefaults {
            let loaded = SharedDataStore.loadCachedMembers()
            #expect(loaded.isEmpty)
        }
    }

    @Test func clearCacheRemovesCachedMembers() throws {
        try withTestDefaults {
            let members = [
                BoardMember(id: "c", displayName: "Charlie", vo2Max: 45.0, weeklyKilometers: 20.0, lastUpdated: Date())
            ]
            SharedDataStore.cacheMembers(members)
            SharedDataStore.clearCache()
            let loaded = SharedDataStore.loadCachedMembers()
            #expect(loaded.isEmpty)
        }
    }

    @Test func boardCodeGetSet() throws {
        try withTestDefaults {
            #expect(SharedDataStore.boardCode == nil)
            SharedDataStore.boardCode = "ABC123"
            #expect(SharedDataStore.boardCode == "ABC123")
        }
    }

    @Test func myRecordNameGetSet() throws {
        try withTestDefaults {
            #expect(SharedDataStore.myRecordName == nil)
            SharedDataStore.myRecordName = "record-42"
            #expect(SharedDataStore.myRecordName == "record-42")
        }
    }

    @Test func displayNameGetSet() throws {
        try withTestDefaults {
            #expect(SharedDataStore.displayName == nil)
            SharedDataStore.displayName = "TestUser"
            #expect(SharedDataStore.displayName == "TestUser")
        }
    }

    @Test func settingPropertyToNilClearsIt() throws {
        try withTestDefaults {
            SharedDataStore.boardCode = "XYZ"
            SharedDataStore.boardCode = nil
            #expect(SharedDataStore.boardCode == nil)
        }
    }

    @Test func cacheMultipleMembersWithHistory() throws {
        try withTestDefaults {
            let history = [
                WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 1_000_000), weeklyKilometers: 25.0, vo2Max: 48.0),
                WeeklySnapshot(weekStart: Date(timeIntervalSince1970: 2_000_000), weeklyKilometers: 30.0, vo2Max: 49.5),
            ]
            let members = [
                BoardMember(id: "d", displayName: "Dana", vo2Max: 49.5, weeklyKilometers: 30.0, lastUpdated: Date(), isCurrentUser: true, statsHistory: history)
            ]
            SharedDataStore.cacheMembers(members)
            let loaded = SharedDataStore.loadCachedMembers()
            #expect(loaded.first?.statsHistory.count == 2)
            #expect(loaded.first?.isCurrentUser == true)
        }
    }
}
