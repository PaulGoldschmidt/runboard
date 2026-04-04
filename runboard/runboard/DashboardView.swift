//
//  DashboardView.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedStat: StatType = .weeklyKm
    @State private var showBoardSettings = false

    enum StatType: String, CaseIterable {
        case weeklyKm = "WEEKLY KM"
        case vo2Max = "VO2 MAX"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                statToggle
                leaderboardList
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await appState.refreshAndSync()
        }
        .refreshable {
            await appState.refreshAndSync()
        }
        .sheet(isPresented: $showBoardSettings) {
            boardSettingsSheet
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("RUNBOARD")
                    .font(Theme.title)
                    .foregroundStyle(Theme.accent)
                    .tracking(4)

                if let code = appState.cloudKit.currentBoardCode {
                    Text(code)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.dimText)
                        .tracking(2)
                }
            }

            Spacer()

            Button {
                showBoardSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.dimText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Stat Toggle

    private var statToggle: some View {
        HStack(spacing: 2) {
            ForEach(StatType.allCases, id: \.self) { stat in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStat = stat
                    }
                } label: {
                    Text(stat.rawValue)
                        .font(Theme.caption)
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedStat == stat ? Theme.accent.opacity(0.15) : .clear)
                        .foregroundStyle(selectedStat == stat ? Theme.accent : Theme.dimText)
                }
            }
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Leaderboard

    private var sortedMembers: [BoardMember] {
        let members = appState.cloudKit.members
        switch selectedStat {
        case .weeklyKm:
            return members.sorted { $0.weeklyKilometers > $1.weeklyKilometers }
        case .vo2Max:
            return members.sorted { ($0.vo2Max ?? -1) > ($1.vo2Max ?? -1) }
        }
    }

    private var leaderboardList: some View {
        ScrollView {
            if appState.cloudKit.isLoading && appState.cloudKit.members.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Theme.accent)
                    Text("LOADING...")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.dimText)
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if sortedMembers.isEmpty {
                VStack(spacing: 12) {
                    Text("NO MEMBERS YET")
                        .font(Theme.body)
                        .foregroundStyle(Theme.dimText)
                        .tracking(2)
                    Text("Share your board code\nto invite friends")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.dimText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(sortedMembers.enumerated()), id: \.element.id) { index, member in
                        memberCard(rank: index + 1, member: member)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Member Card

    private func memberCard(rank: Int, member: BoardMember) -> some View {
        HStack(spacing: 14) {
            // Rank
            Text("\(rank)")
                .font(Theme.headline)
                .foregroundStyle(rankColor(rank))
                .frame(width: 32)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName.uppercased())
                    .font(Theme.body)
                    .foregroundStyle(.white)
                    .tracking(1)

                if member.isCurrentUser {
                    Text("YOU")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.accent)
                        .tracking(2)
                }
            }

            Spacer()

            // Stat value
            VStack(alignment: .trailing, spacing: 2) {
                switch selectedStat {
                case .weeklyKm:
                    Text(String(format: "%.1f", member.weeklyKilometers))
                        .font(Theme.headline)
                        .foregroundStyle(.white)
                    Text("KM")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.dimText)
                        .tracking(2)
                case .vo2Max:
                    if let vo2 = member.vo2Max {
                        Text(String(format: "%.1f", vo2))
                            .font(Theme.headline)
                            .foregroundStyle(.white)
                        Text("ML/KG/MIN")
                            .font(Theme.font(12))
                            .foregroundStyle(Theme.dimText)
                            .tracking(1)
                    } else {
                        Text("---")
                            .font(Theme.headline)
                            .foregroundStyle(Theme.dimText)
                        Text("NO DATA")
                            .font(Theme.font(12))
                            .foregroundStyle(Theme.dimText)
                            .tracking(1)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(member.isCurrentUser ? Theme.accent.opacity(0.4) : Theme.cardBorder, lineWidth: member.isCurrentUser ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Theme.accent
        case 2: return Theme.secondaryAccent
        case 3: return Color.orange
        default: return Theme.dimText
        }
    }

    // MARK: - Board Settings Sheet

    private var boardSettingsSheet: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("BOARD SETTINGS")
                        .font(Theme.headline)
                        .foregroundStyle(.white)
                        .tracking(2)
                    Spacer()
                    Button {
                        showBoardSettings = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Theme.dimText)
                    }
                }

                if let code = appState.cloudKit.currentBoardCode {
                    VStack(spacing: 8) {
                        Text("BOARD CODE")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.dimText)
                            .tracking(2)

                        Text(code)
                            .font(Theme.font(40))
                            .foregroundStyle(Theme.accent)
                            .tracking(6)

                        ShareLink(item: "Join my Runboard! Code: \(code)") {
                            Text("SHARE CODE")
                                .font(Theme.caption)
                                .tracking(2)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Theme.cardBackground)
                                .foregroundStyle(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.cardBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 20)
                }

                if appState.cloudKit.boardCreatorName != nil || appState.cloudKit.boardCreatedDate != nil {
                    VStack(spacing: 6) {
                        if let creator = appState.cloudKit.boardCreatorName {
                            HStack(spacing: 6) {
                                Text("CREATED BY")
                                    .font(Theme.caption)
                                    .foregroundStyle(Theme.dimText)
                                    .tracking(1)
                                Text(creator.uppercased())
                                    .font(Theme.caption)
                                    .foregroundStyle(.white)
                                    .tracking(1)
                            }
                        }
                        if let date = appState.cloudKit.boardCreatedDate {
                            HStack(spacing: 6) {
                                Text("ON")
                                    .font(Theme.caption)
                                    .foregroundStyle(Theme.dimText)
                                    .tracking(1)
                                Text(date.formatted(date: .abbreviated, time: .omitted).uppercased())
                                    .font(Theme.caption)
                                    .foregroundStyle(.white)
                                    .tracking(1)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(spacing: 8) {
                    Text("MEMBERS")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.dimText)
                        .tracking(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(appState.cloudKit.members) { member in
                        HStack {
                            Text(member.displayName.uppercased())
                                .font(Theme.body)
                                .foregroundStyle(.white)
                                .tracking(1)
                            Spacer()
                            if member.isCurrentUser {
                                Text("YOU")
                                    .font(Theme.font(12))
                                    .foregroundStyle(Theme.accent)
                                    .tracking(2)
                            }
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Spacer()

                if let healthStatus = healthStatusText {
                    Text(healthStatus)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.dimText)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await appState.cloudKit.leaveBoard()
                        showBoardSettings = false
                    }
                } label: {
                    Text("LEAVE BOARD")
                        .font(Theme.body)
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(24)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private var healthStatusText: String? {
        switch appState.healthKit.status {
        case .unavailable:
            return "HealthKit is not available on this device."
        case .denied:
            return "HealthKit access denied. Enable in Settings > Privacy > Health."
        case .notDetermined:
            return "HealthKit access not yet requested."
        case .authorized:
            return nil
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
}
