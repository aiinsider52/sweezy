import MapKit
import SwiftUI
import UIKit

struct JourneyMapView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.openURL) private var openURL

    private static let defaultCenter = CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417)
    private static let minCameraDistance: CLLocationDistance = 700
    private static let maxCameraDistance: CLLocationDistance = 520_000
    private static let defaultCameraDistance: CLLocationDistance = 6_800
    private static let defaultHeading: CLLocationDirection = 18
    private static let defaultPitch: CGFloat = 58

    @State private var cameraDistance: CLLocationDistance = Self.defaultCameraDistance
    @State private var cameraCenter: CLLocationCoordinate2D = Self.defaultCenter
    @State private var cameraHeading: CLLocationDirection = Self.defaultHeading
    @State private var cameraPitch: CGFloat = Self.defaultPitch
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: Self.defaultCenter,
            distance: Self.defaultCameraDistance,
            heading: Self.defaultHeading,
            pitch: Self.defaultPitch
        )
    )
    @State private var selectedType: PlaceType?
    @State private var selectedPlace: Place?
    @State private var selectedDiscoveryPlace: SwissDiscoveryPlace?
    @State private var presentedDiscoveryPlace: SwissDiscoveryPlace?
    @State private var discoverySavedPlaceIDs = Set<String>()
    @State private var showsDiscoveryOnly = false
    @State private var searchText = ""
    @State private var activeRoute: MKRoute?
    @State private var isCalculatingRoute = false
    @State private var showsPlaceList = false
    @State private var showsNearbyRail = true

    private let filters: [(PlaceType?, String, String)] = [
        (nil, "common.all".localized, "square.grid.2x2"),
        (.government, "map.type.government".localized, "building.columns"),
        (.healthcare, "map.type.healthcare".localized, "cross.case"),
        (.education, "map.type.education".localized, "graduationcap"),
        (.employment, "map.type.employment".localized, "briefcase"),
        (.community, "map.type.community".localized, "person.2")
    ]

    var body: some View {
        ZStack {
            mapLayer
            mapReadabilityGradient

            VStack(spacing: 10) {
                topControls
                filterBar
                Spacer(minLength: 16)
                    .allowsHitTesting(false)
                if showsNearbyRail {
                    nearbyPlacesRail
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    collapsedNearbyRailChip
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: showsNearbyRail)
        }
        .overlay(alignment: .trailing) {
            zoomRail
                .padding(.trailing, 14)
                .padding(.bottom, showsNearbyRail ? 168 : 58)
        }
        .task {
            if appContainer.contentService.places.isEmpty {
                await appContainer.contentService.refreshContent()
            }
            if appContainer.locationService.isLocationEnabled {
                appContainer.locationService.startLocationUpdates()
            }
            applyPendingMapFocus()
            discoverySavedPlaceIDs = SwissDiscoveryProgressStore.savedPlaceIDs()
            selectFirstVisiblePlace()
        }
        .onAppear {
            applyPendingMapFocus()
            applyPendingDeepLinkFilter()
        }
        .onChange(of: appContainer.locationService.authorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                appContainer.locationService.startLocationUpdates()
            }
        }
        .onChange(of: selectedPlace?.id) { _, _ in
            guard let selectedPlace else {
                activeRoute = nil
                return
            }
            Task { await calculateRoute(to: selectedPlace) }
        }
        .onChange(of: searchText) { _, _ in
            keepSelectionVisible()
            keepDiscoverySelectionVisible()
        }
        .sheet(isPresented: $showsPlaceList) {
            placeListSheet
        }
        .fullScreenCover(item: $presentedDiscoveryPlace) { place in
            NavigationStack {
                SwissDiscoveryDetailView(
                    place: place,
                    isSaved: discoverySavedPlaceIDs.contains(place.id),
                    toggleSaved: { toggleDiscoverySaved(place) }
                )
            }
        }
        .accessibilityIdentifier("map.screen")
    }

    private func applyPendingDeepLinkFilter() {
        guard let type = MapDeepLinkRouter.pendingFilter else { return }
        MapDeepLinkRouter.pendingFilter = nil
        selectedType = type
        showsDiscoveryOnly = false
        selectFirstVisiblePlace()
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
            if let activeRoute {
                MapPolyline(activeRoute.polyline)
                    .stroke(
                        JourneyVisual.lime,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
            }

            UserAnnotation()

            if !showsDiscoveryOnly {
                ForEach(displayedPlaces.prefix(24)) { place in
                    Annotation(place.name, coordinate: place.coordinate.clLocationCoordinate) {
                        Button {
                            focus(on: place)
                        } label: {
                            JourneyMapPin(
                                icon: icon(for: place.type),
                                isSelected: selectedPlace?.id == place.id
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(place.name)
                    }
                }
            }

            if selectedType == nil {
                ForEach(displayedDiscoveryPlaces) { place in
                    Annotation(place.title, coordinate: place.coordinate) {
                        Button {
                            focus(on: place)
                        } label: {
                            JourneyMapPin(
                                icon: "sparkles",
                                isSelected: selectedDiscoveryPlace?.id == place.id
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(place.title), \(place.region)")
                        .accessibilityIdentifier("journey.map.discovery.pin.\(place.id)")
                    }
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls {
            MapScaleView()
                .mapControlVisibility(.visible)
        }
        .onMapCameraChange(frequency: .continuous) { context in
            cameraCenter = context.camera.centerCoordinate
            cameraDistance = context.camera.distance
            cameraHeading = context.camera.heading
            cameraPitch = context.camera.pitch
        }
        .ignoresSafeArea()
    }

    private var zoomRail: some View {
        VStack(spacing: 0) {
            Button {
                adjustZoom(factor: 0.62)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("journey.map.zoom_in".localized)

            zoomGradation
                .frame(width: 40, height: 92)
                .padding(.vertical, 4)

            Button {
                adjustZoom(factor: 1.55)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("journey.map.zoom_out".localized)
        }
        .background(.ultraThinMaterial.opacity(0.88))
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
    }

    private var zoomGradation: some View {
        GeometryReader { geometry in
            let trackWidth: CGFloat = 3
            let thumbHeight: CGFloat = 14
            let progress = zoomProgress
            let travel = max(geometry.size.height - thumbHeight, 1)
            let thumbY = (1 - progress) * travel

            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: trackWidth)

                VStack(spacing: geometry.size.height / 5.2) {
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 10, height: 1.5)
                    }
                }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [JourneyVisual.lime, JourneyVisual.lime.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: trackWidth, height: max(progress * geometry.size.height, 6))
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Capsule()
                    .fill(JourneyVisual.lime)
                    .frame(width: 12, height: thumbHeight)
                    .shadow(color: JourneyVisual.lime.opacity(0.55), radius: 6, y: 0)
                    .offset(y: thumbY - travel / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private var zoomProgress: CGFloat {
        let clamped = min(max(cameraDistance, Self.minCameraDistance), Self.maxCameraDistance)
        let logMin = log(Self.minCameraDistance)
        let logMax = log(Self.maxCameraDistance)
        let logCur = log(clamped)
        return CGFloat((logMax - logCur) / (logMax - logMin))
    }

    private var mapReadabilityGradient: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.42), location: 0),
                .init(color: .clear, location: 0.27),
                .init(color: .clear, location: 0.58),
                .init(color: .black.opacity(0.52), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topControls: some View {
        HStack(spacing: 10) {
            JourneySearchField(text: $searchText, prompt: "journey.map.search_placeholder".localized)

            Button {
                showsPlaceList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial.opacity(0.82))
                    .background(Color.black.opacity(0.22))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.34), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("journey.map.show_list".localized)

            Button {
                activateUserLocation()
            } label: {
                Image(systemName: appContainer.locationService.isLocationEnabled ? "location.fill" : "location")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(appContainer.locationService.isLocationEnabled ? .black : .white)
                    .frame(width: 48, height: 48)
                    .background(appContainer.locationService.isLocationEnabled ? JourneyVisual.lime : Color.black.opacity(0.48))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.34), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("map.center_on_me.label".localized)
            .accessibilityHint("journey.map.location_hint".localized)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                JourneyFilterChip(
                    title: "swiss.discovery.map_filter".localized,
                    icon: "sparkles",
                    isSelected: showsDiscoveryOnly
                ) {
                    applyDiscoveryFilter()
                }
                .accessibilityIdentifier("journey.map.discovery.filter")

                ForEach(filters, id: \.1) { type, title, icon in
                    JourneyFilterChip(
                        title: title,
                        icon: icon,
                        isSelected: !showsDiscoveryOnly && selectedType == type
                    ) {
                        applyFilter(type)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 1, for: .scrollContent)
    }

    private var nearbyPlacesRail: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(railTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("\(railCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())

                Spacer(minLength: 8)

                Button("journey.map.all_places".localized) {
                    showsPlaceList = true
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.78))

                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        showsNearbyRail = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.86))
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.42))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("journey.map.hide_card".localized)
            }
            .shadow(color: .black.opacity(0.65), radius: 6, y: 2)

            if railCount == 0 {
                emptyPlacesCard
            } else if showsDiscoveryOnly || selectedDiscoveryPlace != nil {
                discoveryCarousel
            } else {
                placeCarousel
            }
        }
    }

    private var collapsedNearbyRailChip: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    showsNearbyRail = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.bottomthird.inset.filled")
                        .font(.system(size: 13, weight: .bold))
                    Text("journey.map.show_card".localized)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("\(railCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(.ultraThinMaterial.opacity(0.84))
                .background(Color.black.opacity(0.42))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("journey.map.show_card".localized)

            Spacer(minLength: 0)
        }
    }

    private var placeCarousel: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(displayedPlaces.prefix(12)) { place in
                            placeCard(place)
                                .frame(width: geometry.size.width)
                                .id(place.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .onChange(of: selectedPlace?.id) { _, placeID in
                    guard let placeID else { return }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                        proxy.scrollTo(placeID, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 138)
    }

    private var discoveryCarousel: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(displayedDiscoveryPlaces) { place in
                            discoveryPlaceCard(place)
                                .frame(width: geometry.size.width)
                                .id(place.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .onChange(of: selectedDiscoveryPlace?.id) { _, placeID in
                    guard let placeID else { return }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                        proxy.scrollTo(placeID, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 138)
    }

    private var emptyPlacesCard: some View {
        JourneyGlassPanel(cornerRadius: 24) {
            HStack(spacing: 13) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(JourneyVisual.lime)
                VStack(alignment: .leading, spacing: 3) {
                    Text("journey.map.nothing_found".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("journey.map.change_search_or_category".localized)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.62))
                }
                Spacer()
            }
            .padding(18)
        }
        .frame(height: 96)
    }

    private func placeCard(_ place: Place) -> some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image(imageName(for: place))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 138)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Label(typeTitle(for: place.type), systemImage: icon(for: place.type))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
                    .padding(9)
            }
            .frame(width: 104, height: 138)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(place.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        appContainer.savedItems.togglePlace(place.id)
                    } label: {
                        Image(systemName: appContainer.savedItems.isPlaceSaved(place.id) ? "heart.fill" : "heart")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(appContainer.savedItems.isPlaceSaved(place.id) ? JourneyVisual.lime : .white.opacity(0.72))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("journey.map.save_place".localized)
                }

                Label(locationLine(for: place), systemImage: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Circle()
                        .fill(place.isOpen() ? JourneyVisual.lime : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(todayHours(for: place))
                        .lineLimit(1)
                    if let distance = distanceText(to: place) {
                        Text("·")
                        Text(distance)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.68))

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button {
                        openDirections(to: place)
                    } label: {
                        HStack(spacing: 7) {
                            if isCalculatingRoute && selectedPlace?.id == place.id {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.black)
                            } else {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            }
                            Text("map.directions".localized)
                                .lineLimit(1)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if let bookingURL = bookingURL(for: place) {
                        Button {
                            openURL(bookingURL)
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("journey.map.book_appointment".localized)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(height: 138)
        .background(.ultraThinMaterial.opacity(0.84))
        .background(Color(red: 0.035, green: 0.075, blue: 0.05).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.44), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.42), radius: 18, y: 8)
        .onTapGesture {
            focus(on: place)
        }
    }

    private func discoveryPlaceCard(_ place: SwissDiscoveryPlace) -> some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image(place.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 138)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Label("swiss.discovery.setting.\(place.settings.first?.rawValue ?? "all")".localized, systemImage: "sparkles")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
                    .padding(9)
            }
            .frame(width: 104, height: 138)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 7) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(place.region)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 2)

                    Button { toggleDiscoverySaved(place) } label: {
                        Image(systemName: discoverySavedPlaceIDs.contains(place.id) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(discoverySavedPlaceIDs.contains(place.id) ? JourneyVisual.lime : .white.opacity(0.74))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text(place.summary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.66))
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button {
                        presentedDiscoveryPlace = place
                    } label: {
                        Label("swiss.discovery.open_place".localized, systemImage: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(JourneyVisual.lime)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button { openDirections(to: place) } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(height: 138)
        .background(.ultraThinMaterial.opacity(0.84))
        .background(Color(red: 0.035, green: 0.075, blue: 0.05).opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.42), radius: 18, y: 8)
        .onTapGesture { focus(on: place) }
        .accessibilityIdentifier("journey.map.discovery.card.\(place.id)")
    }

    private var placeListSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.025, green: 0.045, blue: 0.032)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 11) {
                        if selectedType == nil {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("swiss.discovery.map_title".localized)
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("swiss.discovery.map_subtitle".localized)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.56))
                                }
                                Spacer()
                                Text("\(displayedDiscoveryPlaces.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(JourneyVisual.lime)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 2)
                            .padding(.bottom, 3)

                            ForEach(displayedDiscoveryPlaces) { place in
                                discoveryPlaceListRow(place)
                            }
                        }

                        if !showsDiscoveryOnly {
                            if selectedType == nil, !displayedPlaces.isEmpty {
                                Text("journey.map.places_nearby".localized)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.top, 10)
                            }
                            ForEach(displayedPlaces) { place in
                                placeListRow(place)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("journey.map.places_nearby".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) {
                        showsPlaceList = false
                    }
                    .foregroundColor(JourneyVisual.lime)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private func placeListRow(_ place: Place) -> some View {
        Button {
            focus(on: place)
            showsPlaceList = false
        } label: {
            HStack(spacing: 13) {
                Image(imageName(for: place))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 86, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: icon(for: place.type))
                        Text(typeTitle(for: place.type))
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(JourneyVisual.lime)

                    Text(place.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(place.isOpen() ? JourneyVisual.lime : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(locationLine(for: place))
                            .lineLimit(1)
                        if let distance = distanceText(to: place) {
                            Text("· \(distance)")
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.42))
            }
            .padding(10)
            .background(Color.white.opacity(0.065))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func discoveryPlaceListRow(_ place: SwissDiscoveryPlace) -> some View {
        Button {
            focus(on: place)
            showsPlaceList = false
        } label: {
            ZStack(alignment: .bottomLeading) {
                Image(place.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 190)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.9)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(place.region.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(JourneyVisual.lime)
                    Text(place.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(place.summary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                    Label(place.duration, systemImage: "clock")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(15)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(JourneyVisual.lime)
                    .clipShape(Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(14)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var displayedPlaces: [Place] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = appContainer.contentService.places.filter { place in
            let matchesType = selectedType == nil || place.type == selectedType
            let matchesSearch = query.isEmpty
                || place.name.localizedCaseInsensitiveContains(query)
                || place.formattedAddress.localizedCaseInsensitiveContains(query)
            return matchesType && matchesSearch
        }

        guard let location = appContainer.locationService.currentLocation else {
            return matches
        }
        return matches.sorted { $0.distance(from: location) < $1.distance(from: location) }
    }

    private var displayedDiscoveryPlaces: [SwissDiscoveryPlace] {
        guard selectedType == nil else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return SwissDiscoveryCatalog.places.filter { place in
            query.isEmpty
                || place.title.localizedCaseInsensitiveContains(query)
                || place.region.localizedCaseInsensitiveContains(query)
                || place.summary.localizedCaseInsensitiveContains(query)
        }
    }

    private var railTitle: String {
        if showsDiscoveryOnly || selectedDiscoveryPlace != nil {
            return "swiss.discovery.map_title".localized
        }
        return selectedType == nil ? "journey.map.near_you".localized : filterTitle
    }

    private var railCount: Int {
        if showsDiscoveryOnly || selectedDiscoveryPlace != nil {
            return displayedDiscoveryPlaces.count
        }
        return displayedPlaces.count
    }

    private var filterTitle: String {
        filters.first(where: { $0.0 == selectedType })?.1 ?? "journey.map.near_you".localized
    }

    private func applyFilter(_ type: PlaceType?) {
        withAnimation(.easeInOut(duration: 0.22)) {
            showsDiscoveryOnly = false
            selectedDiscoveryPlace = nil
            selectedType = type
            activeRoute = nil
        }
        selectFirstVisiblePlace()
    }

    private func applyDiscoveryFilter() {
        withAnimation(.easeInOut(duration: 0.24)) {
            showsDiscoveryOnly = true
            selectedType = nil
            selectedPlace = nil
            activeRoute = nil
            selectedDiscoveryPlace = displayedDiscoveryPlaces.first
        }
        moveCamera(
            to: CLLocationCoordinate2D(latitude: 46.82, longitude: 8.23),
            distance: 430_000,
            heading: 8,
            pitch: 43,
            duration: 0.42
        )
    }

    private func selectFirstVisiblePlace() {
        selectedPlace = displayedPlaces.first
    }

    private func keepSelectionVisible() {
        guard let selectedPlace, displayedPlaces.contains(where: { $0.id == selectedPlace.id }) else {
            selectFirstVisiblePlace()
            return
        }
    }

    private func keepDiscoverySelectionVisible() {
        guard let selectedDiscoveryPlace else { return }
        guard displayedDiscoveryPlaces.contains(where: { $0.id == selectedDiscoveryPlace.id }) else {
            self.selectedDiscoveryPlace = displayedDiscoveryPlaces.first
            return
        }
    }

    private func focus(on place: Place) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            showsNearbyRail = true
        }
        selectedDiscoveryPlace = nil
        selectedPlace = place
        moveCamera(to: place.coordinate.clLocationCoordinate, distance: 3_600)
    }

    private func focus(on place: SwissDiscoveryPlace) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            showsNearbyRail = true
        }
        selectedPlace = nil
        selectedDiscoveryPlace = place
        activeRoute = nil
        moveCamera(to: place.coordinate, distance: 12_000, heading: 14, pitch: 52)
    }

    private func toggleDiscoverySaved(_ place: SwissDiscoveryPlace) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if discoverySavedPlaceIDs.contains(place.id) {
            discoverySavedPlaceIDs.remove(place.id)
        } else {
            discoverySavedPlaceIDs.insert(place.id)
        }
        SwissDiscoveryProgressStore.save(discoverySavedPlaceIDs)
    }

    private func applyPendingMapFocus() {
        guard let target = MapFocusRouter.pending else { return }
        MapFocusRouter.pending = nil
        moveCamera(
            to: CLLocationCoordinate2D(latitude: target.latitude, longitude: target.longitude),
            distance: min(max(2_400, target.spanDelta * 55_000), Self.maxCameraDistance),
            duration: 0.35
        )
    }

    private func activateUserLocation() {
        switch appContainer.locationService.authorizationStatus {
        case .notDetermined:
            appContainer.locationService.requestLocationPermission()
        case .denied, .restricted:
            appContainer.locationService.openAppSettings()
        case .authorizedWhenInUse, .authorizedAlways:
            appContainer.locationService.startLocationUpdates()
            guard let location = appContainer.locationService.currentLocation else { return }
            moveCamera(to: location.coordinate, distance: 3_600)
        @unknown default:
            break
        }
    }

    private func adjustZoom(factor: Double) {
        let next = min(max(cameraDistance * factor, Self.minCameraDistance), Self.maxCameraDistance)
        moveCamera(to: cameraCenter, distance: next, heading: cameraHeading, pitch: cameraPitch, duration: 0.22)
    }

    private func moveCamera(
        to coordinate: CLLocationCoordinate2D,
        distance: CLLocationDistance,
        heading: CLLocationDirection? = nil,
        pitch: CGFloat? = nil,
        duration: Double = 0.3
    ) {
        let resolvedHeading = heading ?? Self.defaultHeading
        let resolvedPitch = pitch ?? Self.defaultPitch
        let resolvedDistance = min(max(distance, Self.minCameraDistance), Self.maxCameraDistance)
        cameraCenter = coordinate
        cameraDistance = resolvedDistance
        cameraHeading = resolvedHeading
        cameraPitch = resolvedPitch
        withAnimation(.easeInOut(duration: duration)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: resolvedDistance,
                    heading: resolvedHeading,
                    pitch: resolvedPitch
                )
            )
        }
    }

    private func icon(for type: PlaceType) -> String {
        switch type {
        case .government: return "building.columns.fill"
        case .healthcare, .emergency: return "cross.fill"
        case .education: return "graduationcap.fill"
        case .housing: return "house.fill"
        case .employment: return "briefcase.fill"
        case .community, .social: return "person.2.fill"
        case .legal: return "checkmark.seal.fill"
        case .transport: return "tram.fill"
        case .banking: return "creditcard.fill"
        case .shopping: return "cart.fill"
        }
    }

    private func typeTitle(for type: PlaceType) -> String {
        switch type {
        case .government: return "map.type.government".localized
        case .healthcare: return "map.type.healthcare".localized
        case .education: return "map.type.education".localized
        case .employment: return "map.type.employment".localized
        case .community, .social: return "map.type.community".localized
        case .housing: return "map.type.housing".localized
        case .legal: return "journey.map.type.legal".localized
        case .transport: return "map.type.transport".localized
        case .banking: return "map.type.banking".localized
        case .shopping: return "map.type.shopping".localized
        case .emergency: return "map.type.emergency".localized
        }
    }

    private func openDirections(to place: Place) {
        let coordinate = place.coordinate.clLocationCoordinate
        let encodedName = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.name
        guard let url = URL(
            string: "http://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)&q=\(encodedName)"
        ) else { return }
        openURL(url)
    }

    private func openDirections(to place: SwissDiscoveryPlace) {
        let encodedName = place.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.title
        guard let url = URL(
            string: "http://maps.apple.com/?daddr=\(place.latitude),\(place.longitude)&q=\(encodedName)"
        ) else { return }
        openURL(url)
    }

    private func calculateRoute(to place: Place) async {
        activeRoute = nil
        guard let userLocation = appContainer.locationService.currentLocation else { return }

        let destination = CLLocation(
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude
        )
        guard userLocation.distance(from: destination) <= 100_000 else { return }

        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        let request = MKDirections.Request()
        request.source = MKMapItem(location: userLocation, address: nil)
        request.destination = MKMapItem(location: destination, address: nil)
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()
            guard selectedPlace?.id == place.id else { return }
            activeRoute = response.routes.first
        } catch {
            activeRoute = nil
            AppLogger.location("Directions failed: \(error)", isError: true)
        }
    }

    private func distanceText(to place: Place) -> String? {
        guard let meters = appContainer.locationService.distance(to: place.coordinate.clLocationCoordinate),
              meters <= 300_000 else {
            return nil
        }
        if meters < 1_000 { return "journey.map.distance_meters".localized(with: Int(meters.rounded())) }
        return "journey.map.distance_km".localized(with: meters / 1_000)
    }

    private func locationLine(for place: Place) -> String {
        let city = place.address.city.trimmingCharacters(in: .whitespacesAndNewlines)
        return city.isEmpty ? place.canton.localizedName : "\(city) · \(place.canton.rawValue)"
    }

    private func todayHours(for place: Place) -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        guard let hours = place.openingHours.first(where: { $0.weekday == weekday }) else {
            return "journey.map.hours_tbd".localized
        }
        if hours.isClosed { return "journey.map.closed_today".localized }
        let prefix = place.isOpen() ? "map.open".localized : "journey.map.today".localized
        return "\(prefix) · \(hours.openTime.formatted)–\(hours.closeTime.formatted)"
    }

    private func bookingURL(for place: Place) -> URL? {
        if let website = place.website, !website.isEmpty {
            if let url = URL(string: website), url.scheme != nil { return url }
            return URL(string: "https://\(website)")
        }
        if let phone = place.phoneNumber {
            return URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })")
        }
        if let email = place.email { return URL(string: "mailto:\(email)") }
        return nil
    }

    private func imageName(for place: Place) -> String {
        switch place.type {
        case .government, .legal, .banking: return "journey-place-government"
        case .healthcare, .emergency: return "journey-place-healthcare"
        case .education: return "journey-place-education"
        case .employment: return "journey-place-employment"
        case .community, .social, .shopping: return "journey-place-community"
        case .housing, .transport: return "journey-place-housing"
        }
    }
}

private struct JourneyMapPin: View {
    let icon: String
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? JourneyVisual.lime : Color.black.opacity(0.84))
                .frame(width: isSelected ? 42 : 34, height: isSelected ? 42 : 34)
                .overlay(Circle().stroke(Color.white.opacity(0.76), lineWidth: 1.5))
                .shadow(
                    color: isSelected ? JourneyVisual.lime.opacity(0.5) : .black.opacity(0.4),
                    radius: 10,
                    y: 4
                )
            Image(systemName: icon)
                .font(.system(size: isSelected ? 15 : 12, weight: .bold))
                .foregroundColor(isSelected ? .black : .white)
        }
    }
}
