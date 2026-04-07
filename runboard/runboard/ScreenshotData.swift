//
//  ScreenshotData.swift
//  runboard
//
//  Populates CloudKitManager with demo data when launched with --seeded.
//

import Foundation

enum ScreenshotData {
    static func seed(cloudKit: CloudKitManager) {
        let weekStarts = (0..<6).reversed().map { weeksAgo -> Date in
            Calendar(identifier: .iso8601).date(byAdding: .weekOfYear, value: -weeksAgo, to: CloudKitManager.currentWeekStart())!
        }

        func history(_ values: [(Double, Double?)]) -> [WeeklySnapshot] {
            zip(weekStarts, values).map { WeeklySnapshot(weekStart: $0, weeklyKilometers: $1.0, vo2Max: $1.1) }
        }

        let members: [BoardMember] = [
            BoardMember(
                id: "RUN42X_paul", displayName: "Paul", vo2Max: 52.1, weeklyKilometers: 47.2,
                lastUpdated: .now, isCurrentUser: true,
                statsHistory: history([(12.5, 48.2), (18.3, 49.0), (25.1, 50.1), (32.7, 50.8), (40.0, 51.5), (47.2, 52.1)])
            ),
            BoardMember(
                id: "RUN42X_max", displayName: "Max", vo2Max: 48.3, weeklyKilometers: 38.5,
                lastUpdated: .now,
                statsHistory: history([(20.0, 46.5), (25.5, 47.0), (30.2, 47.5), (28.1, 47.2), (35.0, 48.0), (38.5, 48.3)])
            ),
            BoardMember(
                id: "RUN42X_sophie", displayName: "Sophie", vo2Max: 45.7, weeklyKilometers: 31.8,
                lastUpdated: .now,
                statsHistory: history([(15.0, 43.0), (20.3, 43.8), (22.8, 44.2), (25.5, 44.8), (28.0, 45.2), (31.8, 45.7)])
            ),
            BoardMember(
                id: "RUN42X_lucas", displayName: "Lucas", vo2Max: 41.2, weeklyKilometers: 24.1,
                lastUpdated: .now,
                statsHistory: history([(10.5, 39.5), (15.2, 40.0), (18.0, 40.5), (20.5, 40.8), (22.0, 41.0), (24.1, 41.2)])
            ),
            BoardMember(
                id: "RUN42X_emma", displayName: "Emma", vo2Max: nil, weeklyKilometers: 18.6,
                lastUpdated: .now,
                statsHistory: history([(8.0, nil), (10.5, nil), (12.8, nil), (14.2, nil), (16.5, nil), (18.6, nil)])
            ),
        ]

        cloudKit.members = members
        cloudKit.currentBoardCode = "RUN42X"
        cloudKit.myRecordName = "RUN42X_paul"
        cloudKit.myDisplayName = "Paul"
        cloudKit.boardCreatorName = "Paul"
        cloudKit.boardCreatorRecordName = "RUN42X_paul"
        cloudKit.boardCreatedDate = Calendar.current.date(byAdding: .month, value: -2, to: .now)
        cloudKit.hasFetched = true
    }
}
