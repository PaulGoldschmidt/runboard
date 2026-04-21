//
//  CloudKitManager.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import Foundation
import CloudKit
import Observation
import os
import WidgetKit

private enum RecordField {
    static let displayName = "displayName"
    static let vo2Max = "vo2Max"
    static let weeklyKilometers = "weeklyKilometers"
    static let lastUpdated = "lastUpdated"
    static let creatorName = "creatorName"
    static let creatorRecordName = "creatorRecordName"
    static let memberRecordNames = "memberRecordNames"
    static let statsHistory = "statsHistory"
}

@Observable
final class CloudKitManager {
    var members: [BoardMember] = []
    var currentBoardCode: String?
    var myRecordName: String?
    var myDisplayName: String?
    var boardCreatorName: String?
    var boardCreatorRecordName: String?
    var boardCreatedDate: Date?
    var isLoading = false
    var hasFetched = false
    var errorMessage: String?

    private let container = CKContainer(identifier: SharedDataStore.cloudKitContainerID)
    private var database: CKDatabase { container.publicCloudDatabase }

    var hasBoard: Bool { currentBoardCode != nil }
    var isCreator: Bool { myRecordName != nil && myRecordName == boardCreatorRecordName }

    init() {
        currentBoardCode = SharedDataStore.boardCode
        myRecordName = SharedDataStore.myRecordName
        myDisplayName = SharedDataStore.displayName
    }

    private func persist() {
        SharedDataStore.boardCode = currentBoardCode
        SharedDataStore.myRecordName = myRecordName
        SharedDataStore.displayName = myDisplayName
    }

    // MARK: - Board Operations

    func createBoard(displayName: String) async throws {
        let code = generateBoardCode()

        let memberID = CKRecord.ID(recordName: "\(code)_\(UUID().uuidString)")
        let memberRecord = makeMemberRecord(id: memberID, displayName: displayName)

        let boardID = CKRecord.ID(recordName: code)
        let boardRecord = CKRecord(recordType: "Board", recordID: boardID)
        boardRecord[RecordField.creatorName] = displayName
        boardRecord[RecordField.creatorRecordName] = memberID.recordName
        boardRecord[RecordField.memberRecordNames] = [memberID.recordName] as [String]

        async let saveMember: Void = { _ = try await self.database.save(memberRecord) }()
        async let saveBoard: Void = { _ = try await self.database.save(boardRecord) }()
        _ = try await (saveMember, saveBoard)

        currentBoardCode = code
        myRecordName = memberID.recordName
        myDisplayName = displayName
        boardCreatorName = displayName
        boardCreatorRecordName = memberID.recordName
        boardCreatedDate = Date()
        persist()
    }

    func joinBoard(code: String, displayName: String) async throws {
        let upperCode = code.uppercased()
        let boardID = CKRecord.ID(recordName: upperCode)

        let boardRecord: CKRecord
        do {
            boardRecord = try await database.record(for: boardID)
        } catch {
            throw BoardError.boardNotFound
        }

        let memberID = CKRecord.ID(recordName: "\(upperCode)_\(UUID().uuidString)")
        let memberRecord = makeMemberRecord(id: memberID, displayName: displayName)
        try await database.save(memberRecord)

        var memberNames = (boardRecord[RecordField.memberRecordNames] as? [String]) ?? []
        memberNames.append(memberID.recordName)
        boardRecord[RecordField.memberRecordNames] = memberNames as [String]
        try await database.save(boardRecord)

        currentBoardCode = upperCode
        myRecordName = memberID.recordName
        myDisplayName = displayName
        persist()
    }

    func fetchBoardMembers() async {
        guard let code = currentBoardCode else { return }

        isLoading = true
        defer {
            isLoading = false
            hasFetched = true
        }

        do {
            let boardID = CKRecord.ID(recordName: code)
            let boardRecord = try await database.record(for: boardID)

            boardCreatorName = boardRecord[RecordField.creatorName] as? String
            boardCreatorRecordName = boardRecord[RecordField.creatorRecordName] as? String
            boardCreatedDate = boardRecord.creationDate

            let memberNames = (boardRecord[RecordField.memberRecordNames] as? [String]) ?? []
            let memberIDs = memberNames.map { CKRecord.ID(recordName: $0) }

            let fetched = await fetchMemberRecords(ids: memberIDs).deduplicatedByNameAndStats()

            if members != fetched {
                members = fetched
                SharedDataStore.cacheMembers(fetched)
                WidgetCenter.shared.reloadAllTimelines()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not load board."
            members = SharedDataStore.loadCachedMembers()
        }
    }

    func updateMyStats(vo2Max: Double?, weeklyKilometers: Double) async throws {
        guard let recordName = myRecordName else { return }
        let recordID = CKRecord.ID(recordName: recordName)
        let weekStart = Self.currentWeekStart()

        do {
            try await saveWithMerge(recordID: recordID) { record in
                Self.applyStatsUpdate(
                    to: record,
                    vo2Max: vo2Max,
                    weeklyKilometers: weeklyKilometers,
                    weekStart: weekStart
                )
            }
            errorMessage = nil
        } catch {
            SyncLog.cloudkit.error("updateMyStats failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not sync your stats."
            throw error
        }
    }

    private func saveWithMerge(
        recordID: CKRecord.ID,
        maxRetries: Int = 3,
        mutate: @escaping @Sendable (CKRecord) -> Void
    ) async throws {
        let db = database
        var attempt = 0

        while true {
            attempt += 1
            let record: CKRecord
            do {
                record = try await db.record(for: recordID)
            } catch {
                SyncLog.cloudkit.error("fetch before merge failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }

            mutate(record)

            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .ifServerRecordUnchanged

            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    operation.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success: continuation.resume()
                        case .failure(let error): continuation.resume(throwing: error)
                        }
                    }
                    db.add(operation)
                }
                return
            } catch let ckError as CKError where ckError.code == .serverRecordChanged {
                guard attempt < maxRetries else {
                    SyncLog.cloudkit.fault("serverRecordChanged retries exhausted")
                    throw ckError
                }
                SyncLog.cloudkit.info("serverRecordChanged — retry \(attempt, privacy: .public)")
                continue
            } catch {
                throw error
            }
        }
    }

    nonisolated static func applyStatsUpdate(
        to record: CKRecord,
        vo2Max: Double?,
        weeklyKilometers: Double,
        weekStart: Date
    ) {
        record[RecordField.vo2Max] = vo2Max.map { $0 as CKRecordValue }
        record[RecordField.weeklyKilometers] = weeklyKilometers
        record[RecordField.lastUpdated] = Date()

        var history = Self.decodeHistoryRaw(record)
        let incoming = WeeklySnapshot(weekStart: weekStart, weeklyKilometers: weeklyKilometers, vo2Max: vo2Max)
        history = Self.mergeHistory(history, with: incoming)

        if let data = try? JSONEncoder().encode(history), let json = String(data: data, encoding: .utf8) {
            record[RecordField.statsHistory] = json
        }
    }

    /// Union by `weekStart`. For the incoming week, take `max(weeklyKilometers)` across client & server
    /// (weekly distance is monotonic within an open week), and prefer a non-nil incoming vo2Max.
    /// Sorted descending by weekStart, capped to the most recent 52 entries.
    nonisolated static func mergeHistory(_ existing: [WeeklySnapshot], with incoming: WeeklySnapshot) -> [WeeklySnapshot] {
        var byWeek: [Date: WeeklySnapshot] = [:]
        for snap in existing { byWeek[snap.weekStart] = snap }

        if let current = byWeek[incoming.weekStart] {
            byWeek[incoming.weekStart] = WeeklySnapshot(
                weekStart: incoming.weekStart,
                weeklyKilometers: max(current.weeklyKilometers, incoming.weeklyKilometers),
                vo2Max: incoming.vo2Max ?? current.vo2Max
            )
        } else {
            byWeek[incoming.weekStart] = incoming
        }

        let sorted = byWeek.values.sorted { $0.weekStart > $1.weekStart }
        return Array(sorted.prefix(52))
    }

    nonisolated private static func decodeHistoryRaw(_ record: CKRecord) -> [WeeklySnapshot] {
        guard let json = record["statsHistory"] as? String,
              let data = json.data(using: .utf8),
              let history = try? JSONDecoder().decode([WeeklySnapshot].self, from: data) else {
            return []
        }
        return history
    }

    func leaveBoard() async {
        if let code = currentBoardCode, let recordName = myRecordName {
            await removeMemberFromBoard(memberRecordName: recordName, boardCode: code)
        }

        currentBoardCode = nil
        myRecordName = nil
        myDisplayName = nil
        boardCreatorName = nil
        boardCreatorRecordName = nil
        boardCreatedDate = nil
        persist()
        members = []
        SharedDataStore.clearCache()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func removeMember(_ member: BoardMember) async {
        guard isCreator, !member.isCurrentUser, let code = currentBoardCode else { return }

        await removeMemberFromBoard(memberRecordName: member.id, boardCode: code)

        members.removeAll { $0.id == member.id }
        SharedDataStore.cacheMembers(members)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Private Helpers

    private func makeMemberRecord(id: CKRecord.ID, displayName: String) -> CKRecord {
        let record = CKRecord(recordType: "BoardMember", recordID: id)
        record[RecordField.displayName] = displayName
        record[RecordField.weeklyKilometers] = 0.0
        record[RecordField.lastUpdated] = Date()
        return record
    }

    private func removeMemberFromBoard(memberRecordName: String, boardCode: String) async {
        let boardID = CKRecord.ID(recordName: boardCode)
        if let boardRecord = try? await database.record(for: boardID) {
            var names = (boardRecord[RecordField.memberRecordNames] as? [String]) ?? []
            names.removeAll { $0 == memberRecordName }
            boardRecord[RecordField.memberRecordNames] = names as [String]
            _ = try? await database.save(boardRecord)
        }

        let memberID = CKRecord.ID(recordName: memberRecordName)
        _ = try? await database.deleteRecord(withID: memberID)
    }

    nonisolated private func parseMember(from record: CKRecord, id: CKRecord.ID, currentRecordName: String?) -> BoardMember {
        BoardMember(
            id: id.recordName,
            displayName: record["displayName"] as? String ?? "Unknown",
            vo2Max: record["vo2Max"] as? Double,
            weeklyKilometers: record["weeklyKilometers"] as? Double ?? 0.0,
            lastUpdated: record["lastUpdated"] as? Date ?? Date(),
            isCurrentUser: id.recordName == currentRecordName,
            statsHistory: decodeHistory(from: record),
            joinedDate: record.creationDate
        )
    }

    nonisolated private func decodeHistory(from record: CKRecord) -> [WeeklySnapshot] {
        guard let json = record["statsHistory"] as? String,
              let data = json.data(using: .utf8),
              let history = try? JSONDecoder().decode([WeeklySnapshot].self, from: data) else {
            return []
        }
        return history.sorted { $0.weekStart < $1.weekStart }
    }

    nonisolated static func currentWeekStart() -> Date {
        let calendar = Calendar(identifier: .iso8601)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? Date()
    }

    private func fetchMemberRecords(ids: [CKRecord.ID]) async -> [BoardMember] {
        let db = database
        let currentRecordName = myRecordName
        return await withTaskGroup(of: BoardMember?.self) { group in
            for memberID in ids {
                group.addTask { [self] in
                    guard let record = try? await db.record(for: memberID) else { return nil }
                    return self.parseMember(from: record, id: memberID, currentRecordName: currentRecordName)
                }
            }

            var results: [BoardMember] = []
            for await member in group {
                if let member { results.append(member) }
            }
            return results
        }
    }

    private func generateBoardCode() -> String {
        let chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

}

enum BoardError: LocalizedError {
    case boardNotFound

    var errorDescription: String? {
        switch self {
        case .boardNotFound:
            return "No board found with that code."
        }
    }
}
