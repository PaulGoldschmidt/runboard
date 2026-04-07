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
