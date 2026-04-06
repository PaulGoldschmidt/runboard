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

    static let chartColors: [Color] = [
        accent,
        secondaryAccent,
        .orange,
        Color(red: 1.0, green: 0.4, blue: 0.7),     // pink
        Color(red: 0.8, green: 0.6, blue: 1.0),     // lavender
        Color(red: 1.0, green: 0.85, blue: 0.3),    // yellow
    ]

    static func chartColor(forRank rank: Int) -> Color {
        chartColors[(rank - 1) % chartColors.count]
    }
}
