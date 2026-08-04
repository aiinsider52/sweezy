//
//  CityHubView.swift
//  sweezy
//

import SwiftUI
import MapKit

private enum CityHubTab: Int, CaseIterable {
    case discover
    case live
    case guides

    var titleKey: String {
        switch self {
        case .discover: return "cityhub.tab.discover"
        case .live: return "cityhub.tab.live"
        case .guides: return "cityhub.tab.guides"
        }
    }
}

struct CityHubView: View {
    let hub: CityHubDefinition

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    @State private var tab: CityHubTab = .discover
    @State private var visitedSpotIDs: Set<String> = []
    @State private var completedStepIDs: Set<String> = []
    @State private var selectedGuide: Guide?
    @State private var selectedSpot: CityHubSpot?
    @State private var showJobs = false

    private static let sheetCornerRadius: CGFloat = 32

    private var allSpots: [CityHubSpot] {
        hub.mustSee + hub.culture + hub.localLife
    }

    private var featuredSpot: CityHubSpot? {
        hub.mustSee.first { !visitedSpotIDs.contains($0.id) } ?? hub.mustSee.first
    }

    private var zurichPlaces: [Place] {
        appContainer.contentService.places.filter { place in
            place.canton == hub.canton
                || place.address.city.localizedCaseInsensitiveContains("Zürich")
                || place.address.city.localizedCaseInsensitiveContains("Zurich")
        }
    }

    private var zurichGuides: [Guide] {
        appContainer.contentService.guides
            .filter { $0.appliesTo(canton: hub.canton) }
            .sorted { $0.priority > $1.priority }
            .prefix(6)
            .map { $0 }
    }

    private var discoveryProgress: CGFloat {
        CityHubProgressStore.discoveryProgress(cityId: hub.id, totalSpots: allSpots.count)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Theme.Colors.ink
                Theme.Colors.paper
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                inkHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        switch tab {
                        case .discover:
                            discoverTab
                        case .live:
                            liveTab
                        case .guides:
                            guidesTab
                        }
                    }
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Self.sheetCornerRadius,
                        topTrailingRadius: Self.sheetCornerRadius,
                        style: .continuous
                    )
                    .fill(Theme.Colors.paper)
                )
                .padding(.top, -Self.sheetCornerRadius)
            }
        }
        .navigationBarHidden(true)
        .interactiveSwipeBackEnabled()
        .navigationDestination(item: $selectedGuide) { guide in
            GuideDetailView(guide: guide)
        }
        .sheet(item: $selectedSpot) { spot in
            CityHubSpotSheet(
                spot: spot,
                heroImageName: hub.heroImageName,
                isVisited: visitedSpotIDs.contains(spot.id),
                onToggleVisited: { toggleVisited(spot) },
                onShowMap: { focusSpotOnMap(spot) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showJobs) {
            NavigationStack {
                JobsView()
                    .environmentObject(appContainer)
            }
        }
        .onAppear {
            reloadProgress()
            appContainer.telemetry.retention(
                .contentOpened,
                source: "city_hub",
                meta: ["city": hub.id]
            )
        }
    }

    // MARK: - Ink header

    private var inkHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.36))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.back".localized)

                VStack(alignment: .leading, spacing: 4) {
                    Text(hub.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textOnPrimary)
                    Text("cityhub.subtitle".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer()

                discoveryBadge
            }

            HStack(spacing: 8) {
                ForEach(hub.facts.prefix(3)) { fact in
                    Text(fact.valueKey.localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
            }

            PillSegmentedControl(
                items: CityHubTab.allCases.map { $0.titleKey.localized },
                selection: Binding(
                    get: { tab.rawValue },
                    set: { tab = CityHubTab(rawValue: $0) ?? .discover }
                )
            )
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.lg + Self.sheetCornerRadius)
        .background(
            ZStack {
                Theme.Colors.ink
                Image(hub.heroImageName)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.22)
                    .blur(radius: 2)
                    .allowsHitTesting(false)
                LinearGradient(
                    colors: [Theme.Colors.ink.opacity(0.55), Theme.Colors.ink],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        )
    }

    private var discoveryBadge: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: discoveryProgress)
                .stroke(Theme.Colors.primaryLight, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(visitedSpotIDs.count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Discover tab

    @ViewBuilder
    private var discoverTab: some View {
        if let featured = featuredSpot {
            featuredSpotCard(featured)
        }

        spotGallery(
            title: "cityhub.mustsee.subtitle".localized,
            spots: hub.mustSee
        )

        spotGallery(
            title: hub.cultureTitleKey.localized,
            spots: hub.culture
        )

        spotGallery(
            title: hub.localTitleKey.localized,
            spots: hub.localLife
        )
    }

    private func featuredSpotCard(_ spot: CityHubSpot) -> some View {
        Button {
            selectedSpot = spot
        } label: {
            ZStack(alignment: .bottomLeading) {
                CityHubSpotVisual(spot: spot, heroImageName: hub.heroImageName, height: 200)

                VStack(alignment: .leading, spacing: 8) {
                    Text("cityhub.featured.badge".localized.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Theme.Colors.primaryLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.35)))

                    Text(spot.titleKey.localized)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Text(spot.whyKey.localized)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(2)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func spotGallery(title: String, spots: [CityHubSpot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(spots) { spot in
                        CityHubSpotPhotoCard(
                            spot: spot,
                            heroImageName: hub.heroImageName,
                            isVisited: visitedSpotIDs.contains(spot.id)
                        ) {
                            selectedSpot = spot
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Live tab

    private var liveTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            liveCostCard

            VStack(alignment: .leading, spacing: 12) {
                Text(hub.firstStepsTitleKey.localized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Spacing.lg)

                VStack(spacing: 10) {
                    ForEach(hub.firstSteps) { step in
                        CityHubInkStepRow(
                            step: step,
                            isCompleted: completedStepIDs.contains(step.id),
                            onToggle: { toggleStep(step) }
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            if !zurichPlaces.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(hub.placesTitleKey.localized)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Button(action: openCityOnMap) {
                            Text("cityhub.places.view_map".localized)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    VStack(spacing: 8) {
                        ForEach(Array(zurichPlaces.prefix(4))) { place in
                            CityHubInkPlaceRow(place: place) {
                                focusPlaceOnMap(place)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
        }
    }

    private var liveCostCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("cityhub.live.cost_title".localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 0) {
                ForEach(Array(hub.costFacts.enumerated()), id: \.element.id) { index, fact in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1, height: 36)
                    }
                    VStack(spacing: 4) {
                        Text(fact.valueKey.localized)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(fact.labelKey.localized)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CityHubInkSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CityHubInkSurface.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Guides tab

    private var guidesTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            HStack(spacing: 10) {
                CityHubQuickAction(
                    icon: "map.fill",
                    title: "cityhub.map.cta_format".localized(with: hub.title),
                    tint: Color(red: 0.92, green: 0.78, blue: 0.28),
                    action: openCityOnMap
                )
                CityHubQuickAction(
                    icon: "briefcase.fill",
                    title: "cityhub.jobs.cta_format".localized(with: hub.title),
                    tint: Theme.Colors.accent,
                    action: openJobs
                )
            }
            .padding(.horizontal, Theme.Spacing.lg)

            if zurichGuides.isEmpty {
                Text("cityhub.tab.empty".localized)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.lg)
            } else {
                VStack(spacing: 10) {
                    ForEach(zurichGuides) { guide in
                        Button {
                            selectedGuide = guide
                        } label: {
                            CityHubGuideCard(guide: guide)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Actions

    private func reloadProgress() {
        visitedSpotIDs = CityHubProgressStore.visitedSpotIDs(cityId: hub.id)
        completedStepIDs = CityHubProgressStore.completedStepIDs(cityId: hub.id)
    }

    private func toggleVisited(_ spot: CityHubSpot) {
        let next = !visitedSpotIDs.contains(spot.id)
        CityHubProgressStore.setVisited(next, spotId: spot.id, cityId: hub.id)
        visitedSpotIDs = CityHubProgressStore.visitedSpotIDs(cityId: hub.id)
    }

    private func toggleStep(_ step: CityHubFirstStep) {
        let next = !completedStepIDs.contains(step.id)
        CityHubProgressStore.setStepCompleted(next, stepId: step.id, cityId: hub.id)
        completedStepIDs = CityHubProgressStore.completedStepIDs(cityId: hub.id)
    }

    private func focusSpotOnMap(_ spot: CityHubSpot) {
        selectedSpot = nil
        guard let coordinate = spot.coordinate else {
            openCityOnMap()
            return
        }
        MapFocusRouter.pending = MapFocusTarget(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            spanDelta: 0.03
        )
        NotificationCenter.default.post(name: .switchTab, object: 2)
    }

    private func focusPlaceOnMap(_ place: Place) {
        let coord = place.coordinate.clLocationCoordinate
        MapFocusRouter.pending = MapFocusTarget(
            latitude: coord.latitude,
            longitude: coord.longitude,
            spanDelta: 0.03
        )
        NotificationCenter.default.post(name: .switchTab, object: 2)
    }

    private func openCityOnMap() {
        MapFocusRouter.pending = MapFocusTarget(
            latitude: hub.mapCenter.latitude,
            longitude: hub.mapCenter.longitude,
            spanDelta: hub.mapSpanDelta
        )
        NotificationCenter.default.post(name: .switchTab, object: 2)
    }

    private func openJobs() {
        JobsSearchPreset.pendingCanton = hub.canton.rawValue
        JobsSearchPreset.pendingCity = hub.jobsCityQuery
        showJobs = true
    }
}

// MARK: - Visual system

private enum CityHubInkSurface {
    static let card = Color(red: 0.10, green: 0.15, blue: 0.12)
    static let cardBorder = Color.white.opacity(0.08)
}

private enum CityHubSpotPalette {
    static func gradient(for spot: CityHubSpot) -> [Color] {
        switch spot.kind {
        case .mustSee:
            return [Color(red: 0.14, green: 0.32, blue: 0.28), Color(red: 0.28, green: 0.52, blue: 0.42)]
        case .culture:
            return [Color(red: 0.18, green: 0.22, blue: 0.42), Color(red: 0.38, green: 0.42, blue: 0.68)]
        case .local:
            return [Color(red: 0.32, green: 0.24, blue: 0.14), Color(red: 0.58, green: 0.42, blue: 0.22)]
        }
    }
}

private struct CityHubSpotVisual: View {
    let spot: CityHubSpot
    let heroImageName: String
    var height: CGFloat = 168

    private var resolvedImageName: String {
        spot.imageName ?? heroImageName
    }

    private var hasDedicatedPhoto: Bool {
        spot.imageName != nil
    }

    var body: some View {
        ZStack {
            Image(resolvedImageName)
                .resizable()
                .scaledToFill()
                .frame(height: height)
                .clipped()

            if !hasDedicatedPhoto {
                LinearGradient(
                    colors: CityHubSpotPalette.gradient(for: spot) + [.black.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.multiply)

                Image(systemName: spot.icon)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundColor(.white.opacity(0.18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(16)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(hasDedicatedPhoto ? 0.55 : 0.65)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .frame(height: height)
    }
}

private struct CityHubSpotPhotoCard: View {
    let spot: CityHubSpot
    let heroImageName: String
    let isVisited: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                CityHubSpotVisual(spot: spot, heroImageName: heroImageName, height: 196)

                VStack(alignment: .leading, spacing: 4) {
                    if isVisited {
                        Label("cityhub.spot.visited".localized, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryLight)
                    }
                    Text(spot.titleKey.localized)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .padding(14)
            }
            .frame(width: 148)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
    }
}

private struct CityHubSpotSheet: View {
    let spot: CityHubSpot
    let heroImageName: String
    let isVisited: Bool
    let onToggleVisited: () -> Void
    let onShowMap: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                CityHubSpotVisual(spot: spot, heroImageName: heroImageName, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(spot.titleKey.localized)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(spot.whyKey.localized)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let tip = spot.tipKey?.localized {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(Theme.Colors.primaryLight)
                            Text(tip)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.Colors.primary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.Colors.primary.opacity(0.1))
                        )
                    }
                }

                VStack(spacing: 10) {
                    Button(action: onToggleVisited) {
                        HStack {
                            Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                            Text(isVisited ? "cityhub.spot.visited".localized : "cityhub.spot.mark_visited".localized)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if spot.coordinate != nil {
                        Button(action: onShowMap) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("cityhub.spot.on_map".localized)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.Colors.primary.opacity(0.35), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .journeyScreen(.zurich, darkness: 0.72)
    }
}

private struct CityHubInkStepRow: View {
    let step: CityHubFirstStep
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Capsule()
                        .fill(Theme.Colors.primaryLight.opacity(isCompleted ? 0.35 : 0.18))
                        .frame(width: 40, height: 32)
                    Image(systemName: isCompleted ? "checkmark" : step.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isCompleted ? .white : Theme.Colors.primaryLight)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(step.titleKey.localized)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .strikethrough(isCompleted, color: .white.opacity(0.4))
                    Text(step.detailKey.localized)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.52))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CityHubInkSurface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(CityHubInkSurface.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CityHubInkPlaceRow: View {
    let place: Place
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: place.type.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(place.type.swiftUIColor)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(place.type.swiftUIColor.opacity(0.15)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(place.type.localizedName)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Colors.primaryLight)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CityHubInkSurface.card)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CityHubQuickAction: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Capsule()
                        .fill(tint.opacity(0.2))
                        .frame(width: 44, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(tint)
                }
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(CityHubInkSurface.card)
            )
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
    }
}

private struct CityHubGuideCard: View {
    let guide: Guide

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.primary.opacity(0.25), Theme.Colors.primaryLight.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.Colors.primary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(guide.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                Text(guide.category.localizedName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.Colors.paperCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
        )
    }
}
