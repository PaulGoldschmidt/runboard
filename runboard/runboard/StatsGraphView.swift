//
//  StatsGraphView.swift
//  runboard
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import SwiftUI
import Charts

struct StatsGraphView: View {
    let members: [BoardMember]
    let statType: StatType

    private var yLabel: String {
        statType == .weeklyKm ? "KM" : "VO2"
    }

    var body: some View {
        VStack(spacing: 8) {
            chart
            legend
        }
        .padding(16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                let color = Theme.chartColor(forRank: index + 1)
                ForEach(dataPoints(for: member)) { point in
                    LineMark(
                        x: .value("Week", point.weekStart),
                        y: .value(yLabel, point.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Week", point.weekStart),
                        y: .value(yLabel, point.value)
                    )
                    .foregroundStyle(color)
                    .symbolSize(30)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.cardBorder)
                AxisValueLabel()
                    .font(Theme.font(10))
                    .foregroundStyle(Theme.dimText)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Theme.cardBorder)
                AxisValueLabel()
                    .font(Theme.font(10))
                    .foregroundStyle(Theme.dimText)
            }
        }
        .chartLegend(.hidden)
        .frame(height: 200)
    }

    // MARK: - Legend

    private var legend: some View {
        FlowLayout(spacing: 12) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.chartColor(forRank: index + 1))
                        .frame(width: 8, height: 8)
                    Text(member.displayName.uppercased())
                        .font(Theme.font(10))
                        .foregroundStyle(Theme.dimText)
                        .tracking(1)
                }
            }
        }
    }

    // MARK: - Data

    private struct DataPoint: Identifiable {
        let weekStart: Date
        let value: Double
        var id: Date { weekStart }
    }

    private func dataPoints(for member: BoardMember) -> [DataPoint] {
        member.statsHistory.compactMap { snapshot in
            switch statType {
            case .weeklyKm:
                return DataPoint(weekStart: snapshot.weekStart, value: snapshot.weeklyKilometers)
            case .vo2Max:
                guard let vo2 = snapshot.vo2Max else { return nil }
                return DataPoint(weekStart: snapshot.weekStart, value: vo2)
            }
        }
    }
}

// MARK: - Flow Layout

fileprivate struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    struct CacheData {
        let rows: [[Int]]
        let sizes: [CGSize]
    }

    func makeCache(subviews: Subviews) -> CacheData {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return CacheData(rows: [], sizes: sizes)
    }

    func updateCache(_ cache: inout CacheData, subviews: Subviews) {
        cache = CacheData(rows: cache.rows, sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let rows = computeRows(maxWidth: proposal.width ?? .infinity, sizes: cache.sizes)
        var height: CGFloat = 0
        for (index, row) in rows.enumerated() {
            let rowHeight = row.map { cache.sizes[$0].height }.max() ?? 0
            height += rowHeight
            if index < rows.count - 1 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        let rows = computeRows(maxWidth: bounds.width, sizes: cache.sizes)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { cache.sizes[$0].height }.max() ?? 0
            var x = bounds.minX
            for idx in row {
                let size = cache.sizes[idx]
                subviews[idx].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(maxWidth: CGFloat, sizes: [CGSize]) -> [[Int]] {
        var rows: [[Int]] = [[]]
        var currentWidth: CGFloat = 0

        for (index, size) in sizes.enumerated() {
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(index)
            currentWidth += size.width + spacing
        }
        return rows
    }
}
