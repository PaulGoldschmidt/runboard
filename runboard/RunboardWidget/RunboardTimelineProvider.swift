//
//  RunboardTimelineProvider.swift
//  RunboardWidget
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import WidgetKit
import CloudKit

struct RunboardEntry: TimelineEntry {
    let date: Date
    let members: [BoardMember]
    let boardCode: String?
    let myRecordName: String?
    let statType: WidgetStatType
    let isPlaceholder: Bool
}

struct RunboardTimelineProvider: AppIntentTimelineProvider {
    private let container = CKContainer(identifier: SharedDataStore.cloudKitContainerID)

    func placeholder(in context: Context) -> RunboardEntry {
        RunboardEntry(
            date: .now,
            members: Self.placeholderMembers,
            boardCode: "ABC123",
            myRecordName: nil,
            statType: .weeklyKm,
            isPlaceholder: true
        )
    }

    func snapshot(for configuration: RunboardWidgetIntent, in context: Context) async -> RunboardEntry {
        let members = sortedMembers(for: configuration.statType)
        return RunboardEntry(
            date: .now,
            members: members,
            boardCode: SharedDataStore.boardCode,
            myRecordName: SharedDataStore.myRecordName,
            statType: configuration.statType,
            isPlaceholder: false
        )
    }

    func timeline(for configuration: RunboardWidgetIntent, in context: Context) async -> Timeline<RunboardEntry> {
        let fetched = await fetchMembers()
        let sorted = Self.sorted(fetched, by: configuration.statType)

        let entry = RunboardEntry(
            date: .now,
            members: sorted,
            boardCode: SharedDataStore.boardCode,
            myRecordName: SharedDataStore.myRecordName,
            statType: configuration.statType,
            isPlaceholder: false
        )

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    // MARK: - CloudKit Fetch

    private func fetchMembers() async -> [BoardMember] {
        guard let code = SharedDataStore.boardCode else {
            return SharedDataStore.loadCachedMembers()
        }

        let db = container.publicCloudDatabase
        let boardID = CKRecord.ID(recordName: code)

        do {
            let boardRecord = try await db.record(for: boardID)
            let memberNames = (boardRecord["memberRecordNames"] as? [String]) ?? []
            let memberIDs = memberNames.map { CKRecord.ID(recordName: $0) }
            let myRecordName = SharedDataStore.myRecordName

            let members: [BoardMember] = await withTaskGroup(of: BoardMember?.self) { group in
                for memberID in memberIDs {
                    group.addTask {
                        guard let record = try? await db.record(for: memberID) else { return nil }
                        return BoardMember(
                            id: memberID.recordName,
                            displayName: record["displayName"] as? String ?? "Unknown",
                            vo2Max: record["vo2Max"] as? Double,
                            weeklyKilometers: record["weeklyKilometers"] as? Double ?? 0.0,
                            lastUpdated: record["lastUpdated"] as? Date ?? Date(),
                            isCurrentUser: memberID.recordName == myRecordName
                        )
                    }
                }
                var results: [BoardMember] = []
                for await member in group {
                    if let member { results.append(member) }
                }
                return results
            }

            let deduped = members.deduplicatedByNameAndStats()
            SharedDataStore.cacheMembers(deduped)
            return deduped
        } catch {
            return SharedDataStore.loadCachedMembers()
        }
    }

    private func sortedMembers(for statType: WidgetStatType) -> [BoardMember] {
        Self.sorted(SharedDataStore.loadCachedMembers(), by: statType)
    }

    private static func sorted(_ members: [BoardMember], by statType: WidgetStatType) -> [BoardMember] {
        let active = members.activeMembers()
        switch statType {
        case .weeklyKm:
            return active.sorted { $0.weeklyKilometers > $1.weeklyKilometers }
        case .vo2Max:
            return active.sorted { ($0.vo2Max ?? -1) > ($1.vo2Max ?? -1) }
        }
    }

    // MARK: - Placeholder Data

    static let placeholderMembers: [BoardMember] = [
        BoardMember(id: "1", displayName: "RUNNER A", weeklyKilometers: 42.5, lastUpdated: .now, isCurrentUser: true),
        BoardMember(id: "2", displayName: "RUNNER B", weeklyKilometers: 38.2, lastUpdated: .now),
        BoardMember(id: "3", displayName: "RUNNER C", weeklyKilometers: 27.1, lastUpdated: .now),
        BoardMember(id: "4", displayName: "RUNNER D", weeklyKilometers: 21.0, lastUpdated: .now),
        BoardMember(id: "5", displayName: "RUNNER E", weeklyKilometers: 15.3, lastUpdated: .now),
    ]
}
