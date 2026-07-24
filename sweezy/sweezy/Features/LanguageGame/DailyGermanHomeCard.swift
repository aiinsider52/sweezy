//
//  DailyGermanHomeCard.swift
//  sweezy
//
//  Home entry point for the daily German word game.
//

import SwiftUI

struct DailyGermanHomeCard: View {
    @ObservedObject var service: DailyGermanGameService
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        Theme.Colors.primaryDark,
                        Theme.Colors.primary,
                        Theme.Colors.accent.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundColor(.white.opacity(0.07))
                    .offset(x: 130, y: 22)
                    .rotationEffect(.degrees(-8))

                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 8) {
                            Label("daily_german.home.badge".localized, systemImage: "flame.fill")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .tracking(1.1)
                                .foregroundColor(Theme.Colors.accentYellowSoft)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.white.opacity(0.14)))

                            if service.isFinished {
                                Text(service.isSolved ? "daily_german.home.done".localized : "daily_german.home.try_tomorrow".localized)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.82))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.white.opacity(0.12)))
                            }
                        }

                        Text("daily_german.home.title".localized)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text("daily_german.home.subtitle".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.82))
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            MiniMetric(icon: "square.grid.3x3.fill", text: "daily_german.home.letters_format".localized(with: service.wordLength))
                            MiniMetric(icon: "target", text: "daily_german.home.tries_format".localized(with: service.attemptsLeft))
                            MiniMetric(icon: "bolt.fill", text: "+20 XP")
                        }
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 54, height: 54)
                        Image(systemName: service.isSolved ? "checkmark.seal.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Theme.Colors.primary.opacity(0.22), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .onAppear {
            service.refreshIfNeeded()
        }
    }
}

private struct MiniMetric: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white.opacity(0.88))
    }
}
