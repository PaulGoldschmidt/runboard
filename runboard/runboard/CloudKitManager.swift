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
    let boardCode: String
    var displayName: String
    var vo2Max: Double?
    var weeklyKilometers: Double
    var lastUpdated: Date
    var isCurrentUser: Bool = false
}

@Observable
final class CloudKitManager {
    var members: [BoardMember] = []
    var currentBoardCode: String? {
        get { UserDefaults.standard.string(forKey: "boardCode") }
        set { UserDefaults.standard.set(newValue, forKey: "boardCode") }
    }
    var myRecordName: String? {
        get { UserDefaults.standard.string(forKey: "myRecordName") }
        set { UserDefaults.standard.set(newValue, forKey: "myRecordName") }
    }
    var myDisplayName: String? {
        get { UserDefaults.standard.string(forKey: "displayName") }
        set { UserDefaults.standard.set(newValue, forKey: "displayName") }
    }
    var isLoading = false
    var errorMessage: String?

    private let container = CKContainer(identifier: "iCloud.p3g3.runboard")
    private var database: CKDatabase { container.publicCloudDatabase }

    var hasBoard: Bool { currentBoardCode != nil }

    // MARK: - Board Operations

    func createBoard(displayName: String) async throws {
        let code = generateBoardCode()
        let record = CKRecord(recordType: "BoardMember")
        record["boardCode"] = code
        record["displayName"] = displayName
        record["vo2Max"] = 0.0
        record["weeklyKilometers"] = 0.0
        record["lastUpdated"] = Date()

        let saved = try await database.save(record)

        currentBoardCode = code
        myRecordName = saved.recordID.recordName
        myDisplayName = displayName
    }

    func joinBoard(code: String, displayName: String) async throws {
        let upperCode = code.uppercased()

        // Verify board exists
        let predicate = NSPredicate(format: "boardCode == %@", upperCode)
        let query = CKQuery(recordType: "BoardMember", predicate: predicate)
        let (results, _) = try await database.records(matching: query, resultsLimit: 1)

        guard !results.isEmpty else {
            throw BoardError.boardNotFound
        }

        let record = CKRecord(recordType: "BoardMember")
        record["boardCode"] = upperCode
        record["displayName"] = displayName
        record["vo2Max"] = 0.0
        record["weeklyKilometers"] = 0.0
        record["lastUpdated"] = Date()

        let saved = try await database.save(record)

        currentBoardCode = upperCode
        myRecordName = saved.recordID.recordName
        myDisplayName = displayName
    }

    func fetchBoardMembers() async {
        guard let code = currentBoardCode else { return }

        isLoading = true
        defer { isLoading = false }

        let predicate = NSPredicate(format: "boardCode == %@", code)
        let query = CKQuery(recordType: "BoardMember", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "weeklyKilometers", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 50)
            var fetched: [BoardMember] = []

            for (recordID, result) in results {
                if case .success(let record) = result {
                    let member = BoardMember(
                        id: recordID.recordName,
                        boardCode: record["boardCode"] as? String ?? "",
                        displayName: record["displayName"] as? String ?? "Unknown",
                        vo2Max: zeroToNil(record["vo2Max"] as? Double),
                        weeklyKilometers: record["weeklyKilometers"] as? Double ?? 0.0,
                        lastUpdated: record["lastUpdated"] as? Date ?? Date(),
                        isCurrentUser: recordID.recordName == myRecordName
                    )
                    fetched.append(member)
                }
            }

            members = fetched
            cacheMembers(fetched)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load board members."
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
        if let recordName = myRecordName {
            let recordID = CKRecord.ID(recordName: recordName)
            _ = try? await database.deleteRecord(withID: recordID)
        }

        currentBoardCode = nil
        myRecordName = nil
        myDisplayName = nil
        members = []
        clearCache()
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
