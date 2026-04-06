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
}

struct RunboardWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Runboard Leaderboard"
    static var description: IntentDescription = "Shows your running leaderboard."

    @Parameter(title: "Stat", default: .weeklyKm)
    var statType: WidgetStatType
}
