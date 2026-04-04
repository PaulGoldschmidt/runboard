//
//  BoardSetupView.swift
//  runboard
//
//  Created by Paul Goldschmidt on 03.04.26.
//

import SwiftUI

struct BoardSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var displayName = ""
    @State private var joinCode = ""
    @State private var mode: Mode = .none
    @State private var createdCode: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode {
        case none, create, join
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo area
                VStack(spacing: 8) {
                    Text("RUNBOARD")
                        .font(Theme.title)
                        .foregroundStyle(Theme.accent)
                        .tracking(4)

                    Text("COMPETE WITH FRIENDS")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.dimText)
                        .tracking(2)
                }

                Spacer()

                if let createdCode {
                    boardCreatedView(code: createdCode)
                } else {
                    switch mode {
                    case .none:
                        modeSelectionView
                    case .create:
                        createBoardView
                    case .join:
                        joinBoardView
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Mode Selection

    private var modeSelectionView: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation { mode = .create }
            } label: {
                Text("CREATE BOARD")
                    .font(Theme.headline)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                withAnimation { mode = .join }
            } label: {
                Text("JOIN BOARD")
                    .font(Theme.headline)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.cardBackground)
                    .foregroundStyle(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Create Board

    private var createBoardView: some View {
        VStack(spacing: 20) {
            Text("YOUR NAME")
                .font(Theme.caption)
                .foregroundStyle(Theme.dimText)
                .tracking(2)

            TextField("", text: $displayName, prompt: Text("Enter name").foregroundStyle(Theme.dimText))
                .font(Theme.body)
                .foregroundStyle(.white)
                .padding(14)
                .background(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await createBoard() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("CREATE")
                            .font(Theme.headline)
                            .tracking(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(displayName.isEmpty ? Theme.dimText : Theme.accent)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(displayName.isEmpty || isLoading)

            backButton
        }
    }

    // MARK: - Join Board

    private var joinBoardView: some View {
        VStack(spacing: 20) {
            Text("BOARD CODE")
                .font(Theme.caption)
                .foregroundStyle(Theme.dimText)
                .tracking(2)

            TextField("", text: $joinCode, prompt: Text("XXXXXX").foregroundStyle(Theme.dimText))
                .font(Theme.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(14)
                .background(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .onChange(of: joinCode) { _, newValue in
                    joinCode = String(newValue.prefix(6)).uppercased()
                }

            Text("YOUR NAME")
                .font(Theme.caption)
                .foregroundStyle(Theme.dimText)
                .tracking(2)

            TextField("", text: $displayName, prompt: Text("Enter name").foregroundStyle(Theme.dimText))
                .font(Theme.body)
                .foregroundStyle(.white)
                .padding(14)
                .background(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await joinBoard() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("JOIN")
                            .font(Theme.headline)
                            .tracking(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canJoin ? Theme.accent : Theme.dimText)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canJoin || isLoading)

            backButton
        }
    }

    // MARK: - Board Created

    private func boardCreatedView(code: String) -> some View {
        VStack(spacing: 20) {
            Text("YOUR BOARD CODE")
                .font(Theme.caption)
                .foregroundStyle(Theme.dimText)
                .tracking(2)

            Text(code)
                .font(Theme.font(40))
                .foregroundStyle(Theme.accent)
                .tracking(8)

            Text("Share this code with your friends so they can join your board.")
                .font(Theme.caption)
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)

            ShareLink(item: "Join my Runboard! Code: \(code)") {
                Text("SHARE CODE")
                    .font(Theme.body)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.cardBackground)
                    .foregroundStyle(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                // Transition to dashboard
                createdCode = nil
            } label: {
                Text("CONTINUE")
                    .font(Theme.headline)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

    private var backButton: some View {
        Button {
            withAnimation {
                mode = .none
                errorMessage = nil
            }
        } label: {
            Text("BACK")
                .font(Theme.caption)
                .foregroundStyle(Theme.dimText)
                .tracking(2)
        }
    }

    private var canJoin: Bool {
        joinCode.count == 6 && !displayName.isEmpty
    }

    private func createBoard() async {
        isLoading = true
        errorMessage = nil
        do {
            try await appState.cloudKit.createBoard(displayName: displayName)
            createdCode = appState.cloudKit.currentBoardCode
        } catch {
            errorMessage = "Failed to create board. Check your connection."
        }
        isLoading = false
    }

    private func joinBoard() async {
        isLoading = true
        errorMessage = nil
        do {
            try await appState.cloudKit.joinBoard(code: joinCode, displayName: displayName)
        } catch is BoardError {
            errorMessage = "No board found with that code."
        } catch {
            errorMessage = "Failed to join board. Check your connection."
        }
        isLoading = false
    }
}

#Preview {
    BoardSetupView()
        .environment(AppState())
}
