//
//  ThemeTests.swift
//  runboardTests
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import Testing
import SwiftUI
@testable import runboard

struct ThemeTests {

    @Test func chartColorsCount() {
        #expect(Theme.chartColors.count == 6)
    }

    @Test func chartColorForRankOne() {
        #expect(Theme.chartColor(forRank: 1) == Theme.accent)
    }

    @Test func chartColorForRankTwo() {
        #expect(Theme.chartColor(forRank: 2) == Theme.secondaryAccent)
    }

    @Test func chartColorWrapsAround() {
        #expect(Theme.chartColor(forRank: 7) == Theme.chartColor(forRank: 1))
        #expect(Theme.chartColor(forRank: 8) == Theme.chartColor(forRank: 2))
    }

    @Test func chartColorLargeRank() {
        #expect(Theme.chartColor(forRank: 13) == Theme.chartColor(forRank: 1))
    }
}
