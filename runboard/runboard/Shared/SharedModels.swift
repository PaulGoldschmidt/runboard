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

        let keyFor: (BoardMember) -> DedupBucketKey = { member in
            DedupBucketKey(
                name: member.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                weeklyKm: roundedToTenth(member.weeklyKilometers)
            )
        }
        let groups = Dictionary(grouping: self, by: keyFor)

        // Emit groups in first-occurrence order; iterating groups.values directly
        // would randomize the order per process (seeded dictionary hashing).
        var emitted = Set<DedupBucketKey>()
        var result: [BoardMember] = []
        result.reserveCapacity(groups.count)
        for member in self {
            let key = keyFor(member)
            guard emitted.insert(key).inserted, let group = groups[key] else { continue }
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

extension Array where Element == WeeklySnapshot {
    /// Decodes the statsHistory JSON stored on a member record, sorted by week
    /// ascending. Returns [] for missing or undecodable payloads.
    static func decodedHistory(fromJSON json: String?) -> [WeeklySnapshot] {
        guard let json,
              let data = json.data(using: .utf8),
              let history = try? JSONDecoder().decode([WeeklySnapshot].self, from: data) else {
            return []
        }
        return history.sorted { $0.weekStart < $1.weekStart }
    }
}

extension BoardMember {
    /// Fills a missing flat vo2Max from the newest history entry, for members
    /// whose flat field was wiped by an app version that cleared it on failed
    /// HealthKit reads. Must run AFTER deduplication: dedup treats a nil vo2 as
    /// a merge wildcard, and backfilling first would turn wiped ghost records
    /// into false vo2 conflicts that resurface as duplicate rows.
    func backfillingVo2FromHistory() -> BoardMember {
        guard vo2Max == nil,
              let historic = statsHistory.last(where: { $0.vo2Max != nil })?.vo2Max else { return self }
        var filled = self
        filled.vo2Max = historic
        return filled
    }
}

extension BoardMember {
    /// Kilometers to show for the running week. `weeklyKilometers` is whatever
    /// this member's own device last pushed; a push from before the current ISO
    /// week is last week's total, so it counts as 0 until they sync again.
    func currentWeekKilometers(asOf now: Date = Date()) -> Double {
        lastUpdated >= Self.weekStart(containing: now) ? weeklyKilometers : 0
    }

    static func weekStart(containing date: Date) -> Date {
        let calendar = Calendar(identifier: .iso8601)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
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
