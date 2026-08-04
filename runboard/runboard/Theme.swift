//
//  Theme.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import SwiftUI

enum Theme {
    static let fontName = "GeistPixel-Circle"

    static func font(_ size: CGFloat) -> Font {
        .custom(fontName, size: size)
    }

    static let title = font(36)
    static let headline = font(26)
    static let body = font(18)
    static let caption = font(14)

    static let accent = Color(red: 0.2, green: 1.0, blue: 0.4)
    static let secondaryAccent = Color(red: 0.3, green: 0.8, blue: 1.0)
    static let cardBackground = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.1)
    static let dimText = Color.white.opacity(0.5)

    // Fixed order: adjacent pairs are validated for color-vision-deficiency
    // separation on the dark card surface. Append new colors, don't reorder.
    static let chartColors: [Color] = [
        accent,                                      // #33FF66
        secondaryAccent,                             // #4DCCFF
        Color(red: 1.0, green: 0.62, blue: 0.04),    // orange     #FF9F0A
        Color(red: 1.0, green: 0.4, blue: 0.66),     // pink       #FF66A8
        Color(red: 0.8, green: 0.6, blue: 1.0),      // lavender   #CC99FF
        Color(red: 1.0, green: 0.85, blue: 0.3),     // yellow     #FFD94D
        Color(red: 0.57, green: 0.64, blue: 1.0),    // periwinkle #91A3FF
        Color(red: 1.0, green: 0.51, blue: 0.4),     // coral      #FF8266
        Color(red: 0.2, green: 0.9, blue: 0.72),     // mint       #33E6B8
        Color(red: 0.93, green: 0.44, blue: 1.0),    // magenta    #ED70FF
        Color(red: 0.72, green: 0.9, blue: 0.21),    // lime       #B8E635
        Color(red: 0.86, green: 0.61, blue: 0.29),   // gold       #DB9C4A
    ]

    static func chartColor(forIndex index: Int) -> Color {
        chartColors[index % chartColors.count]
    }

    static func chartColor(forRank rank: Int) -> Color {
        chartColor(forIndex: rank - 1)
    }
}
