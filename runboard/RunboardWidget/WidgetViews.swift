//
//  WidgetViews.swift
//  RunboardWidget
//
//  Created by Paul Goldschmidt on 06.04.26.
//

import SwiftUI
import WidgetKit

// MARK: - Entry View Router

struct RunboardWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: RunboardEntry

    var body: some View {
        if entry.boardCode == nil && !entry.isPlaceholder {
            noBoardView
        } else {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
    }

    private var noBoardView: some View {
        VStack(spacing: 8) {
            Text("RUNBOARD")
                .font(Theme.font(16))
                .foregroundStyle(Theme.accent)
                .tracking(2)
            Text("OPEN APP\nTO GET STARTED")
                .font(Theme.font(11))
                .foregroundStyle(Theme.dimText)
                .tracking(1)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: RunboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("RUNBOARD")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.accent)
                    .tracking(2)
                Spacer()
                Text(entry.statType.shortLabel)
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.dimText)
                    .tracking(1)
            }
            .padding(.bottom, 8)

            let members = Array(entry.members.prefix(5))
            VStack(spacing: 6) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    smallMemberRow(rank: index + 1, member: member)
                }
            }

            Spacer(minLength: 0)
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }

    private func smallMemberRow(rank: Int, member: BoardMember) -> some View {
        HStack(spacing: 6) {
            Text("\(rank)")
                .font(Theme.font(14))
                .foregroundStyle(Theme.chartColor(forRank: rank))
                .frame(width: 16, alignment: .leading)

            Text(member.displayName.uppercased())
                .font(Theme.font(11))
                .foregroundStyle(member.isCurrentUser ? Theme.accent : .white)
                .tracking(0.5)
                .lineLimit(1)

            if rank == 1 {
                Image("Trophy")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 12)
            }

            Spacer(minLength: 0)

            Text(entry.statType.formattedValue(for: member, compact: true))
                .font(Theme.font(12))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: RunboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("RUNBOARD")
                    .font(Theme.font(16))
                    .foregroundStyle(Theme.accent)
                    .tracking(2)
                if let code = entry.boardCode {
                    Text(code)
                        .font(Theme.font(10))
                        .foregroundStyle(Theme.dimText)
                        .tracking(1)
                }
                Spacer()
                Text(entry.statType.fullLabel)
                    .font(Theme.font(9))
                    .foregroundStyle(Theme.dimText)
                    .tracking(1)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)

            let members = Array(entry.members.prefix(5))
            VStack(spacing: 5) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    mediumMemberRow(rank: index + 1, member: member)
                }
            }

            Spacer(minLength: 0)
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }

    private func mediumMemberRow(rank: Int, member: BoardMember) -> some View {
        HStack(spacing: 8) {
            Text("\(rank)")
                .font(Theme.font(13))
                .foregroundStyle(Theme.chartColor(forRank: rank))
                .frame(width: 18, alignment: .leading)

            Text(member.displayName.uppercased())
                .font(Theme.font(12))
                .foregroundStyle(member.isCurrentUser ? Theme.accent : .white)
                .tracking(0.5)
                .lineLimit(1)

            if rank == 1 {
                Image("Trophy")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)
            }

            if member.isCurrentUser {
                Text("YOU")
                    .font(Theme.font(8))
                    .foregroundStyle(Theme.accent)
                    .tracking(1)
            }

            Spacer(minLength: 0)

            Text(entry.statType.formattedValue(for: member))
                .font(Theme.font(13))
                .foregroundStyle(.white)

            Text(entry.statType.unitLabel)
                .font(Theme.font(8))
                .foregroundStyle(Theme.dimText)
                .tracking(0.5)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            member.isCurrentUser
                ? RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.08))
                : nil
        )
        .overlay(
            member.isCurrentUser
                ? RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.3), lineWidth: 0.5)
                : nil
        )
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: RunboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RUNBOARD")
                        .font(Theme.font(20))
                        .foregroundStyle(Theme.accent)
                        .tracking(3)
                    if let code = entry.boardCode {
                        Text(code)
                            .font(Theme.font(10))
                            .foregroundStyle(Theme.dimText)
                            .tracking(2)
                    }
                }
                Spacer()
                Text(entry.statType.fullLabel)
                    .font(Theme.font(10))
                    .foregroundStyle(Theme.secondaryAccent)
                    .tracking(1)
            }
            .padding(.bottom, 12)

            let members = Array(entry.members.prefix(8))
            VStack(spacing: 6) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    largeMemberCard(rank: index + 1, member: member)
                }
            }

            Spacer(minLength: 0)
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }

    private func largeMemberCard(rank: Int, member: BoardMember) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(Theme.font(16))
                .foregroundStyle(Theme.chartColor(forRank: rank))
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(member.displayName.uppercased())
                        .font(Theme.font(13))
                        .foregroundStyle(.white)
                        .tracking(0.5)
                        .lineLimit(1)

                    if rank == 1 {
                        Image("Trophy")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 14)
                    }
                }

                if member.isCurrentUser {
                    Text("YOU")
                        .font(Theme.font(8))
                        .foregroundStyle(Theme.accent)
                        .tracking(2)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text(entry.statType.formattedValue(for: member))
                    .font(Theme.font(15))
                    .foregroundStyle(.white)
                Text(entry.statType.unitLabel)
                    .font(Theme.font(8))
                    .foregroundStyle(Theme.dimText)
                    .tracking(1)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    member.isCurrentUser ? Theme.accent.opacity(0.4) : Theme.cardBorder,
                    lineWidth: member.isCurrentUser ? 1 : 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    RunboardWidget()
} timeline: {
    RunboardEntry(
        date: .now,
        members: RunboardTimelineProvider.placeholderMembers,
        boardCode: "ABC123",
        myRecordName: "1",
        statType: .weeklyKm,
        isPlaceholder: false
    )
}

#Preview("Medium", as: .systemMedium) {
    RunboardWidget()
} timeline: {
    RunboardEntry(
        date: .now,
        members: RunboardTimelineProvider.placeholderMembers,
        boardCode: "ABC123",
        myRecordName: "1",
        statType: .weeklyKm,
        isPlaceholder: false
    )
}

#Preview("Large", as: .systemLarge) {
    RunboardWidget()
} timeline: {
    RunboardEntry(
        date: .now,
        members: RunboardTimelineProvider.placeholderMembers,
        boardCode: "ABC123",
        myRecordName: "1",
        statType: .weeklyKm,
        isPlaceholder: false
    )
}
