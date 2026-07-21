//
//  DailyGermanGameView.swift
//  sweezy
//
//  Wordly-inspired daily German micro-game.
//

import SwiftUI

struct DailyGermanGameView: View {
    @ObservedObject var service: DailyGermanGameService
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var now = Date()
    @State private var didEmitReward = false

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Spacing.xl) {
                hero
                board
                clueCard
                keyboard
                resultCard
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .background(Color.clear)
        .navigationTitle("daily_german.nav_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("common.done".localized) { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .onAppear {
            service.refreshIfNeeded()
            maybeAwardXP()
        }
        .onReceive(timer) { date in
            now = date
            service.refreshIfNeeded()
        }
        .onChange(of: service.isSolved) { _, _ in
            maybeAwardXP()
        }
        .journeyScreen(.alpine, darkness: 0.68)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Theme.Colors.primaryDark,
                    Theme.Colors.primary,
                    Theme.Colors.accent.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "textformat.abc")
                .font(.system(size: 160, weight: .bold))
                .foregroundColor(.white.opacity(0.07))
                .offset(x: 120, y: 20)
                .rotationEffect(.degrees(-10))

            RadialGradient(
                colors: [Theme.Colors.accentYellowSoft.opacity(0.45), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 220
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Label("daily_german.hero.badge".localized, systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.86))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                    Spacer()
                    Text(countdownText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("daily_german.hero.title".localized)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("daily_german.hero.subtitle".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    StatCapsule(icon: "square.grid.3x3.fill", value: "\(service.wordLength)", label: "daily_german.stat.letters".localized, color: Theme.Colors.accentYellowSoft)
                    StatCapsule(icon: "target", value: "\(service.attemptsLeft)", label: "daily_german.stat.tries".localized, color: .white)
                    StatCapsule(icon: "bolt.fill", value: "+20", label: "XP", color: Theme.Colors.accentYellowSoft)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Theme.Colors.primary.opacity(0.25), radius: 24, y: 14)
    }

    private var board: some View {
        VStack(spacing: 8) {
            ForEach(service.rows) { row in
                HStack(spacing: 8) {
                    ForEach(row.letters) { tile in
                        DailyGermanTileView(tile: tile)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.adaptiveCard)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var clueCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("daily_german.clue.title".localized, systemImage: "lightbulb.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.accent)
                Spacer()
                Text("daily_german.clue.context".localized)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.Colors.primary.opacity(0.12)))
            }

            Text(service.puzzle.clueKey.localized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let message = service.validationMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.accentCoral)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.adaptiveCard)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var keyboard: some View {
        VStack(spacing: 8) {
            ForEach(DailyGermanGameService.keyboardRows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { letter in
                        DailyGermanKeyButton(
                            title: letter,
                            state: service.keyState(for: letter),
                            isWide: false
                        ) {
                            service.type(letter)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                DailyGermanKeyButton(title: "daily_german.key.enter".localized, state: .empty, isWide: true) {
                    service.submitGuess()
                }
                DailyGermanKeyButton(title: "⌫", state: .empty, isWide: true) {
                    service.deleteLetter()
                }
            }
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        if service.isFinished {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(resultColor.opacity(0.16))
                            .frame(width: 52, height: 52)
                        Image(systemName: service.isSolved ? "checkmark.seal.fill" : "book.closed.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(resultColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.isSolved ? "daily_german.result.win_title".localized : "daily_german.result.lose_title".localized)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(service.isSolved ? "daily_german.result.win_subtitle".localized : "daily_german.result.lose_subtitle".localized)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(service.puzzle.word)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundColor(resultColor)
                    Text(service.puzzle.meaningKey.localized)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(service.puzzle.exampleKey.localized)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(service.puzzle.contextKey.localized, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                }
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.adaptiveSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("daily_german.result.next_format".localized(with: countdownText))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.adaptiveCard)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(resultColor.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var resultColor: Color {
        service.isSolved ? Theme.Colors.success : Theme.Colors.accentCoral
    }

    private var countdownText: String {
        let remaining = max(0, service.nextRefreshDate.timeIntervalSince(now))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private func maybeAwardXP() {
        guard service.isSolved, !service.hasAwardedXP, !didEmitReward else { return }
        didEmitReward = true
        EventBus.shared.emit(
            GamEvent(
                type: .dailyGermanCompleted,
                idempotencyKey: "daily-german:\(service.dayKey)",
                metadata: ["entityId": service.dayKey]
            )
        )
        service.markAwardedXP()
    }
}

private struct DailyGermanTileView: View {
    let tile: DailyGermanTile

    var body: some View {
        Text(tile.letter)
            .font(.system(size: 25, weight: .black, design: .rounded))
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(border, lineWidth: tile.letter.isEmpty ? 1 : 1.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var foreground: Color {
        switch tile.state {
        case .correct, .present, .absent:
            return .white
        case .empty:
            return Theme.Colors.textPrimary
        }
    }

    private var background: Color {
        switch tile.state {
        case .correct: return Theme.Colors.success
        case .present: return Theme.Colors.accent
        case .absent: return Theme.Colors.textTertiary.opacity(0.55)
        case .empty: return Theme.Colors.adaptiveSurface
        }
    }

    private var border: Color {
        tile.letter.isEmpty ? Theme.Colors.adaptiveBorder : Theme.Colors.primary.opacity(0.28)
    }
}

private struct DailyGermanKeyButton: View {
    let title: String
    let state: DailyGermanTileState
    let isWide: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: isWide ? 13 : 15, weight: .bold, design: .rounded))
                .foregroundColor(foreground)
                .frame(maxWidth: isWide ? 120 : .infinity)
                .frame(height: 46)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.8), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch state {
        case .correct, .present, .absent:
            return .white
        case .empty:
            return Theme.Colors.textPrimary
        }
    }

    private var background: Color {
        switch state {
        case .correct: return Theme.Colors.success
        case .present: return Theme.Colors.accent
        case .absent: return Theme.Colors.textTertiary.opacity(0.55)
        case .empty: return Theme.Colors.adaptiveCard
        }
    }
}

private struct StatCapsule: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .opacity(0.72)
            }
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
        )
    }
}
