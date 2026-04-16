//
//  SharedModels.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import Foundation

struct WeeklySnapshot: Codable, Equatable, Identifiable {
    let weekStart: Date
    var weeklyKilometers: Double
    var vo2Max: Double?
    var id: Date { weekStart }
}

struct BoardMember: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var vo2Max: Double?
    var weeklyKilometers: Double
    var lastUpdated: Date
    var isCurrentUser: Bool = false
    var statsHistory: [WeeklySnapshot] = []
    var joinedDate: Date?
}

enum StatType: String, CaseIterable {
    case weeklyKm = "WEEKLY KM"
    case vo2Max = "VO2 MAX"
}

extension Array where Element == BoardMember {
    /// Merges entries that share the same normalized name and weeklyKm (rounded to 1 decimal).
    /// VO2 Max is treated as a wildcard when nil — `nil` merges with any non-nil value.
    /// If two entries in the same name+km group carry distinct non-nil VO2 values, the group
    /// is treated as a real conflict and all entries are preserved.
    func deduplicatedByNameAndStats() -> [BoardMember] {
        guard count > 1 else { return self }

        var groupOrder: [String] = []
        var groups: [String: [BoardMember]] = [:]

        for member in self {
            let key = BoardMember.dedupBucketKey(for: member)
            if groups[key] == nil {
                groupOrder.append(key)
                groups[key] = []
            }
            groups[key]?.append(member)
        }

        var result: [BoardMember] = []
        for key in groupOrder {
            guard let group = groups[key] else { continue }
            if group.count == 1 {
                result.append(group[0])
                continue
            }
            let distinctVo2s = Set(group.compactMap { $0.vo2Max.map(BoardMember.roundedToTenth) })
            if distinctVo2s.count <= 1 {
                result.append(BoardMember.merge(group))
            } else {
                result.append(contentsOf: group)
            }
        }
        return result
    }
}

extension BoardMember {
    fileprivate static func roundedToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    fileprivate static func dedupBucketKey(for member: BoardMember) -> String {
        let name = member.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(name)|\(roundedToTenth(member.weeklyKilometers))"
    }

    fileprivate static func merge(_ group: [BoardMember]) -> BoardMember {
        let ranked = group.sorted { a, b in
            if a.isCurrentUser != b.isCurrentUser { return a.isCurrentUser }
            if a.lastUpdated != b.lastUpdated { return a.lastUpdated > b.lastUpdated }
            return a.id < b.id
        }
        let canonical = ranked[0]

        let vo2 = group
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .compactMap { $0.vo2Max }
            .first

        var historyByWeek: [Date: (snapshot: WeeklySnapshot, updated: Date)] = [:]
        for member in group {
            for snap in member.statsHistory {
                if let existing = historyByWeek[snap.weekStart], existing.updated >= member.lastUpdated {
                    continue
                }
                historyByWeek[snap.weekStart] = (snap, member.lastUpdated)
            }
        }

        return BoardMember(
            id: canonical.id,
            displayName: canonical.displayName,
            vo2Max: vo2,
            weeklyKilometers: canonical.weeklyKilometers,
            lastUpdated: group.map { $0.lastUpdated }.max() ?? canonical.lastUpdated,
            isCurrentUser: group.contains { $0.isCurrentUser },
            statsHistory: historyByWeek.values.map { $0.snapshot }.sorted { $0.weekStart < $1.weekStart },
            joinedDate: group.compactMap { $0.joinedDate }.min()
        )
    }
}
