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
    let memberColors: [String: Color]

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
        Chart(chartData, id: \.id) { point in
            LineMark(
                x: .value("Week", point.weekStart),
                y: .value(yLabel, point.value),
                series: .value("Member", point.memberName)
            )
            .foregroundStyle(point.color)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
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
        // New identity per stat type: crossfade between the two datasets
        // instead of morphing one into the other.
        .id(statType)
        .transition(.opacity)
    }

    // MARK: - Legend

    private var legend: some View {
        FlowLayout(spacing: 12) {
            ForEach(members) { member in
                HStack(spacing: 6) {
                    Circle()
                        .fill(color(for: member))
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

    private struct ChartPoint: Identifiable {
        let id: String
        let weekStart: Date
        let value: Double
        let memberName: String
        let color: Color
    }

    private func color(for member: BoardMember) -> Color {
        memberColors[member.id] ?? Theme.dimText
    }

    private var chartData: [ChartPoint] {
        members.flatMap { member in
            let color = color(for: member)
            return member.statsHistory.compactMap { snapshot -> ChartPoint? in
                let value: Double?
                switch statType {
                case .weeklyKm: value = snapshot.weeklyKilometers
                case .vo2Max: value = snapshot.vo2Max
                }
                guard let v = value else { return nil }
                return ChartPoint(
                    id: "\(member.id)_\(snapshot.weekStart.timeIntervalSince1970)",
                    weekStart: snapshot.weekStart,
                    value: v,
                    memberName: member.displayName,
                    color: color
                )
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
