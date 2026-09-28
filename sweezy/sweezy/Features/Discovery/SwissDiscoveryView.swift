import MapKit
import SwiftUI
import UIKit

private enum SwissDiscoveryPresentation: String, CaseIterable, Identifiable {
    case list
    case map

    var id: String { rawValue }
    var title: String { "swiss.discovery.view.\(rawValue)".localized }
    var icon: String { self == .list ? "square.grid.2x2.fill" : "map.fill" }
}

struct SwissDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    @State private var query = ""
    @State private var selectedFilter: SwissDiscoveryFilter = .all
    @State private var selectedSetting: SwissDiscoverySetting = .all
    @State private var selectedPlace: SwissDiscoveryPlace?
    @State private var savedPlaceIDs = Set<String>()
    @State private var showsSavedOnly = false
    @State private var showsHiddenOnly = false
    @State private var presentation: SwissDiscoveryPresentation = .list
    @State private var ratingSummaries: [String: APIClient.DiscoveryRatingSummary] = [:]
    @State private var showPlanner = false
    @State private var showPaywall = false
    @StateObject private var subscription = SubscriptionManager.shared

    private var filteredPlaces: [SwissDiscoveryPlace] {
        SwissDiscoveryCatalog.places.filter { place in
            place.matches(query: query, filter: selectedFilter)
                && place.matches(setting: selectedSetting)
                && (!showsSavedOnly || savedPlaceIDs.contains(place.id))
                && (!showsHiddenOnly || Self.hiddenPlaceIDs.contains(place.id))
        }
    }

    var body: some View {
        ZStack {
            JourneyVisual.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    searchAndFilters

                    plusTravelCard

                    if presentation == .map, !filteredPlaces.isEmpty {
                        SwissDiscoveryMapView(places: filteredPlaces, ratings: ratingSummaries) { selectedPlace = $0 }
                    } else if let featured = filteredPlaces.first {
                        sectionHeader(
                            title: showsSavedOnly
                                ? "swiss.discovery.saved_title".localized
                                : "swiss.discovery.featured".localized,
                            count: filteredPlaces.count
                        )

                        SwissDiscoveryFeaturedCard(
                            place: featured,
                            rating: ratingSummaries[featured.id],
                            isSaved: savedPlaceIDs.contains(featured.id),
                            action: { selectedPlace = featured },
                            toggleSaved: { toggleSaved(featured) }
                        )

                        if filteredPlaces.count > 1 {
                            if !showsSavedOnly && query.isEmpty {
                                settingCollections
                            }

                            sectionHeader(
                                title: "swiss.discovery.all_places".localized,
                                count: filteredPlaces.count - 1
                            )

                            LazyVStack(spacing: 14) {
                                ForEach(Array(filteredPlaces.dropFirst().enumerated()), id: \.element.id) { index, place in
                                    SwissDiscoveryEditorialCard(
                                        place: place,
                                        rating: ratingSummaries[place.id],
                                        index: index + 2,
                                        isSaved: savedPlaceIDs.contains(place.id),
                                        action: { selectedPlace = place },
                                        toggleSaved: { toggleSaved(place) }
                                    )
                                }
                            }
                        }
                    } else {
                        emptyState
                    }

                    sourceFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 128)
            }
        }
        .statusBarScrim()
        .navigationBarHidden(true)
        .interactiveSwipeBackEnabled()
        .navigationDestination(item: $selectedPlace) { place in
            SwissDiscoveryDetailView(
                place: place,
                isSaved: savedPlaceIDs.contains(place.id),
                toggleSaved: { toggleSaved(place) }
            )
        }
        .sheet(isPresented: $showPlanner) { SwissTripPlannerView() }
        .fullScreenCover(isPresented: $showPaywall) { SubscriptionView(source: .profile) }
        .onAppear {
            savedPlaceIDs = SwissDiscoveryProgressStore.savedPlaceIDs()
            appContainer.telemetry.retention(
                .contentOpened,
                source: "swiss_discovery",
                meta: ["places": String(SwissDiscoveryCatalog.places.count)]
            )
        }
        .task {
            guard let summaries = try? await APIClient.fetchDiscoveryRatings() else { return }
            ratingSummaries = Dictionary(uniqueKeysWithValues: summaries.map { ($0.placeID, $0) })
        }
        .accessibilityIdentifier("swiss.discovery.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(JourneyVisual.primaryText)
                        .frame(width: 46, height: 46)
                        .background(Theme.Colors.card)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
                }
                .accessibilityIdentifier("swiss.discovery.back")
                .accessibilityLabel("common.back".localized)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showsSavedOnly.toggle()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: showsSavedOnly ? "bookmark.fill" : "bookmark")
                        Text(String(savedPlaceIDs.count))
                            .contentTransition(.numericText(value: Double(savedPlaceIDs.count)))
                    }
                    .font(.system(size: 14, weight: .bold, design: .default))
                    .foregroundStyle(showsSavedOnly ? .black : JourneyVisual.primaryText)
                    .padding(.horizontal, 15)
                    .frame(height: 46)
                    .background(showsSavedOnly ? JourneyVisual.lime : Theme.Colors.card)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(showsSavedOnly ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
                }
                .accessibilityLabel("swiss.discovery.saved".localized)
            }

            // The promenade with the signpost: "go and explore".
            FocusedSceneImage(name: "city-scene-map", focusY: 0.35)
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Label("swiss.discovery.eyebrow".localized, systemImage: "binoculars.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(JourneyVisual.lime, in: Capsule())
                        .padding(14)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(JourneyVisual.softBorder, lineWidth: 1)
                )
                .shadow(color: JourneyVisual.black.opacity(0.08), radius: 14, y: 6)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text("swiss.discovery.title".localized)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("swiss.discovery.subtitle".localized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Search and the list/map switch share one row; "where" is a menu at the head of the topic row.
    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                JourneySearchField(text: $query, prompt: "swiss.discovery.search".localized)

                HStack(spacing: 2) {
                    ForEach(SwissDiscoveryPresentation.allCases) { option in
                        let selected = presentation == option
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                presentation = option
                            }
                        } label: {
                            Image(systemName: option.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(selected ? .black : JourneyVisual.secondaryText)
                                .frame(width: 42, height: 40)
                                .background(selected ? JourneyVisual.lime : Color.clear, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(4)
                .background(Theme.Colors.card, in: Capsule())
                .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    settingMenu

                    Rectangle()
                        .fill(JourneyVisual.softBorder)
                        .frame(width: 1, height: 22)
                        .padding(.horizontal, 2)

                    ForEach(SwissDiscoveryFilter.allCases) { filter in
                        compactChip(
                            title: filter.title,
                            icon: filter.icon,
                            selected: selectedFilter == filter
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    /// Where to go (anywhere / cities / mountains / lakes) as one menu chip instead of a second chip row.
    private var settingMenu: some View {
        let active = selectedSetting != .all
        return Menu {
            Picker("swiss.discovery.setting.all".localized, selection: $selectedSetting.animation(.easeInOut(duration: 0.2))) {
                ForEach(SwissDiscoverySetting.allCases) { setting in
                    Label(setting.title, systemImage: setting.icon).tag(setting)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: active ? selectedSetting.icon : "mappin.and.ellipse")
                Text(selectedSetting.title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .black))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(active ? JourneyVisual.lime : JourneyVisual.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(active ? JourneyVisual.black : Theme.Colors.card, in: Capsule())
            .overlay(Capsule().stroke(active ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
        }
        .accessibilityLabel(selectedSetting.title)
    }

    private func compactChip(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selected ? .black : JourneyVisual.primaryText)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(selected ? JourneyVisual.lime : Theme.Colors.card, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Both Plus extras side by side in one short row.
    private var plusTravelCard: some View {
        HStack(spacing: 8) {
            plusPill(
                icon: "sparkles",
                swatch: JourneyCategoryPalette.lime,
                title: "AI-план поїздки"
            ) {
                if subscription.isPremium { showPlanner = true } else { showPaywall = true }
            }

            plusPill(
                icon: showsHiddenOnly ? "square.grid.2x2.fill" : "eye.slash.fill",
                swatch: JourneyCategoryPalette.lilac,
                title: showsHiddenOnly ? "Усі місця" : "Приховані місця",
                active: showsHiddenOnly
            ) {
                guard subscription.isPremium else { showPaywall = true; return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsHiddenOnly.toggle()
                    showsSavedOnly = false
                    presentation = .list
                }
            }
        }
    }

    private func plusPill(
        icon: String,
        swatch: JourneyCategorySwatch,
        title: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                JourneyCategoryIcon(symbol: icon, swatch: swatch, size: 30, selected: active)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(JourneyVisual.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !subscription.isPremium {
                        Text("PLUS")
                            .font(.system(size: 8, weight: .black))
                            .tracking(0.6)
                            .foregroundStyle(JourneyVisual.accentText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(active ? JourneyVisual.accentStrong : JourneyVisual.lime.opacity(0.4), lineWidth: active ? 1.5 : 1)
            )
        }
        .buttonStyle(CardPressStyle())
    }

    private var settingCollections: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("swiss.discovery.collections.title".localized)
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundStyle(JourneyVisual.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SwissDiscoverySetting.allCases.filter { $0 != .all }) { setting in
                        let place = representativePlace(for: setting)
                        SwissDiscoverySettingCard(setting: setting, place: place) {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                                selectedSetting = setting
                            }
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    private func representativePlace(for setting: SwissDiscoverySetting) -> SwissDiscoveryPlace {
        let preferredID: String
        switch setting {
        case .city: preferredID = "locarno"
        case .mountain: preferredID = "crans-montana"
        case .lake: preferredID = "interlaken"
        case .all: preferredID = "bern-region"
        }
        return SwissDiscoveryCatalog.places.first(where: { $0.id == preferredID })
            ?? SwissDiscoveryCatalog.places[0]
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundStyle(JourneyVisual.primaryText)
            Spacer()
            Text("swiss.discovery.places_count".localized(with: count))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(JourneyVisual.secondaryText)
        }
    }

    private var emptyState: some View {
        JourneyGlassPanel(cornerRadius: 26) {
            VStack(spacing: 13) {
                Image(systemName: showsSavedOnly ? "bookmark.slash" : "binoculars.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("swiss.discovery.empty.title".localized)
                    .font(.system(size: 19, weight: .bold, design: .default))
                    .foregroundStyle(JourneyVisual.primaryText)
                Text("swiss.discovery.empty.subtitle".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .multilineTextAlignment(.center)
                Button("swiss.discovery.empty.reset".localized) {
                    query = ""
                    selectedFilter = .all
                    selectedSetting = .all
                    showsSavedOnly = false
                    showsHiddenOnly = false
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(JourneyVisual.lime)
                .clipShape(Capsule())
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private var sourceFooter: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("swiss.discovery.source_footer".localized(with: SwissDiscoveryCatalog.verifiedAt))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private func toggleSaved(_ place: SwissDiscoveryPlace) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if savedPlaceIDs.contains(place.id) {
            savedPlaceIDs.remove(place.id)
        } else {
            if !subscription.isPremium && savedPlaceIDs.count >= 5 {
                showPaywall = true
                return
            }
            savedPlaceIDs.insert(place.id)
        }
        SwissDiscoveryProgressStore.save(savedPlaceIDs)
    }

    private static let hiddenPlaceIDs: Set<String> = ["creux-du-van", "ruinaulta", "monte-generoso", "st-gallen-abbey"]
}

private struct SwissDiscoveryMapView: View {
    let places: [SwissDiscoveryPlace]
    let ratings: [String: APIClient.DiscoveryRatingSummary]
    let openPlace: (SwissDiscoveryPlace) -> Void

    @State private var selectedPlace: SwissDiscoveryPlace?
    @State private var position: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 46.82, longitude: 8.23),
            distance: 430_000,
            heading: 0,
            pitch: 38
        )
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("swiss.discovery.map.title".localized)
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundStyle(.white)

            Map(position: $position) {
                ForEach(places) { place in
                    Annotation(place.title, coordinate: place.coordinate, anchor: .bottom) {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                selectedPlace = place
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Image(systemName: selectedPlace?.id == place.id ? "mappin.circle.fill" : "mappin.circle")
                                    .font(.system(size: selectedPlace?.id == place.id ? 38 : 31, weight: .bold))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, JourneyVisual.lime)
                                    .shadow(color: .black.opacity(0.46), radius: 6, y: 4)
                                Text(place.title)
                                    .font(.system(size: 9, weight: .bold, design: .default))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 7)
                                    .frame(height: 23)
                                    .background(Color.black.opacity(0.8))
                                    .clipShape(Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .frame(height: 560)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(alignment: .bottom) {
                if let selectedPlace {
                    Button { openPlace(selectedPlace) } label: {
                        HStack(spacing: 12) {
                            Image(selectedPlace.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedPlace.title)
                                    .font(.system(size: 16, weight: .bold, design: .default))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text(selectedPlace.region)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.62))
                                if let rating = ratings[selectedPlace.id], rating.reviewCount > 0 {
                                    Label(String(format: "%.1f", rating.averageRating), systemImage: "star.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(JourneyVisual.accentText)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 42, height: 42)
                                .background(JourneyVisual.lime)
                                .clipShape(Circle())
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.24), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.28), lineWidth: 1))
        }
    }
}

private struct SwissDiscoveryFeaturedCard: View {
    let place: SwissDiscoveryPlace
    let rating: APIClient.DiscoveryRatingSummary?
    let isSaved: Bool
    let action: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                featuredVisual
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(place.title), \(place.region)")
            .accessibilityIdentifier("swiss.discovery.place.\(place.id)")

            SwissDiscoverySaveButton(isSaved: isSaved, action: toggleSaved)
                .padding(14)
        }
        .accessibilityElement(children: .contain)
    }

    private var featuredVisual: some View {
        ZStack(alignment: .bottomLeading) {
                FittedAssetImage(name: place.imageName, height: 322)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.16), .black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 9) {
                    Label(place.region, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(JourneyVisual.lime)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Color.black.opacity(0.52))
                        .clipShape(Capsule())

                    Text(place.title)
                        .font(.system(size: 29, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: 14) {
                        Label(place.season, systemImage: "sun.max.fill")
                        Label(place.duration, systemImage: "clock.fill")
                        if let rating, rating.reviewCount > 0 {
                            Label(String(format: "%.1f", rating.averageRating), systemImage: "star.fill")
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                }
                .padding(18)
        }
        .frame(height: 322)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: JourneyVisual.lime.opacity(0.09), radius: 24, y: 12)
    }
}

private struct SwissDiscoverySettingCard: View {
    let setting: SwissDiscoverySetting
    let place: SwissDiscoveryPlace
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image(place.imageNames[1])
                    .resizable()
                    .scaledToFill()
                    .frame(width: 178, height: 166)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.82)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: setting.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(JourneyVisual.lime)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    Text(setting.title)
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                }
                .padding(13)
            }
            .frame(width: 178, height: 166)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SwissDiscoveryEditorialCard: View {
    let place: SwissDiscoveryPlace
    let rating: APIClient.DiscoveryRatingSummary?
    let index: Int
    let isSaved: Bool
    let action: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                ZStack(alignment: .bottomLeading) {
                FittedAssetImage(name: place.imageName, height: 252)

                LinearGradient(
                        colors: [.black.opacity(0.06), .clear, .black.opacity(0.92)],
                        startPoint: .top,
                    endPoint: .bottom
                )

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(String(format: "%02d", index))
                                .font(.system(size: 11, weight: .black, design: .default))
                                .foregroundStyle(.black)
                                .frame(width: 34, height: 26)
                                .background(JourneyVisual.lime)
                                .clipShape(Capsule())

                            Text(place.region.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.7)
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                        }

                        Text(place.title)
                            .font(.system(size: 25, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Text(place.summary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Label(place.duration, systemImage: "clock")
                            Label(place.season, systemImage: "sun.max")
                            if let rating, rating.reviewCount > 0 {
                                Label(String(format: "%.1f", rating.averageRating), systemImage: "star.fill")
                            }
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(JourneyVisual.lime)
                    }
                    .padding(16)
                }
                .frame(height: 252)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(place.title), \(place.region)")
            .accessibilityIdentifier("swiss.discovery.place.\(place.id)")

            SwissDiscoverySaveButton(isSaved: isSaved, action: toggleSaved, compact: true)
                .padding(13)
        }
        .shadow(color: .black.opacity(0.32), radius: 18, y: 9)
    }
}

private struct SwissDiscoverySaveButton: View {
    let isSaved: Bool
    let action: () -> Void
    var compact = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: compact ? 13 : 15, weight: .bold))
                .foregroundStyle(isSaved ? .black : .white)
                .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)
                .background(isSaved ? JourneyVisual.lime : Color.black.opacity(0.52))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(isSaved ? 0 : 0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "swiss.discovery.unsave".localized : "swiss.discovery.save".localized)
    }
}

struct SwissDiscoveryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager

    let place: SwissDiscoveryPlace
    let isSaved: Bool
    let toggleSaved: () -> Void

    @State private var visitedPlaceIDs = Set<String>()
    @State private var selectedPhotoIndex = 0
    @State private var reviewPage: APIClient.DiscoveryReviewPage?
    @State private var myReview: APIClient.DiscoveryReview?
    @State private var isLoadingReviews = false
    @State private var showReviewEditor = false
    @State private var showAuth = false
    @State private var pendingReviewAfterAuth = false
    @State private var reviewNotice: String?
    @State private var reviewLoadError: String?
    @State private var offlineNotice: String?
    @State private var downloadingOffline = false
    @StateObject private var offlineCache = OfflineMapCacheService()
    @StateObject private var subscription = SubscriptionManager.shared
    @State private var showPaywall = false

    private var isVisited: Bool { visitedPlaceIDs.contains(place.id) }

    var body: some View {
        ZStack(alignment: .top) {
            JourneyVisual.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    detailContent
                }
            }
            .ignoresSafeArea(edges: .top)

            stickyHeader
        }
        .navigationBarHidden(true)
        .interactiveSwipeBackEnabled()
        .onAppear {
            NotificationCenter.default.post(name: .setJourneyBottomBarHidden, object: true)
            visitedPlaceIDs = SwissDiscoveryProgressStore.visitedPlaceIDs()
            appContainer.telemetry.retention(
                .contentOpened,
                source: "swiss_discovery_detail",
                meta: ["place": place.id]
            )
        }
        .onDisappear {
            NotificationCenter.default.post(name: .setJourneyBottomBarHidden, object: false)
        }
        .task(id: sessionManager.isAuthenticated) {
            await loadReviews()
        }
        .onChange(of: sessionManager.isAuthenticated) { _, authenticated in
            guard authenticated, pendingReviewAfterAuth else { return }
            pendingReviewAfterAuth = false
            showAuth = false
            showReviewEditor = true
        }
        .sheet(isPresented: $showAuth) {
            AuthEntryView(showsCloseButton: true) { showAuth = false }
                .environment(\.locale, appContainer.currentLocale)
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showReviewEditor) {
            SwissDiscoveryReviewEditor(
                place: place,
                existingReview: myReview,
                onChanged: {
                    showReviewEditor = false
                    Task { await loadReviews() }
                }
            )
        }
        .fullScreenCover(isPresented: $showPaywall) { SubscriptionView(source: .profile) }
        .alert("Offline route", isPresented: Binding(get: { offlineNotice != nil }, set: { if !$0 { offlineNotice = nil } })) { Button("OK") {} } message: { Text(offlineNotice ?? "") }
        .accessibilityIdentifier("swiss.discovery.detail.\(place.id)")
    }

    private var stickyHeader: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 46, height: 46)
            }
            .accessibilityLabel("common.back".localized)
            .accessibilityIdentifier("swiss.discovery.detail.back")

            Spacer()

            ShareLink(item: place.officialURL) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 46, height: 46)
            }
            .accessibilityLabel("common.share".localized)

            Button(action: toggleSaved) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isSaved ? JourneyVisual.lime : .white)
                    .frame(width: 46, height: 46)
            }
            .accessibilityLabel(isSaved ? "swiss.discovery.unsave".localized : "swiss.discovery.save".localized)
        }
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.45), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
        .buttonStyle(SwissDiscoveryHeaderButtonStyle())
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(place.imageNames.enumerated()), id: \.offset) { index, imageName in
                    FittedAssetImage(name: imageName, height: 460)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            LinearGradient(
                colors: [.clear, .black.opacity(0.16), .black],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 11) {
                Label(place.region, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())

                Text(place.title)
                    .font(.system(size: 29, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(place.summary)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 52)

            HStack(spacing: 5) {
                ForEach(place.imageNames.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedPhotoIndex ? JourneyVisual.lime : Color.white.opacity(0.46))
                        .frame(width: index == selectedPhotoIndex ? 24 : 7, height: 7)
                }
            }
            // Between the summary and the paper sheet, clear of the header buttons.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 38)
        }
        .frame(height: 460)
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 9) {
                detailMetric(icon: "sun.max.fill", value: place.season)
                detailMetric(icon: "clock.fill", value: place.duration)
            }

            gallery

            VStack(alignment: .leading, spacing: 9) {
                Text("swiss.discovery.detail.why".localized)
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(JourneyVisual.primaryText)
                Text(place.details)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("swiss.discovery.detail.description")
            }

            detailInfoCard(
                icon: "lightbulb.max.fill",
                swatch: JourneyCategoryPalette.lime,
                title: "swiss.discovery.detail.tip".localized,
                text: place.tip
            )

            detailInfoCard(
                icon: "figure.walk.motion",
                swatch: JourneyCategoryPalette.sky,
                title: "swiss.discovery.detail.route_format".localized,
                text: place.route
            )

            Button(action: openInMaps) {
                HStack(spacing: 10) {
                    Image(systemName: "map.fill")
                    Text("swiss.discovery.detail.open_route".localized)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                guard subscription.isPremium else { showPaywall = true; return }
                Task {
                    downloadingOffline = true
                    defer { downloadingOffline = false }
                    do {
                        try await offlineCache.saveSnapshot(for: place.id, center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22))
                        offlineNotice = "Маршрут і карта-знімок збережені на цьому пристрої."
                    } catch { offlineNotice = "Не вдалося зберегти карту. Перевір з’єднання й спробуй ще раз." }
                }
            } label: {
                HStack { Image(systemName: offlineCache.hasSnapshot(for: place.id) ? "checkmark.circle.fill" : "arrow.down.circle.fill"); Text(offlineCache.hasSnapshot(for: place.id) ? "Доступно офлайн" : "Зберегти офлайн"); Spacer(); Text("PLUS").font(.caption.bold()) }
                    .font(.headline).foregroundStyle(Theme.Colors.textPrimary).padding(.horizontal, 18).frame(height: 54).background(JourneyVisual.lime.opacity(0.09)).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(JourneyVisual.lime.opacity(0.25)))
            }.buttonStyle(.plain).disabled(downloadingOffline)

            Link(destination: place.officialURL) {
                HStack(spacing: 12) {
                    JourneyCategoryIcon(symbol: "checkmark.seal.fill", swatch: JourneyCategoryPalette.teal, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("swiss.discovery.detail.official_source".localized)
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .foregroundStyle(JourneyVisual.primaryText)
                        Text("swiss.discovery.detail.verified".localized(with: SwissDiscoveryCatalog.verifiedAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(JourneyVisual.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(JourneyVisual.primaryText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: toggleVisited) {
                HStack(spacing: 10) {
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                    Text(isVisited ? "swiss.discovery.detail.visited".localized : "swiss.discovery.detail.mark_visited".localized)
                    Spacer()
                }
                .font(.system(size: 15, weight: .bold, design: .default))
                .foregroundStyle(isVisited ? Theme.Colors.textPrimary : JourneyVisual.secondaryText)
                .padding(.horizontal, 17)
                .frame(height: 52)
                .background(Theme.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(JourneyVisual.softBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            reviewsSection

            Text("swiss.discovery.detail.illustration_note".localized)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(JourneyVisual.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 44)
        // Paper sheet that slides over the photo instead of a hard black-to-white edge.
        .background(
            JourneyVisual.pageBackground,
            in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
        )
        .padding(.top, -28)
    }

    private func detailInfoCard(icon: String, swatch: JourneyCategorySwatch, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            JourneyCategoryIcon(symbol: icon, swatch: swatch, size: 40)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundStyle(JourneyVisual.primaryText)
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("swiss.discovery.gallery".localized)
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(JourneyVisual.primaryText)
                Spacer()
                Text("swiss.discovery.photos_count".localized(with: place.imageNames.count))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(JourneyVisual.secondaryText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(Array(place.imageNames.enumerated()), id: \.offset) { index, imageName in
                        Button {
                            withAnimation(.easeInOut(duration: 0.24)) { selectedPhotoIndex = index }
                        } label: {
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 146, height: 104)
                                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 19)
                                        .stroke(index == selectedPhotoIndex ? JourneyVisual.lime : Color.white.opacity(0.18), lineWidth: index == selectedPhotoIndex ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
        .accessibilityIdentifier("swiss.discovery.gallery")
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("swiss.discovery.reviews.title".localized)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundStyle(JourneyVisual.primaryText)
                    Text("swiss.discovery.reviews.count".localized(with: reviewPage?.reviewCount ?? 0))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(JourneyVisual.secondaryText)
                }
                Spacer()
                if let reviewPage, reviewPage.reviewCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(String(format: "%.1f", reviewPage.averageRating))
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundStyle(JourneyVisual.primaryText)
                    }
                }
            }

            Button(action: reviewButtonTapped) {
                HStack(spacing: 10) {
                    Image(systemName: myReview == nil ? "star.bubble.fill" : "pencil.circle.fill")
                    Text(sessionManager.isAuthenticated
                         ? (myReview == nil ? "swiss.discovery.reviews.write".localized : "swiss.discovery.reviews.edit".localized)
                         : "swiss.discovery.reviews.sign_in".localized)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 15, weight: .bold, design: .default))
                .foregroundStyle(.black)
                .padding(.horizontal, 17)
                .frame(height: 54)
                .background(JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            if let reviewNotice {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(reviewNotice)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(JourneyVisual.secondaryText)
                    Spacer()
                    Button { self.reviewNotice = nil } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(JourneyVisual.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Theme.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }

            if let reviewLoadError {
                JourneyGlassPanel(cornerRadius: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.orange)
                        Text(reviewLoadError)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(JourneyVisual.secondaryText)
                        Spacer()
                        Button {
                            Task { await loadReviews() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(width: 38, height: 38)
                                .background(Theme.Colors.card)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("swiss.discovery.reviews.retry".localized)
                    }
                    .padding(14)
                }
            } else if isLoadingReviews && reviewPage == nil {
                ProgressView()
                    .tint(JourneyVisual.lime)
                    .frame(maxWidth: .infinity, minHeight: 90)
            } else if let items = reviewPage?.items, !items.isEmpty {
                ForEach(items) { review in
                    reviewCard(review)
                }
            } else if reviewPage != nil {
                Text("swiss.discovery.reviews.empty".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityIdentifier("swiss.discovery.reviews")
    }

    private func reviewCard(_ review: APIClient.DiscoveryReview) -> some View {
        JourneyGlassPanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(review.authorLabel)
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .foregroundStyle(.white)
                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { value in
                                Image(systemName: value <= review.rating ? "star.fill" : "star")
                            }
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(JourneyVisual.accentText)
                    }
                    Spacer()
                    if !review.isMine {
                        Menu {
                            Button("swiss.discovery.reviews.report".localized, role: .destructive) {
                                report(review)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                Text(review.comment)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private func reviewButtonTapped() {
        if sessionManager.isAuthenticated {
            showReviewEditor = true
        } else {
            pendingReviewAfterAuth = true
            showAuth = true
        }
    }

    private func loadReviews() async {
        isLoadingReviews = true
        reviewLoadError = nil
        defer { isLoadingReviews = false }
        do {
            reviewPage = try await APIClient.fetchDiscoveryReviews(placeID: place.id)
            if sessionManager.isAuthenticated {
                myReview = try await APIClient.fetchMyDiscoveryReview(placeID: place.id)
                if let myReview {
                    reviewPage = reviewPage.map {
                        let containsMine = $0.items.contains(where: { $0.id == myReview.id })
                        let items = $0.items.map { $0.id == myReview.id ? myReview : $0 }
                        return APIClient.DiscoveryReviewPage(
                            averageRating: $0.averageRating,
                            reviewCount: $0.reviewCount,
                            items: containsMine ? items : [myReview] + items,
                            myReview: myReview
                        )
                    }
                }
            } else {
                myReview = nil
            }
        } catch {
            reviewLoadError = "swiss.discovery.reviews.load_error".localized
        }
    }

    private func report(_ review: APIClient.DiscoveryReview) {
        guard sessionManager.isAuthenticated else {
            showAuth = true
            return
        }
        Task {
            do {
                try await APIClient.reportDiscoveryReview(reviewID: review.id, reason: "other")
                reviewNotice = "swiss.discovery.reviews.reported".localized
            } catch {
                reviewNotice = error.localizedDescription
            }
        }
    }

    private func detailMetric(icon: String, value: String) -> some View {
        HStack(spacing: 9) {
            JourneyCategoryIcon(
                symbol: icon,
                swatch: icon == "sun.max.fill" ? JourneyCategoryPalette.sand : JourneyCategoryPalette.teal,
                size: 30
            )
            Text(value)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(JourneyVisual.primaryText)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(JourneyVisual.softBorder, lineWidth: 1)
        )
    }

    private func openInMaps() {
        let mapItem = MKMapItem(
            location: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude),
            address: nil
        )
        mapItem.name = place.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit
        ])
    }

    private func toggleVisited() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isVisited {
            visitedPlaceIDs.remove(place.id)
        } else {
            visitedPlaceIDs.insert(place.id)
        }
        SwissDiscoveryProgressStore.saveVisited(visitedPlaceIDs)
    }
}

private struct SwissDiscoveryReviewEditor: View {
    @Environment(\.dismiss) private var dismiss

    let place: SwissDiscoveryPlace
    let existingReview: APIClient.DiscoveryReview?
    let onChanged: () -> Void

    @State private var rating: Int
    @State private var comment: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    init(place: SwissDiscoveryPlace, existingReview: APIClient.DiscoveryReview?, onChanged: @escaping () -> Void) {
        self.place = place
        self.existingReview = existingReview
        self.onChanged = onChanged
        _rating = State(initialValue: existingReview?.rating ?? 0)
        _comment = State(initialValue: existingReview?.comment ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.pageBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(spacing: 13) {
                            Image(place.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 74, height: 74)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.title)
                                    .font(.system(size: 20, weight: .bold, design: .default))
                                    .foregroundStyle(JourneyVisual.primaryText)
                                Text(place.region)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(JourneyVisual.secondaryText)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("swiss.discovery.reviews.rating".localized)
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundStyle(JourneyVisual.primaryText)
                            HStack(spacing: 11) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        rating = value
                                    } label: {
                                        Image(systemName: value <= rating ? "star.fill" : "star")
                                            .font(.system(size: 31, weight: .bold))
                                            .foregroundStyle(value <= rating ? JourneyVisual.lime : JourneyVisual.softBorder)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(value)")
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("swiss.discovery.reviews.comment".localized)
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundStyle(JourneyVisual.primaryText)
                            TextEditor(text: $comment)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(JourneyVisual.primaryText)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .frame(minHeight: 150)
                                .background(Theme.Colors.card)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(JourneyVisual.softBorder, lineWidth: 1))
                                .onChange(of: comment) { _, value in
                                    if value.count > 1000 { comment = String(value.prefix(1000)) }
                                }
                            Text("\(comment.count)/1000")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(JourneyVisual.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                        }

                        Button { submit() } label: {
                            HStack {
                                if isSubmitting { ProgressView().tint(.black) }
                                Text(existingReview == nil ? "swiss.discovery.reviews.publish".localized : "swiss.discovery.reviews.update".localized)
                            }
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(JourneyVisual.lime)
                            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmitting)

                        if existingReview != nil {
                            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                                Text("swiss.discovery.reviews.delete".localized)
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .disabled(isSubmitting)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existingReview == nil ? "swiss.discovery.reviews.write".localized : "swiss.discovery.reviews.edit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("swiss.discovery.reviews.cancel".localized) { dismiss() }
                }
            }
            .alert("swiss.discovery.reviews.delete_confirm.title".localized, isPresented: $showDeleteConfirmation) {
                Button("swiss.discovery.reviews.delete_confirm.action".localized, role: .destructive) { deleteReview() }
                Button("swiss.discovery.reviews.cancel".localized, role: .cancel) {}
            } message: {
                Text("swiss.discovery.reviews.delete_confirm.body".localized)
            }
        }
    }

    private func submit() {
        let normalized = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...5).contains(rating), normalized.count >= 3 else {
            errorMessage = "swiss.discovery.reviews.validation".localized
            return
        }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await APIClient.upsertDiscoveryReview(placeID: place.id, rating: rating, comment: normalized)
                onChanged()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }

    private func deleteReview() {
        isSubmitting = true
        Task {
            do {
                try await APIClient.deleteDiscoveryReview(placeID: place.id)
                onChanged()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

private struct SwissDiscoveryHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.ultraThinMaterial, in: Circle())
            .background(Color.black.opacity(configuration.isPressed ? 0.4 : 0.22), in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}
