//
//  SweezyPassportView.swift
//  sweezy
//
//  Premium, brand-aligned passport view (Swiss Alpine Spring style).
//

import SwiftUI

// MARK: - Models

struct SweezyPassportLevel: Identifiable {
    let id: Int
    let titleKey: String
    let threshold: Int
    let nextThreshold: Int
    let unlockTitleKey: String
    let unlockDescriptionKey: String
    let icon: String
    let color: Color

    static let all: [SweezyPassportLevel] = [
        .init(id: 1, titleKey: "passport.level.1.title", threshold: 0, nextThreshold: 100, unlockTitleKey: "passport.level.1.unlock_title", unlockDescriptionKey: "passport.level.1.unlock_description", icon: "sparkles", color: Theme.Colors.accentTurquoise),
        .init(id: 2, titleKey: "passport.level.2.title", threshold: 100, nextThreshold: 300, unlockTitleKey: "passport.level.2.unlock_title", unlockDescriptionKey: "passport.level.2.unlock_description", icon: "bell.badge.fill", color: Theme.Colors.primary),
        .init(id: 3, titleKey: "passport.level.3.title", threshold: 300, nextThreshold: 600, unlockTitleKey: "passport.level.3.unlock_title", unlockDescriptionKey: "passport.level.3.unlock_description", icon: "person.text.rectangle.fill", color: Theme.Colors.accent),
        .init(id: 4, titleKey: "passport.level.4.title", threshold: 600, nextThreshold: 1000, unlockTitleKey: "passport.level.4.unlock_title", unlockDescriptionKey: "passport.level.4.unlock_description", icon: "bubble.left.and.bubble.right.fill", color: Theme.Colors.accentCoral),
        .init(id: 5, titleKey: "passport.level.5.title", threshold: 1000, nextThreshold: 1500, unlockTitleKey: "passport.level.5.unlock_title", unlockDescriptionKey: "passport.level.5.unlock_description", icon: "lightbulb.fill", color: Theme.Colors.info),
        .init(id: 6, titleKey: "passport.level.6.title", threshold: 1500, nextThreshold: 2200, unlockTitleKey: "passport.level.6.unlock_title", unlockDescriptionKey: "passport.level.6.unlock_description", icon: "person.2.badge.gearshape.fill", color: Theme.Colors.success),
        .init(id: 7, titleKey: "passport.level.7.title", threshold: 2200, nextThreshold: 3000, unlockTitleKey: "passport.level.7.unlock_title", unlockDescriptionKey: "passport.level.7.unlock_description", icon: "crown.fill", color: Theme.Colors.accent)
    ]

    static func current(for xp: Int) -> SweezyPassportLevel {
        all.last(where: { xp >= $0.threshold }) ?? all[0]
    }

    static func next(after level: SweezyPassportLevel) -> SweezyPassportLevel? {
        all.first(where: { $0.id == level.id + 1 })
    }
}

struct PassportAchievement: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    let progress: Double
}

struct PassportEarnAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let xp: Int
    let icon: String
    let color: Color
}

// MARK: - Main View

struct SweezyPassportView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.colorScheme) private var colorScheme

    private var gamification: GamificationService { appContainer.gamification }
    private var xp: Int { gamification.totalXP }
    private var level: SweezyPassportLevel { SweezyPassportLevel.current(for: xp) }
    private var nextLevel: SweezyPassportLevel? { SweezyPassportLevel.next(after: level) }
    private var nextThreshold: Int { nextLevel?.threshold ?? level.nextThreshold }
    private var progress: Double {
        let span = max(1, nextThreshold - level.threshold)
        return Double(max(0, xp - level.threshold)) / Double(span)
    }

    var body: some View {
        InkPageScaffold {
            passportHero
                .padding(.top, Theme.Spacing.xs)
        } content: {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    unlocksSection
                    achievementsSection
                    earnActionsSection
                    historySection

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .navigationTitle("passport.nav_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.ink, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: Hero (passport card)

    private var passportHero: some View {
        ZStack {
            // Base brand gradient
            LinearGradient(
                colors: [
                    Theme.Colors.primaryDark,
                    Theme.Colors.primary,
                    level.color.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Watermark glyph
            Image(systemName: level.icon)
                .font(.system(size: 220, weight: .bold))
                .foregroundColor(.white.opacity(0.06))
                .offset(x: 110, y: 60)
                .rotationEffect(.degrees(-12))
                .allowsHitTesting(false)

            // Soft top-right glow
            RadialGradient(
                colors: [Theme.Colors.accent.opacity(0.45), .clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 240
            )
            .allowsHitTesting(false)

            // Bottom shimmer
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Top row — meta + level chip
                HStack(alignment: .center) {
                    Text("passport.hero.tagline".localized)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.6)
                        .foregroundColor(.white.opacity(0.65))
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 10, weight: .bold))
                        Text("passport.hero.level_format".localized(with: level.id))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.6)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                }

                // Title row
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(level.titleKey.localized)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)

                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.Colors.accentYellowSoft)
                            Text("passport.hero.progress_format".localized(with: xp, nextThreshold))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                        }
                    }
                    Spacer(minLength: 8)

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            .frame(width: 60, height: 60)
                        Image(systemName: level.icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Theme.Colors.accentYellowSoft],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }

                // Progress bar with subtle markers
                progressBlock

                Divider()
                    .background(Color.white.opacity(0.18))

                // Footer row — like real passport bottom strip
                HStack(spacing: 12) {
                    HeroFooterCell(
                        title: "passport.hero.member_id".localized,
                        value: passportSerial
                    )
                    HeroFooterCell(
                        title: "passport.hero.status".localized,
                        value: level.titleKey.localized,
                        accent: Theme.Colors.accentYellowSoft
                    )
                    HeroFooterCell(
                        title: "passport.hero.xp_total".localized,
                        value: "\(xp) XP",
                        accent: .white
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Theme.Colors.primaryDark.opacity(0.45), radius: 22, x: 0, y: 14)
        .shadow(color: level.color.opacity(0.25), radius: 32, x: 0, y: 18)
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.accentYellowSoft,
                                    Theme.Colors.accent,
                                    Theme.Colors.accentCoral
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(min(max(progress, 0), 1))))
                        .shadow(color: Theme.Colors.accent.opacity(0.6), radius: 8, x: 0, y: 0)

                    // Markers
                    HStack(spacing: 0) {
                        ForEach(0..<5) { _ in
                            Spacer(minLength: 0)
                            Capsule()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 1, height: 6)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 10)

            HStack {
                if let next = nextLevel {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.Colors.accentYellowSoft)
                        Text("passport.hero.next_format".localized(with: next.titleKey.localized))
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.Colors.accentYellowSoft)
                        Text("passport.hero.max_status".localized)
                    }
                }
                Spacer()
                Text("passport.hero.left_format".localized(with: max(0, nextThreshold - xp)))
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
        }
    }

    private var passportSerial: String {
        let base = String(format: "%05d", max(1, xp + level.id * 137) % 99999)
        return "SW-\(base)"
    }

    // MARK: Sections

    private var unlocksSection: some View {
        section(title: "passport.section.unlocks".localized, icon: "lock.open.fill", iconColor: Theme.Colors.accent) {
            VStack(spacing: 0) {
                ForEach(Array(SweezyPassportLevel.all.enumerated()), id: \.element.id) { index, item in
                    PassportUnlockRow(
                        level: item,
                        isCurrent: item.id == level.id,
                        isUnlocked: xp >= item.threshold,
                        isLast: index == SweezyPassportLevel.all.count - 1,
                        currentXP: xp
                    )
                }
            }
        }
    }

    private var achievementsSection: some View {
        section(title: "passport.section.achievements".localized, icon: "rosette", iconColor: Theme.Colors.accentCoral) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(achievements) { achievement in
                    PassportAchievementCard(achievement: achievement)
                }
            }
        }
    }

    private var earnActionsSection: some View {
        section(title: "passport.section.earn".localized, icon: "bolt.fill", iconColor: Theme.Colors.accent) {
            VStack(spacing: 10) {
                ForEach(earnActions) { action in
                    PassportEarnActionRow(action: action)
                }
            }
        }
    }

    private var historySection: some View {
        section(title: "passport.section.history".localized, icon: "clock.arrow.circlepath", iconColor: Theme.Colors.info) {
            if gamification.xpHistory.isEmpty {
                emptyHistoryCard
            } else {
                VStack(spacing: 10) {
                    ForEach(gamification.xpHistory.prefix(12)) { item in
                        XPHistoryRow(entry: item)
                    }
                }
            }
        }
    }

    private var emptyHistoryCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.14))
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
            }
            Text("passport.history.empty".localized)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .padding(.horizontal, Theme.Spacing.md)
        .background(Theme.Colors.paperCard)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Section wrapper

    private func section<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
            }
            content()
        }
    }

    // MARK: Data

    private var achievements: [PassportAchievement] {
        let guides = appContainer.userStats.guidesReadCount
        let checklists = appContainer.userStats.activeChecklistsCount
        let hoursSaved = max(0, guides * 2 + checklists)
        let historyTypes = Set(gamification.xpHistory.map(\.type))

        return [
            .init(id: "first_guide",
                  title: "passport.achievement.reader.title".localized,
                  subtitle: "passport.achievement.reader.subtitle".localized(with: guides),
                  icon: "book.fill",
                  color: Theme.Colors.info,
                  isUnlocked: guides >= 1,
                  progress: min(Double(guides), 1)),
            .init(id: "bookworm",
                  title: "passport.achievement.bookworm.title".localized,
                  subtitle: "passport.achievement.bookworm.subtitle".localized(with: guides),
                  icon: "books.vertical.fill",
                  color: Theme.Colors.accentTurquoise,
                  isUnlocked: guides >= 5,
                  progress: min(Double(guides) / 5, 1)),
            .init(id: "organizer",
                  title: "passport.achievement.organizer.title".localized,
                  subtitle: "passport.achievement.organizer.subtitle".localized(with: checklists),
                  icon: "checklist",
                  color: Theme.Colors.success,
                  isUnlocked: checklists >= 1,
                  progress: min(Double(checklists), 1)),
            .init(id: "time_saver",
                  title: "passport.achievement.time_saver.title".localized,
                  subtitle: "passport.achievement.time_saver.subtitle".localized(with: hoursSaved),
                  icon: "clock.fill",
                  color: Theme.Colors.accent,
                  isUnlocked: hoursSaved >= 5,
                  progress: min(Double(hoursSaved) / 5, 1)),
            .init(id: "deadline_safe",
                  title: "passport.achievement.deadline_safe.title".localized,
                  subtitle: "passport.achievement.deadline_safe.subtitle".localized,
                  icon: "calendar.badge.checkmark",
                  color: Theme.Colors.accentCoral,
                  isUnlocked: historyTypes.contains(GamEventType.deadlineTracked.rawValue),
                  progress: historyTypes.contains(GamEventType.deadlineTracked.rawValue) ? 1 : 0),
            .init(id: "expert_ready",
                  title: "passport.achievement.expert_ready.title".localized,
                  subtitle: "passport.achievement.expert_ready.subtitle".localized,
                  icon: "bubble.left.and.bubble.right.fill",
                  color: Theme.Colors.primary,
                  isUnlocked: historyTypes.contains(GamEventType.expertQuestionAsked.rawValue),
                  progress: historyTypes.contains(GamEventType.expertQuestionAsked.rawValue) ? 1 : 0)
        ]
    }

    private var earnActions: [PassportEarnAction] {
        [
            .init(id: "guide", title: "passport.earn.guide.title".localized, subtitle: "passport.earn.guide.subtitle".localized,
                  xp: GamificationXP.value(for: .guideReadCompleted), icon: "book.fill", color: Theme.Colors.info),
            .init(id: "step", title: "passport.earn.step.title".localized, subtitle: "passport.earn.step.subtitle".localized,
                  xp: GamificationXP.value(for: .checklistStepCompleted), icon: "checkmark.circle.fill", color: Theme.Colors.success),
            .init(id: "checklist", title: "passport.earn.checklist.title".localized, subtitle: "passport.earn.checklist.subtitle".localized,
                  xp: GamificationXP.value(for: .checklistCompleted), icon: "checklist", color: Theme.Colors.primary),
            .init(id: "deadline", title: "passport.earn.deadline.title".localized, subtitle: "passport.earn.deadline.subtitle".localized,
                  xp: GamificationXP.value(for: .deadlineTracked), icon: "calendar.badge.clock", color: Theme.Colors.accent),
            .init(id: "expert", title: "passport.earn.expert.title".localized, subtitle: "passport.earn.expert.subtitle".localized,
                  xp: GamificationXP.value(for: .expertQuestionAsked), icon: "person.crop.circle.badge.questionmark", color: Theme.Colors.accentCoral),
            .init(id: "community", title: "passport.earn.community.title".localized, subtitle: "passport.earn.community.subtitle".localized,
                  xp: GamificationXP.value(for: .marketplaceContribution), icon: "person.2.fill", color: Theme.Colors.accentTurquoise)
        ]
    }
}

// MARK: - Hero footer cell

private struct HeroFooterCell: View {
    let title: String
    let value: String
    var accent: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Unlock row (timeline rail style)

private struct PassportUnlockRow: View {
    let level: SweezyPassportLevel
    let isCurrent: Bool
    let isUnlocked: Bool
    let isLast: Bool
    let currentXP: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline rail
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(dotFill)
                        .frame(width: 30, height: 30)
                    Circle()
                        .stroke(level.color.opacity(isUnlocked ? 0.45 : 0.18), lineWidth: 2)
                        .frame(width: 30, height: 30)
                    Image(systemName: dotIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isUnlocked ? .white : Theme.Colors.textTertiary)
                }
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    level.color.opacity(isUnlocked ? 0.45 : 0.15),
                                    Theme.Colors.adaptiveBorder
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 30)

            // Card content
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("L\(level.id)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(level.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(level.color.opacity(0.14)))

                    Text(level.unlockTitleKey.localized)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    if isCurrent {
                        Text("passport.unlock.current".localized)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.Colors.accent))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }

                Text(level.unlockDescriptionKey.localized)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.accent)
                    Text("passport.unlock.xp_format".localized(with: level.threshold))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)

                    if !isUnlocked {
                        let remaining = max(0, level.threshold - currentXP)
                        Text("·")
                            .foregroundColor(Theme.Colors.textTertiary)
                        Text("passport.hero.left_format".localized(with: remaining))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.paperCard)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isCurrent ? Theme.Colors.accent.opacity(0.55) : Theme.Colors.adaptiveBorder,
                        lineWidth: isCurrent ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.bottom, isLast ? 0 : 12)
        }
    }

    private var dotIcon: String {
        if isCurrent { return "star.fill" }
        if isUnlocked { return "checkmark" }
        return "lock.fill"
    }

    private var dotFill: Color {
        if isCurrent {
            return Theme.Colors.accent
        }
        if isUnlocked {
            return level.color
        }
        return Theme.Colors.adaptiveSurface
    }
}

// MARK: - Achievement card

private struct PassportAchievementCard: View {
    let achievement: PassportAchievement

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(achievement.isUnlocked ? achievement.color.opacity(0.18) : Theme.Colors.adaptiveSurface)
                        .frame(width: 46, height: 46)
                    if achievement.isUnlocked {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(achievement.color.opacity(0.45), lineWidth: 1)
                            .frame(width: 46, height: 46)
                    }
                    Image(systemName: achievement.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(achievement.isUnlocked ? achievement.color : Theme.Colors.textTertiary)
                }
                Spacer()
                if achievement.isUnlocked {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(achievement.color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(achievement.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.adaptiveSurface)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [achievement.color.opacity(0.55), achievement.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * CGFloat(min(max(achievement.progress, 0), 1))))
                }
            }
            .frame(height: 5)

            Text(percentLabel)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(achievement.isUnlocked ? achievement.color : Theme.Colors.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.paperCard)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    achievement.isUnlocked ? achievement.color.opacity(0.25) : Theme.Colors.adaptiveBorder,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(achievement.isUnlocked ? 1 : 0.85)
    }

    private var percentLabel: String {
        let p = Int((achievement.progress * 100).rounded())
        return "\(min(max(p, 0), 100))%"
    }
}

// MARK: - Earn action row

private struct PassportEarnActionRow: View {
    let action: PassportEarnAction

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(action.color.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: action.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(action.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                Text(action.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("passport.earn.xp_format".localized(with: action.xp))
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(action.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(action.color.opacity(0.14)))
        }
        .padding(14)
        .background(Theme.Colors.paperCard)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - XP history row

private struct XPHistoryRow: View {
    let entry: XPHistoryEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(entry.timestamp, style: .date)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            Text("passport.earn.xp_format".localized(with: entry.amount))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(color.opacity(0.14)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.Colors.paperCard)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var icon: String {
        switch entry.type {
        case GamEventType.guideReadCompleted.rawValue: return "book.fill"
        case GamEventType.checklistStepCompleted.rawValue, GamEventType.checklistCompleted.rawValue: return "checkmark.circle.fill"
        case GamEventType.roadmapStageCompleted.rawValue: return "map.fill"
        case GamEventType.notificationEnabled.rawValue: return "bell.badge.fill"
        case GamEventType.deadlineTracked.rawValue: return "calendar.badge.clock"
        case GamEventType.expertQuestionAsked.rawValue: return "bubble.left.and.bubble.right.fill"
        case GamEventType.marketplaceContribution.rawValue: return "person.2.fill"
        case GamEventType.profileCompleted.rawValue: return "person.crop.circle.badge.checkmark"
        default: return "sparkles"
        }
    }

    private var color: Color {
        switch entry.type {
        case GamEventType.guideReadCompleted.rawValue: return Theme.Colors.info
        case GamEventType.checklistStepCompleted.rawValue, GamEventType.checklistCompleted.rawValue: return Theme.Colors.success
        case GamEventType.deadlineTracked.rawValue: return Theme.Colors.accent
        case GamEventType.expertQuestionAsked.rawValue: return Theme.Colors.accentCoral
        case GamEventType.profileCompleted.rawValue: return Theme.Colors.primary
        default: return Theme.Colors.accentTurquoise
        }
    }
}
