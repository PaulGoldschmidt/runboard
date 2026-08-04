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
        #expect(Theme.chartColors.count == 12)
    }

    @Test func chartColorForRankOne() {
        #expect(Theme.chartColor(forRank: 1) == Theme.accent)
    }

    @Test func chartColorForRankTwo() {
        #expect(Theme.chartColor(forRank: 2) == Theme.secondaryAccent)
    }

    @Test func chartColorWrapsAround() {
        #expect(Theme.chartColor(forRank: 13) == Theme.chartColor(forRank: 1))
        #expect(Theme.chartColor(forRank: 14) == Theme.chartColor(forRank: 2))
    }

    @Test func chartColorLargeRank() {
        #expect(Theme.chartColor(forRank: 25) == Theme.chartColor(forRank: 1))
    }

    @Test func chartColorForIndexMatchesRank() {
        #expect(Theme.chartColor(forIndex: 0) == Theme.chartColor(forRank: 1))
        #expect(Theme.chartColor(forIndex: 11) == Theme.chartColor(forRank: 12))
        #expect(Theme.chartColor(forIndex: 12) == Theme.chartColor(forIndex: 0))
    }
}
