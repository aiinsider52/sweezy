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
    @State private var selectedPlace: SwissDiscoveryPlace?
    @State private var savedPlaceIDs = Set<String>()
    @State private var showsSavedOnly = false
    @State private var presentation: SwissDiscoveryPresentation = .list
    @State private var ratingSummaries: [String: APIClient.DiscoveryRatingSummary] = [:]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var filteredPlaces: [SwissDiscoveryPlace] {
        SwissDiscoveryCatalog.places.filter { place in
            place.matches(query: query, filter: selectedFilter)
                && (!showsSavedOnly || savedPlaceIDs.contains(place.id))
        }
    }

    var body: some View {
        ZStack {
            JourneyPhotoBackground(
                imageName: "swiss-discovery-aletsch",
                blurRadius: 10,
                darkness: 0.7
            )

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    searchAndFilters

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
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(Array(filteredPlaces.dropFirst().enumerated()), id: \.element.id) { index, place in
                                    SwissDiscoveryGridCard(
                                        place: place,
                                        rating: ratingSummaries[place.id],
                                        height: index.isMultiple(of: 3) ? 278 : 238,
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
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedPlace) { place in
            SwissDiscoveryDetailView(
                place: place,
                isSaved: savedPlaceIDs.contains(place.id),
                toggleSaved: { toggleSaved(place) }
            )
        }
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
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("swiss.discovery.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
                }
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
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(showsSavedOnly ? .black : .white)
                    .padding(.horizontal, 15)
                    .frame(height: 46)
                    .background(showsSavedOnly ? JourneyVisual.lime : Color.black.opacity(0.5))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(showsSavedOnly ? 0 : 0.28), lineWidth: 1))
                }
                .accessibilityLabel("swiss.discovery.saved".localized)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("swiss.discovery.eyebrow".localized.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(JourneyVisual.lime)

                Text("swiss.discovery.title".localized)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(-3)

                Text("swiss.discovery.subtitle".localized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var searchAndFilters: some View {
        VStack(spacing: 12) {
            JourneySearchField(text: $query, prompt: "swiss.discovery.search".localized)

            HStack(spacing: 8) {
                ForEach(SwissDiscoveryPresentation.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            presentation = option
                        }
                    } label: {
                        Label(option.title, systemImage: option.icon)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(presentation == option ? .black : .white.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(presentation == option ? JourneyVisual.lime : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(presentation == option ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.44))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SwissDiscoveryFilter.allCases) { filter in
                        JourneyFilterChip(
                            title: filter.title,
                            icon: filter.icon,
                            isSelected: selectedFilter == filter
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

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text("swiss.discovery.places_count".localized(with: count))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.54))
        }
    }

    private var emptyState: some View {
        JourneyGlassPanel(cornerRadius: 26) {
            VStack(spacing: 13) {
                Image(systemName: showsSavedOnly ? "bookmark.slash" : "binoculars.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(JourneyVisual.lime)
                Text("swiss.discovery.empty.title".localized)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("swiss.discovery.empty.subtitle".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                Button("swiss.discovery.empty.reset".localized) {
                    query = ""
                    selectedFilter = .all
                    showsSavedOnly = false
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
                .foregroundStyle(JourneyVisual.lime)
            Text("swiss.discovery.source_footer".localized(with: SwissDiscoveryCatalog.verifiedAt))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private func toggleSaved(_ place: SwissDiscoveryPlace) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if savedPlaceIDs.contains(place.id) {
            savedPlaceIDs.remove(place.id)
        } else {
            savedPlaceIDs.insert(place.id)
        }
        SwissDiscoveryProgressStore.save(savedPlaceIDs)
    }
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
                .font(.system(size: 22, weight: .bold, design: .rounded))
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
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
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
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text(selectedPlace.region)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.62))
                                if let rating = ratings[selectedPlace.id], rating.reviewCount > 0 {
                                    Label(String(format: "%.1f", rating.averageRating), systemImage: "star.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(JourneyVisual.lime)
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
    }

    private var featuredVisual: some View {
        ZStack(alignment: .bottomLeading) {
                Image(place.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 322)
                    .clipped()

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
                        .font(.system(size: 29, weight: .bold, design: .rounded))
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

private struct SwissDiscoveryGridCard: View {
    let place: SwissDiscoveryPlace
    let rating: APIClient.DiscoveryRatingSummary?
    let height: CGFloat
    let isSaved: Bool
    let action: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                gridVisual
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(place.title), \(place.region)")
            .accessibilityIdentifier("swiss.discovery.place.\(place.id)")

            SwissDiscoverySaveButton(isSaved: isSaved, action: toggleSaved, compact: true)
                .padding(10)
        }
    }

    private var gridVisual: some View {
        ZStack(alignment: .bottomLeading) {
                Image(place.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.88)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(place.region.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(JourneyVisual.lime)
                        .lineLimit(1)
                    Text(place.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Label(place.duration, systemImage: "clock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                    if let rating, rating.reviewCount > 0 {
                        Label(String(format: "%.1f · %d", rating.averageRating, rating.reviewCount), systemImage: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(JourneyVisual.lime)
                    }
                }
                .padding(14)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
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

private struct SwissDiscoveryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
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

    private var isVisited: Bool { visitedPlaceIDs.contains(place.id) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

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
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("swiss.discovery.detail.\(place.id)")
    }

    private var stickyHeader: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 46, height: 46)
            }
            .accessibilityLabel("common.back".localized)

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
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.9), .black.opacity(0.54), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .buttonStyle(SwissDiscoveryHeaderButtonStyle())
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(place.imageNames.enumerated()), id: \.offset) { index, imageName in
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 430)
                        .clipped()
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
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(place.summary)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)

            HStack(spacing: 5) {
                ForEach(place.imageNames.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedPhotoIndex ? JourneyVisual.lime : Color.white.opacity(0.46))
                        .frame(width: index == selectedPhotoIndex ? 24 : 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 22)
            .padding(.top, 108)
        }
        .frame(height: 430)
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
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(place.details)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("swiss.discovery.detail.description")
            }

            JourneyGlassPanel(cornerRadius: 23) {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: "lightbulb.max.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(JourneyVisual.lime)
                        .frame(width: 40, height: 40)
                        .background(JourneyVisual.lime.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Text("swiss.discovery.detail.tip".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(place.tip)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineSpacing(3)
                    }
                }
                .padding(17)
            }

            JourneyGlassPanel(cornerRadius: 23) {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(JourneyVisual.lime)
                        .frame(width: 40, height: 40)
                        .background(JourneyVisual.lime.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Text("swiss.discovery.detail.route_format".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(place.route)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
                .padding(17)
            }

            Button(action: openInMaps) {
                HStack(spacing: 10) {
                    Image(systemName: "map.fill")
                    Text("swiss.discovery.detail.open_route".localized)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Link(destination: place.officialURL) {
                JourneyGlassPanel(cornerRadius: 23) {
                    HStack(spacing: 13) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(JourneyVisual.lime)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("swiss.discovery.detail.official_source".localized)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("swiss.discovery.detail.verified".localized(with: SwissDiscoveryCatalog.verifiedAt))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.56))
                        }

                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(JourneyVisual.lime)
                    }
                    .padding(17)
                }
            }
            .buttonStyle(.plain)

            Button(action: toggleVisited) {
                HStack(spacing: 10) {
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                    Text(isVisited ? "swiss.discovery.detail.visited".localized : "swiss.discovery.detail.mark_visited".localized)
                    Spacer()
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(isVisited ? JourneyVisual.lime : .white)
                .padding(.horizontal, 17)
                .frame(height: 52)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            reviewsSection

            Text("swiss.discovery.detail.illustration_note".localized)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 44)
        .background(Color.black)
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("swiss.discovery.gallery".localized)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("swiss.discovery.photos_count".localized(with: place.imageNames.count))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
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
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("swiss.discovery.reviews.count".localized(with: reviewPage?.reviewCount ?? 0))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if let reviewPage, reviewPage.reviewCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(JourneyVisual.lime)
                        Text(String(format: "%.1f", reviewPage.averageRating))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
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
                .font(.system(size: 15, weight: .bold, design: .rounded))
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
                        .foregroundStyle(JourneyVisual.lime)
                    Text(reviewNotice)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.76))
                    Spacer()
                    Button { self.reviewNotice = nil } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color.white.opacity(0.07))
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
                            .foregroundStyle(.white.opacity(0.66))
                        Spacer()
                        Button {
                            Task { await loadReviews() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(JourneyVisual.lime)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.08))
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
                    .foregroundStyle(.white.opacity(0.56))
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
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { value in
                                Image(systemName: value <= review.rating ? "star.fill" : "star")
                            }
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(JourneyVisual.lime)
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
            Image(systemName: icon)
                .foregroundStyle(JourneyVisual.lime)
            Text(value)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func openInMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
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
                Color.black.ignoresSafeArea()
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
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(place.region)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("swiss.discovery.reviews.rating".localized)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            HStack(spacing: 11) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        rating = value
                                    } label: {
                                        Image(systemName: value <= rating ? "star.fill" : "star")
                                            .font(.system(size: 31, weight: .bold))
                                            .foregroundStyle(value <= rating ? JourneyVisual.lime : .white.opacity(0.3))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(value)")
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("swiss.discovery.reviews.comment".localized)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            TextEditor(text: $comment)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .frame(minHeight: 150)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.17), lineWidth: 1))
                                .onChange(of: comment) { _, value in
                                    if value.count > 1000 { comment = String(value.prefix(1000)) }
                                }
                            Text("\(comment.count)/1000")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
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
                            .font(.system(size: 16, weight: .bold, design: .rounded))
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
        .preferredColorScheme(.dark)
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
            .background(Color.black.opacity(configuration.isPressed ? 0.72 : 0.5))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}
