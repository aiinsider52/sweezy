//
//  MountainRoadmapPreviewCard.swift
//  sweezy
//
//  Preview card for Home screen that shows current roadmap progress
//

import SwiftUI

struct MountainRoadmapPreviewCard: View {
    private struct DotSpec: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var roadmapService = RoadmapService()

    // TEMPORARY (App Store review): IAP removed — roadmap is fully unlocked.
    private var isPremium: Bool { true }

    private let cardCornerRadius: CGFloat = 28

    private let dots: [DotSpec] = [
        .init(id: 0, x: 0.08, y: 0.2, size: 3, opacity: 0.14),
        .init(id: 1, x: 0.18, y: 0.3, size: 2, opacity: 0.12),
        .init(id: 2, x: 0.33, y: 0.16, size: 2, opacity: 0.1),
        .init(id: 3, x: 0.52, y: 0.22, size: 3, opacity: 0.12),
        .init(id: 4, x: 0.7, y: 0.18, size: 2, opacity: 0.1),
        .init(id: 5, x: 0.86, y: 0.28, size: 3, opacity: 0.12)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(cardFill)

            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(cardGlow)

            GeometryReader { geo in
                ZStack {
                    ForEach(dots) { dot in
                        Circle()
                            .fill((colorScheme == .dark ? Color.white : Theme.Colors.primary).opacity(dot.opacity))
                            .frame(width: dot.size, height: dot.size)
                            .position(x: geo.size.width * dot.x, y: geo.size.height * dot.y)
                    }

                    Circle()
                        .fill(Theme.Colors.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                        .frame(width: 170, height: 170)
                        .blur(radius: 40)
                        .position(x: geo.size.width * 0.14, y: geo.size.height * 0.16)

                    Circle()
                        .fill(Theme.Colors.accentTurquoise.opacity(colorScheme == .dark ? 0.08 : 0.06))
                        .frame(width: 180, height: 180)
                        .blur(radius: 44)
                        .position(x: geo.size.width * 0.84, y: geo.size.height * 0.18)

                    RoadmapPreviewAlps()
                        .fill(alpsBackFill)
                        .frame(height: geo.size.height * 0.26)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .offset(y: 2)

                    RoadmapPreviewAlps()
                        .fill(alpsFrontFill)
                        .frame(height: geo.size.height * 0.22)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(roadmapService.currentLevel.map { $0.title.localized } ?? "roadmap.default_level_title".localized)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)

                        Text("roadmap.level_of_total_format".localized(with: roadmapService.progress.currentLevel))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    ZStack {
                        Circle()
                            .fill(Theme.Colors.adaptiveSurface)
                            .frame(width: 68, height: 68)

                        Circle()
                            .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
                            .frame(width: 68, height: 68)

                        Circle()
                            .trim(from: 0, to: max(0.04, roadmapService.levelProgress(for: roadmapService.progress.currentLevel)))
                            .stroke(Theme.Colors.gradientPrimaryAdaptive, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 68, height: 68)
                            .rotationEffect(.degrees(-90))

                        Image(systemName: roadmapService.currentLevel?.iconName ?? "flag.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("roadmap.overall_progress".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text("\(Int(roadmapService.overallProgress * 100))%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.Colors.adaptiveSurface)

                            Capsule()
                                .fill(Theme.Colors.gradientPrimaryAdaptive)
                                .frame(width: max(geo.size.width * roadmapService.overallProgress, roadmapService.overallProgress > 0 ? 14 : 0))
                        }
                    }
                    .frame(height: 10)
                }

                HStack(spacing: 7) {
                    ForEach(1...10, id: \.self) { levelId in
                        let level = roadmapService.levels.first { $0.id == levelId }
                        let status = level.map { roadmapService.status(for: $0, isPremium: isPremium) } ?? .locked

                        Circle()
                            .fill(levelIndicatorColor(for: status))
                            .frame(width: 11, height: 11)
                            .overlay(
                                Circle()
                                    .stroke(Theme.Colors.adaptiveBorder.opacity(0.75), lineWidth: 1)
                            )
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text("common.open".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 18, y: 10)
        .onAppear {
            roadmapService.refreshFromStorage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .roadmapProgressUpdated)) { _ in
            roadmapService.refreshFromStorage()
        }
    }

    private var cardFill: some ShapeStyle {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Theme.Colors.darkCard, Theme.Colors.darkElevated, Theme.Colors.darkCard]
                : [Theme.Colors.adaptiveCard, Theme.Colors.surface.opacity(0.96), Theme.Colors.adaptiveCard],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardGlow: some ShapeStyle {
        LinearGradient(
            colors: [Theme.Colors.primary.opacity(colorScheme == .dark ? 0.16 : 0.08), .clear, Theme.Colors.accentTurquoise.opacity(colorScheme == .dark ? 0.08 : 0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var alpsBackFill: some ShapeStyle {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Theme.Colors.primary.opacity(0.10), Theme.Colors.darkSurface.opacity(0.14)]
                : [Theme.Colors.textTertiary.opacity(0.05), Theme.Colors.primary.opacity(0.025)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var alpsFrontFill: some ShapeStyle {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Theme.Colors.primary.opacity(0.16), Theme.Colors.darkSurface.opacity(0.18)]
                : [Theme.Colors.primary.opacity(0.07), Theme.Colors.accentTurquoise.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Theme.Colors.primary.opacity(0.12)
    }

    private func levelIndicatorColor(for status: LevelStatus) -> Color {
        switch status {
        case .completed: return Theme.Colors.success
        case .inProgress: return Theme.Colors.accent
        case .available: return Theme.Colors.primary
        case .locked: return Theme.Colors.adaptiveBorder.opacity(0.9)
        }
    }
}

private struct RoadmapPreviewAlps: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.46))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.66))
        path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.56))
        path.addLine(to: CGPoint(x: w * 0.63, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.7))
        path.addLine(to: CGPoint(x: w, y: h * 0.92))
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

#Preview {
    MountainRoadmapPreviewCard()
        .environmentObject(AppContainer())
        .padding()
        .background(Theme.Colors.primaryBackground)
}
