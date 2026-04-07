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

        let cal = Calendar.current
        let boardCreated = cal.date(byAdding: .month, value: -2, to: .now)!

        let members: [BoardMember] = [
            BoardMember(
                id: "RUN42X_paul", displayName: "Paul", vo2Max: 52.1, weeklyKilometers: 47.2,
                lastUpdated: .now, isCurrentUser: true,
                statsHistory: history([(15.0, 47.0), (22.0, 48.5), (25.5, 49.2), (30.0, 50.5), (38.5, 51.8), (47.2, 52.1)]),
                joinedDate: boardCreated
            ),
            BoardMember(
                id: "RUN42X_max", displayName: "Max", vo2Max: 48.3, weeklyKilometers: 38.5,
                lastUpdated: .now,
                statsHistory: history([(28.0, 48.8), (32.0, 48.5), (35.5, 48.0), (36.0, 47.8), (37.2, 48.1), (38.5, 48.3)]),
                joinedDate: cal.date(byAdding: .day, value: -50, to: .now)
            ),
            BoardMember(
                id: "RUN42X_sophie", displayName: "Sophie", vo2Max: 45.7, weeklyKilometers: 31.8,
                lastUpdated: .now,
                statsHistory: history([(18.0, 42.0), (24.5, 43.5), (28.0, 44.8), (22.0, 43.5), (29.5, 45.0), (31.8, 45.7)]),
                joinedDate: cal.date(byAdding: .day, value: -35, to: .now)
            ),
            BoardMember(
                id: "RUN42X_lucas", displayName: "Lucas", vo2Max: 41.2, weeklyKilometers: 24.1,
                lastUpdated: .now,
                statsHistory: history([(12.0, 39.0), (14.5, 39.8), (17.0, 40.2), (19.5, 40.5), (21.8, 40.9), (24.1, 41.2)]),
                joinedDate: cal.date(byAdding: .day, value: -21, to: .now)
            ),
            BoardMember(
                id: "RUN42X_emma", displayName: "Emma", vo2Max: nil, weeklyKilometers: 18.6,
                lastUpdated: .now,
                statsHistory: history([(14.0, nil), (16.5, nil), (15.0, nil), (14.8, nil), (16.0, nil), (18.6, nil)]),
                joinedDate: cal.date(byAdding: .day, value: -7, to: .now)
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
