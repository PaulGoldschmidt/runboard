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

private func roundedToTenth(_ value: Double) -> Double {
    (value * 10).rounded() / 10
}

private struct DedupBucketKey: Hashable {
    let name: String
    let weeklyKm: Double
}

extension Array where Element == BoardMember {
    /// Merges entries that share the same normalized name and weeklyKm (rounded to 1 decimal).
    /// VO2 Max is treated as a wildcard when nil — `nil` merges with any non-nil value.
    /// If two entries in the same name+km group carry distinct non-nil VO2 values, the group
    /// is treated as a real conflict and all entries are preserved.
    func deduplicatedByNameAndStats() -> [BoardMember] {
        guard count > 1 else { return self }

        let groups = Dictionary(grouping: self) { member in
            DedupBucketKey(
                name: member.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                weeklyKm: roundedToTenth(member.weeklyKilometers)
            )
        }

        var result: [BoardMember] = []
        result.reserveCapacity(groups.count)
        for group in groups.values {
            if group.count == 1 {
                result.append(group[0])
                continue
            }
            let distinctVo2s = Set(group.compactMap { $0.vo2Max.map(roundedToTenth) })
            if distinctVo2s.count <= 1 {
                result.append(BoardMember.merge(group))
            } else {
                result.append(contentsOf: group)
            }
        }
        return result
    }
}

extension Array where Element == BoardMember {
    /// Members whose data is fresh enough to show on the board. Members who
    /// haven't submitted anything for `days` days (default: two weeks) are
    /// hidden; the current user is always kept so their own row stays visible.
    func activeMembers(within days: Int = 14, asOf now: Date = Date()) -> [BoardMember] {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        return filter { $0.isCurrentUser || $0.lastUpdated > cutoff }
    }
}

extension BoardMember {
    fileprivate static func merge(_ group: [BoardMember]) -> BoardMember {
        let canonical = group.max { a, b in
            if a.isCurrentUser != b.isCurrentUser { return b.isCurrentUser }
            if a.lastUpdated != b.lastUpdated { return a.lastUpdated < b.lastUpdated }
            return a.id > b.id
        }!

        let vo2 = group
            .filter { $0.vo2Max != nil }
            .max { $0.lastUpdated < $1.lastUpdated }
            .flatMap { $0.vo2Max }

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
            lastUpdated: group.lazy.map(\.lastUpdated).max()!,
            isCurrentUser: group.contains { $0.isCurrentUser },
            statsHistory: historyByWeek.values.map(\.snapshot).sorted { $0.weekStart < $1.weekStart },
            joinedDate: group.compactMap(\.joinedDate).min()
        )
    }
}
