//
//  CloudKitManager.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import Foundation
import CloudKit
import Observation

struct BoardMember: Identifiable, Codable {
    let id: String
    var displayName: String
    var vo2Max: Double?
    var weeklyKilometers: Double
    var lastUpdated: Date
    var isCurrentUser: Bool = false
}

@Observable
final class CloudKitManager {
    var members: [BoardMember] = []
    var currentBoardCode: String?
    var myRecordName: String?
    var myDisplayName: String?
    var boardCreatorName: String?
    var boardCreatedDate: Date?
    var isLoading = false
    var errorMessage: String?

    private let container = CKContainer(identifier: "iCloud.p3g3.runboard")
    private var database: CKDatabase { container.publicCloudDatabase }

    var hasBoard: Bool { currentBoardCode != nil }
    var isCreator: Bool { myDisplayName != nil && myDisplayName == boardCreatorName }

    init() {
        currentBoardCode = UserDefaults.standard.string(forKey: "boardCode")
        myRecordName = UserDefaults.standard.string(forKey: "myRecordName")
        myDisplayName = UserDefaults.standard.string(forKey: "displayName")
    }

    private func persist() {
        UserDefaults.standard.set(currentBoardCode, forKey: "boardCode")
        UserDefaults.standard.set(myRecordName, forKey: "myRecordName")
        UserDefaults.standard.set(myDisplayName, forKey: "displayName")
    }

    // MARK: - Board Operations

    func createBoard(displayName: String) async throws {
        let code = generateBoardCode()

        // Create the member record with a deterministic ID
        let memberID = CKRecord.ID(recordName: "\(code)_\(UUID().uuidString)")
        let memberRecord = CKRecord(recordType: "BoardMember", recordID: memberID)
        memberRecord["displayName"] = displayName
        memberRecord["vo2Max"] = 0.0
        memberRecord["weeklyKilometers"] = 0.0
        memberRecord["lastUpdated"] = Date()

        // Create the board record with the code as its record ID
        let boardID = CKRecord.ID(recordName: code)
        let boardRecord = CKRecord(recordType: "Board", recordID: boardID)
        boardRecord["creatorName"] = displayName
        boardRecord["memberRecordNames"] = [memberID.recordName] as [String]

        // Save both
        try await database.save(memberRecord)
        try await database.save(boardRecord)

        currentBoardCode = code
        myRecordName = memberID.recordName
        myDisplayName = displayName
        boardCreatorName = displayName
        boardCreatedDate = Date()
        persist()
    }

    func joinBoard(code: String, displayName: String) async throws {
        let upperCode = code.uppercased()
        let boardID = CKRecord.ID(recordName: upperCode)

        // Fetch the board record by ID — no query needed
        let boardRecord: CKRecord
        do {
            boardRecord = try await database.record(for: boardID)
        } catch {
            throw BoardError.boardNotFound
        }

        // Create the member record
        let memberID = CKRecord.ID(recordName: "\(upperCode)_\(UUID().uuidString)")
        let memberRecord = CKRecord(recordType: "BoardMember", recordID: memberID)
        memberRecord["displayName"] = displayName
        memberRecord["vo2Max"] = 0.0
        memberRecord["weeklyKilometers"] = 0.0
        memberRecord["lastUpdated"] = Date()

        try await database.save(memberRecord)

        // Add to the board's member list
        var memberNames = (boardRecord["memberRecordNames"] as? [String]) ?? []
        memberNames.append(memberID.recordName)
        boardRecord["memberRecordNames"] = memberNames as [String]
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
            // Fetch the board record by ID
            let boardID = CKRecord.ID(recordName: code)
            let boardRecord = try await database.record(for: boardID)

            boardCreatorName = boardRecord["creatorName"] as? String
            boardCreatedDate = boardRecord.creationDate

            // Get the member record names
            let memberNames = (boardRecord["memberRecordNames"] as? [String]) ?? []

            // Fetch each member by ID
            let memberIDs = memberNames.map { CKRecord.ID(recordName: $0) }
            var fetched: [BoardMember] = []

            for memberID in memberIDs {
                do {
                    let record = try await database.record(for: memberID)
                    let member = BoardMember(
                        id: memberID.recordName,
                        displayName: record["displayName"] as? String ?? "Unknown",
                        vo2Max: zeroToNil(record["vo2Max"] as? Double),
                        weeklyKilometers: record["weeklyKilometers"] as? Double ?? 0.0,
                        lastUpdated: record["lastUpdated"] as? Date ?? Date(),
                        isCurrentUser: memberID.recordName == myRecordName
                    )
                    fetched.append(member)
                } catch {
                    // Member record may have been deleted — skip it
                }
            }

            members = fetched
            cacheMembers(fetched)
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
            record["vo2Max"] = vo2Max ?? 0.0
            record["weeklyKilometers"] = weeklyKilometers
            record["lastUpdated"] = Date()
            try await database.save(record)
        } catch {
            errorMessage = "Could not sync your stats."
        }
    }

    func leaveBoard() async {
        // Remove member record from board's list
        if let code = currentBoardCode, let recordName = myRecordName {
            let boardID = CKRecord.ID(recordName: code)
            if let boardRecord = try? await database.record(for: boardID) {
                var memberNames = (boardRecord["memberRecordNames"] as? [String]) ?? []
                memberNames.removeAll { $0 == recordName }
                boardRecord["memberRecordNames"] = memberNames as [String]
                _ = try? await database.save(boardRecord)
            }

            // Delete member record
            let memberID = CKRecord.ID(recordName: recordName)
            _ = try? await database.deleteRecord(withID: memberID)
        }

        currentBoardCode = nil
        myRecordName = nil
        myDisplayName = nil
        boardCreatorName = nil
        boardCreatedDate = nil
        persist()
        members = []
        clearCache()
    }

    func removeMember(_ member: BoardMember) async {
        guard isCreator, !member.isCurrentUser, let code = currentBoardCode else { return }

        // Remove from board's member list
        let boardID = CKRecord.ID(recordName: code)
        if let boardRecord = try? await database.record(for: boardID) {
            var memberNames = (boardRecord["memberRecordNames"] as? [String]) ?? []
            memberNames.removeAll { $0 == member.id }
            boardRecord["memberRecordNames"] = memberNames as [String]
            _ = try? await database.save(boardRecord)
        }

        // Delete the member's record
        let memberID = CKRecord.ID(recordName: member.id)
        _ = try? await database.deleteRecord(withID: memberID)

        // Update local state
        members.removeAll { $0.id == member.id }
        cacheMembers(members)
    }

    // MARK: - Helpers

    private func generateBoardCode() -> String {
        let chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    private func zeroToNil(_ value: Double?) -> Double? {
        guard let v = value, v > 0 else { return nil }
        return v
    }

    private func cacheMembers(_ members: [BoardMember]) {
        if let data = try? JSONEncoder().encode(members) {
            UserDefaults.standard.set(data, forKey: "cachedMembers")
        }
    }

    private func loadCachedMembers() -> [BoardMember] {
        guard let data = UserDefaults.standard.data(forKey: "cachedMembers"),
              let members = try? JSONDecoder().decode([BoardMember].self, from: data) else {
            return []
        }
        return members
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: "cachedMembers")
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
