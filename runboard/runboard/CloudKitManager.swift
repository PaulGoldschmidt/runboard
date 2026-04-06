//
//  CloudKitManager.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import Foundation
import CloudKit
import Observation

struct BoardMember: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var vo2Max: Double?
    var weeklyKilometers: Double
    var lastUpdated: Date
    var isCurrentUser: Bool = false
}

private enum Keys {
    static let boardCode = "boardCode"
    static let myRecordName = "myRecordName"
    static let displayName = "displayName"
    static let cachedMembers = "cachedMembers"
}

private enum RecordField {
    static let displayName = "displayName"
    static let vo2Max = "vo2Max"
    static let weeklyKilometers = "weeklyKilometers"
    static let lastUpdated = "lastUpdated"
    static let creatorName = "creatorName"
    static let creatorRecordName = "creatorRecordName"
    static let memberRecordNames = "memberRecordNames"
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
    var errorMessage: String?

    private let container = CKContainer(identifier: "iCloud.p3g3.runboard")
    private var database: CKDatabase { container.publicCloudDatabase }

    var hasBoard: Bool { currentBoardCode != nil }
    var isCreator: Bool { myRecordName != nil && myRecordName == boardCreatorRecordName }

    init() {
        currentBoardCode = UserDefaults.standard.string(forKey: Keys.boardCode)
        myRecordName = UserDefaults.standard.string(forKey: Keys.myRecordName)
        myDisplayName = UserDefaults.standard.string(forKey: Keys.displayName)
    }

    private func persist() {
        UserDefaults.standard.set(currentBoardCode, forKey: Keys.boardCode)
        UserDefaults.standard.set(myRecordName, forKey: Keys.myRecordName)
        UserDefaults.standard.set(myDisplayName, forKey: Keys.displayName)
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
        defer { isLoading = false }

        do {
            let boardID = CKRecord.ID(recordName: code)
            let boardRecord = try await database.record(for: boardID)

            boardCreatorName = boardRecord[RecordField.creatorName] as? String
            boardCreatorRecordName = boardRecord[RecordField.creatorRecordName] as? String
            boardCreatedDate = boardRecord.creationDate

            let memberNames = (boardRecord[RecordField.memberRecordNames] as? [String]) ?? []
            let memberIDs = memberNames.map { CKRecord.ID(recordName: $0) }

            let fetched = await fetchMemberRecords(ids: memberIDs)

            if members != fetched {
                members = fetched
                cacheMembers(fetched)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not load board."
            members = loadCachedMembers()
        }
    }

    func updateMyStats(vo2Max: Double?, weeklyKilometers: Double) async {
        guard let recordName = myRecordName else { return }

        let recordID = CKRecord.ID(recordName: recordName)

        do {
            let record = try await database.record(for: recordID)
            record[RecordField.vo2Max] = vo2Max.map { $0 as CKRecordValue }
            record[RecordField.weeklyKilometers] = weeklyKilometers
            record[RecordField.lastUpdated] = Date()
            try await database.save(record)
        } catch {
            errorMessage = "Could not sync your stats."
        }
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
        clearCache()
    }

    func removeMember(_ member: BoardMember) async {
        guard isCreator, !member.isCurrentUser, let code = currentBoardCode else { return }

        await removeMemberFromBoard(memberRecordName: member.id, boardCode: code)

        members.removeAll { $0.id == member.id }
        cacheMembers(members)
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

    private func fetchMemberRecords(ids: [CKRecord.ID]) async -> [BoardMember] {
        let db = database
        let currentRecordName = myRecordName
        return await withTaskGroup(of: BoardMember?.self) { group in
            for memberID in ids {
                group.addTask {
                    guard let record = try? await db.record(for: memberID) else { return nil }
                    return BoardMember(
                        id: memberID.recordName,
                        displayName: record[RecordField.displayName] as? String ?? "Unknown",
                        vo2Max: record[RecordField.vo2Max] as? Double,
                        weeklyKilometers: record[RecordField.weeklyKilometers] as? Double ?? 0.0,
                        lastUpdated: record[RecordField.lastUpdated] as? Date ?? Date(),
                        isCurrentUser: memberID.recordName == currentRecordName
                    )
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

    private func cacheMembers(_ members: [BoardMember]) {
        if let data = try? JSONEncoder().encode(members) {
            UserDefaults.standard.set(data, forKey: Keys.cachedMembers)
        }
    }

    private func loadCachedMembers() -> [BoardMember] {
        guard let data = UserDefaults.standard.data(forKey: Keys.cachedMembers),
              let members = try? JSONDecoder().decode([BoardMember].self, from: data) else {
            return []
        }
        return members
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: Keys.cachedMembers)
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
