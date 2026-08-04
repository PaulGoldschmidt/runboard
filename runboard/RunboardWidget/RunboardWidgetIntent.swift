//
//  RunboardWidgetIntent.swift
//  RunboardWidget
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import AppIntents
import WidgetKit

enum WidgetStatType: String, AppEnum {
    case weeklyKm = "weeklyKm"
    case vo2Max = "vo2Max"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Stat Type"
    }

    static var caseDisplayRepresentations: [WidgetStatType: DisplayRepresentation] {
        [
            .weeklyKm: "Weekly KM",
            .vo2Max: "VO2 Max"
        ]
    }

    var fullLabel: String {
        switch self {
        case .weeklyKm: return "WEEKLY KM"
        case .vo2Max: return "VO2 MAX"
        }
    }

    var shortLabel: String {
        switch self {
        case .weeklyKm: return "KM"
        case .vo2Max: return "VO2"
        }
    }

    var unitLabel: String {
        switch self {
        case .weeklyKm: return "KM"
        case .vo2Max: return "ML/KG/MIN"
        }
    }

    func formattedValue(for member: BoardMember, compact: Bool = false) -> String {
        switch self {
        case .weeklyKm:
            return String(format: "%.1f", member.currentWeekKilometers())
        case .vo2Max:
            if let vo2 = member.vo2Max {
                return String(format: compact ? "%.0f" : "%.1f", vo2)
            }
            return "---"
        }
    }
}

struct RunboardWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Runboard Leaderboard"
    static var description: IntentDescription = "Shows your running leaderboard."

    @Parameter(title: "Stat", default: .weeklyKm)
    var statType: WidgetStatType
}
