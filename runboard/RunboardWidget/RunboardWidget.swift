//
//  RunboardWidget.swift
//  RunboardWidget
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import WidgetKit
import SwiftUI

struct RunboardWidget: Widget {
    let kind: String = "RunboardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: RunboardWidgetIntent.self,
            provider: RunboardTimelineProvider()
        ) { entry in
            RunboardWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("RUNBOARD")
        .description("Your running leaderboard at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
        ])
    }
}
