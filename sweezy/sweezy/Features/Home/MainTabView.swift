//
//  MainTabView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI
import MapKit
import UserNotifications

struct MainTabView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var router = MainTabRouter()
    @State private var deepLinkedGuide: Guide?
    @State private var deepLinkedChecklist: Checklist?
    @State private var deepLinkedTemplate: DocumentTemplate?
    @State private var deepLinkedPlace: SwissDiscoveryPlace?
    @State private var deepLinkedNews: NewsItem?
    @State private var showCalculator = false
    @State private var showAppointments = false
    @State private var showCVBuilder = false
    @State private var showProfile = false
    @State private var showPrivacy = false
    @State private var showLanguage = false
    @State private var showWhatsNew = false
    @State private var showSettings = false
    
    var body: some View {
        Group {
            switch router.selectedTab {
            case 1:
                JourneyDirectoryView(
                    requestedSection: router.requestedDirectorySection,
                    routeID: router.requestedDirectoryRouteID
                )
                .featureOnboarding(.dovidnyk)
            case 2:
                JourneyMapView()
                    .featureOnboarding(.map)
            case 3:
                JourneyMarketplaceView()
            case 4:
                FriendNetworkView(showsDismissButton: false)
                    .environmentObject(appContainer)
                    .environmentObject(lockManager)
                    .environmentObject(sessionManager)
            default:
                JourneyHomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !router.isBottomBarHidden {
                JourneyBottomBar(selection: Binding(
                    get: { router.selectedTab },
                    set: { router.select(tab: $0) }
                ))
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .allowsHitTesting(false)
                    }
            }
        }
        .onAppear {
            AppLogger.ui("MainTabView appeared")
            #if DEBUG
            // Screenshot automation: pass "-screenshotTab N" as a launch argument
            if let idx = UserDefaults.standard.string(forKey: "screenshotTab").flatMap(Int.init) {
                router.select(tab: idx)
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { output in
            if let payload = output.object as? SwitchTabPayload {
                router.open(payload)
            } else if let index = output.object as? Int {
                router.select(tab: index)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .setJourneyBottomBarHidden)) { output in
            withAnimation(.easeInOut(duration: 0.2)) {
                router.setBottomBarHidden(output.object as? Bool ?? false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDeepLinkDestination)) { output in
            guard let link = output.object as? DeepLink else { return }
            router.open(link)
            Task { await resolve(link) }
        }
        .sheet(item: $deepLinkedGuide) { GuideDetailView(guide: $0).environmentObject(appContainer) }
        .sheet(item: $deepLinkedChecklist) { ChecklistDetailView(checklist: $0).environmentObject(appContainer) }
        .sheet(item: $deepLinkedTemplate) { TemplateDetailView(template: $0).environmentObject(appContainer) }
        .sheet(item: $deepLinkedPlace) {
            SwissDiscoveryDetailView(place: $0, isSaved: false, toggleSaved: {})
                .environmentObject(appContainer)
        }
        .sheet(item: $deepLinkedNews) { NewsDetailView(news: $0) }
        .sheet(isPresented: $showCalculator) { NavigationStack { BenefitsCalculatorView() }.environmentObject(appContainer) }
        .sheet(isPresented: $showAppointments) { NavigationStack { AppointmentsView() }.environmentObject(appContainer.appointmentRepository) }
        .fullScreenCover(isPresented: $showCVBuilder) { CVBuilderView().environmentObject(appContainer) }
        .sheet(isPresented: $showProfile) { ProfileEditView().environmentObject(appContainer) }
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
        .sheet(isPresented: $showLanguage) { LanguageSelectionSheet().environmentObject(appContainer) }
        .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appContainer)
                .environmentObject(themeManager)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
    }

    @MainActor
    private func resolve(_ link: DeepLink) async {
        if appContainer.contentService.guides.isEmpty || appContainer.contentService.checklists.isEmpty {
            await appContainer.contentService.refreshContent()
        }
        switch link {
        case .guide(let id):
            deepLinkedGuide = appContainer.contentService.guides.first { matches($0.id, id) }
        case .checklist(let id):
            deepLinkedChecklist = appContainer.contentService.checklists.first { matches($0.id, id) }
        case .template(let id):
            deepLinkedTemplate = appContainer.contentService.templates.first { matches($0.id, id) }
        case .place(let id):
            deepLinkedPlace = SwissDiscoveryCatalog.places.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
        case .map(let filter):
            if let filter, let type = PlaceType(rawValue: filter.lowercased()) {
                MapDeepLinkRouter.pendingFilter = type
            }
        case .calculator: showCalculator = true
        case .appointments: showAppointments = true
        case .news:
            deepLinkedNews = appContainer.contentService.latestNews(limit: 1, language: appContainer.currentLocale.language.languageCode?.identifier).first
        case .cvBuilder: showCVBuilder = true
        case .settings: showSettings = true
        case .profile: showProfile = true
        case .privacy: showPrivacy = true
        case .language: showLanguage = true
        case .whatsNew: showWhatsNew = true
        case .onboarding:
            appContainer.restartOnboarding()
        case .passwordReset, .chat:
            break
        }
        router.consumeDeepLink()
    }

    private func matches(_ uuid: UUID, _ raw: String) -> Bool {
        uuid.uuidString.caseInsensitiveCompare(raw) == .orderedSame
    }
}

enum DovidnykRouteSection: String {
    case guides
    case checklists
    case tools
}

struct SwitchTabPayload {
    let tab: Int
    let section: DovidnykRouteSection?
    let routeID: UUID
    
    init(tab: Int, section: DovidnykRouteSection? = nil, routeID: UUID = UUID()) {
        self.tab = tab
        self.section = section
        self.routeID = routeID
    }
}

// MARK: - Map focus routing (Home city cards → Map tab)

struct MapFocusTarget {
    let latitude: Double
    let longitude: Double
    let spanDelta: Double
}

/// Pending "center map on city" request. Set before switching to the Map tab;
/// `OptimizedMapView` consumes it on appear (survives lazy map loading).
enum MapFocusRouter {
    static var pending: MapFocusTarget?
}

enum MapDeepLinkRouter {
    static var pendingFilter: PlaceType?
}

// MARK: - Tab Icon
private struct NewYearTabIcon: View {
    let baseSystemName: String
    let isSelected: Bool
    
    private var iconColor: Color {
        isSelected ? Theme.Colors.primary : Theme.Colors.textTertiary
    }

    var body: some View {
        Image(systemName: baseSystemName)
            .font(.system(size: 21, weight: .semibold))
            .foregroundColor(iconColor)
            .shadow(color: isSelected ? Theme.Colors.primary.opacity(0.4) : Color.clear,
                    radius: 6, x: 0, y: 2)
    }
}

// MARK: - Simple Placeholder Tab
struct PlaceholderTab: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(color)
                Text(title)
                    .font(.title2.bold())
                Text("common.coming_soon".localized)
                    .foregroundColor(.secondary)
            }
            .navigationTitle(title)
        }
        .journeyScreen(.city, darkness: 0.72)
    }
}

// MARK: - Lazy Home Wrapper (loads HomeViewRedesigned after delay)
struct LazyHomeWrapper: View {
    @State private var showOriginal = false
    
    var body: some View {
        Group {
            if showOriginal {
                HomeViewRedesigned()
                    .onAppear {
                        AppLogger.ui("HomeViewRedesigned loaded")
                    }
            } else {
                // Show simplified version while loading
                HomeSimplifiedView()
            }
        }
        .onAppear {
            // Delay loading of heavy view
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showOriginal = true
            }
        }
    }
}

// MARK: - Lazy Guides Wrapper
struct LazyGuidesWrapper: View {
    @State private var showOriginal = false
    
    var body: some View {
        Group {
            if showOriginal {
                GuidesView()
                    .onAppear {
                        AppLogger.ui("GuidesView (original) loaded")
                    }
            } else {
                GuidesLiteView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showOriginal = true
            }
        }
    }
}

// MARK: - Lazy Checklists Wrapper
struct LazyChecklistsWrapper: View {
    @State private var showOriginal = false
    
    var body: some View {
        Group {
            if showOriginal {
                ChecklistsView()
                    .onAppear {
                        AppLogger.ui("ChecklistsView (original) loaded")
                    }
            } else {
                ChecklistsLiteView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showOriginal = true
            }
        }
    }
}

// MARK: - Lazy Settings Wrapper
struct LazySettingsWrapper: View {
    @State private var showOriginal = false
    
    var body: some View {
        Group {
            if showOriginal {
                SettingsView()
                    .onAppear {
                        AppLogger.ui("SettingsView (original) loaded")
                    }
            } else {
                SettingsLiteView()
            }
        }
        .onAppear {
            // Longer delay for Settings to ensure other views are loaded first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showOriginal = true
            }
        }
    }
}

// MARK: - Lazy Map Wrapper (only loads when tab is selected)
struct LazyMapWrapper: View {
    let isSelected: Bool
    @State private var hasBeenSelected = false
    @State private var showMap = false
    
    var body: some View {
        Group {
            if showMap {
                OptimizedMapView()
            } else {
                // Ultra-light placeholder until tab is selected
                MapPlaceholderView()
            }
        }
        .onChange(of: isSelected) { _, newValue in
            if newValue && !hasBeenSelected {
                hasBeenSelected = true
                // Small delay to let tab animation complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showMap = true
                    AppLogger.ui("MapView loaded (tab selected)")
                }
            }
        }
    }
}

// MARK: - Ultra-light Map Placeholder (shown before tab is ever selected)
struct MapPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("map.title_short".localized)
                    .font(.title2.bold())
                
                Text("map.tap_to_open".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .navigationTitle("map.title_short".localized)
        }
        .journeyScreen(.city, darkness: 0.72)
    }
}

// MARK: - Optimized Map View (full functionality, optimized performance)
struct OptimizedMapView: View {
    @EnvironmentObject private var appContainer: AppContainer
    
    private enum RangeMode {
        case nearby
        case all
    }

    @State private var places: [Place] = []
    @State private var selectedType: PlaceType?
    @State private var selectedPlace: Place?
    @State private var isLoading = true
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.8182, longitude: 8.2275),
            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
        )
    )
    @State private var rangeMode: RangeMode = .nearby
    @State private var hasAutoCenteredOnUser = false
    @State private var mapScrollOffset: CGFloat = 0

    private let nearbyRadiusMeters: Double = 10_000
    private let embeddedMapExpandedHeight: CGFloat = 340
    private let embeddedMapCollapsedHeight: CGFloat = 150

    private var embeddedMapHeight: CGFloat {
        let delta = min(max(mapScrollOffset * 0.72, 0), embeddedMapExpandedHeight - embeddedMapCollapsedHeight)
        return embeddedMapExpandedHeight - delta
    }

    private var embeddedMapCollapseProgress: CGFloat {
        let range = max(1, embeddedMapExpandedHeight - embeddedMapCollapsedHeight)
        return min(max((embeddedMapExpandedHeight - embeddedMapHeight) / range, 0), 1)
    }

    private var embeddedMapOverlayOpacity: CGFloat {
        max(0, 1 - embeddedMapCollapseProgress * 1.65)
    }

    private var currentLanguageCode: String {
        String(appContainer.currentLocale.identifier.prefix(2)).lowercased()
    }
    
    private var userLocation: CLLocation? {
        appContainer.locationService.currentLocation
    }
    
    private var filteredPlaces: [Place] {
        let typedPlaces: [Place]
        if let type = selectedType {
            typedPlaces = places.filter { $0.type == type }
        } else {
            typedPlaces = places
        }
        
        guard rangeMode == .nearby,
              let userLocation else {
            return typedPlaces
        }
        
        let userCoord = userLocation.coordinate
        return typedPlaces.filter { place in
            let coord = place.coordinate.clLocationCoordinate
            let distance = distanceMeters(from: userCoord, to: coord)
            return distance <= nearbyRadiusMeters
        }
    }
    
    private var visiblePlaces: [Place] {
        Array(filteredPlaces.prefix(50))
    }
    
    private var openNowCount: Int {
        filteredPlaces.filter { $0.isOpen() }.count
    }
    
    private var nearbyPlaces: [Place] {
        guard let userLocation else { return [] }
        return filteredPlaces
            .filter { $0.distance(from: userLocation) <= nearbyRadiusMeters }
            .sorted { lhs, rhs in
                lhs.distance(from: userLocation) < rhs.distance(from: userLocation)
            }
    }
    
    private var bestMatches: [Place] {
        Array(filteredPlaces.sorted { score(for: $0) > score(for: $1) }.prefix(6))
    }
    
    private var nearbyNow: [Place] {
        guard let userLocation else { return [] }
        return nearbyPlaces
            .sorted { lhs, rhs in
                if lhs.isOpen() != rhs.isOpen() {
                    return lhs.isOpen() && !rhs.isOpen()
                }
                return lhs.distance(from: userLocation) < rhs.distance(from: userLocation)
            }
            .prefix(6)
            .map { $0 }
    }
    
    private var popularTypes: [(type: PlaceType, count: Int)] {
        Dictionary(grouping: filteredPlaces, by: \.type)
            .map { (type: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.type.localizedName < rhs.type.localizedName
                }
                return lhs.count > rhs.count
            }
    }
    
    private var allPlacesSorted: [Place] {
        if let userLocation {
            return filteredPlaces.sorted { lhs, rhs in
                lhs.distance(from: userLocation) < rhs.distance(from: userLocation)
            }
        }
        return filteredPlaces.sorted { score(for: $0) > score(for: $1) }
    }
    
    private var featuredPlace: Place? {
        selectedPlace ?? bestMatches.first ?? filteredPlaces.first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 8, darkness: 0.7)
                
                ScrollView(showsIndicators: false) {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: OptimizedMapScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("optimizedMapScroll")).minY
                            )
                    }
                    .frame(height: 0)

                    VStack(spacing: 16) {
                        filtersSection
                        
                        if isLoading {
                            mapLoadingPlaceholder
                        } else {
                            heroMapSection
                            discoverySections
                        }
                    }
                    .padding(.bottom, 100)
                }
                .coordinateSpace(name: "optimizedMapScroll")
                .onPreferenceChange(OptimizedMapScrollOffsetPreferenceKey.self) { minY in
                    mapScrollOffset = max(0, -minY)
                }
            }
            .navigationTitle("map.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .journeyScreen(.city, darkness: 0.7)
        .sheet(item: $selectedPlace) { place in
            PlaceDetailSheet(place: place)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .onAppear {
            loadPlacesOnce()
            ensureLocationFlow()
            applyPendingMapFocus()
        }
        .onChange(of: userLocation?.coordinate.latitude) { _, _ in
            autoCenterIfNeeded()
        }
        .onChange(of: userLocation?.coordinate.longitude) { _, _ in
            autoCenterIfNeeded()
        }
        .onChange(of: rangeMode) { _, mode in
            if mode == .nearby {
                ensureLocationFlow()
            }
        }
        .onChange(of: appContainer.locationService.authorizationStatus) { _, status in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                appContainer.locationService.startLocationUpdates()
                autoCenterIfNeeded(force: true)
            case .denied, .restricted:
                hasAutoCenteredOnUser = false
            default:
                break
            }
        }
    }
    
    // MARK: - Filters
    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Range: nearby or all of Switzerland
                MapFilterChip(
                    title: "map.range.nearby_10km".localized,
                    isSelected: rangeMode == .nearby,
                    color: Theme.Colors.primary
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        rangeMode = .nearby
                    }
                }
                
                MapFilterChip(
                    title: "map.range.all_switzerland".localized,
                    isSelected: rangeMode == .all,
                    color: .purple
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        rangeMode = .all
                    }
                }
                
                // Semantic divider: service-type filter below
                MapFilterChip(
                    title: "common.all".localized,
                    isSelected: selectedType == nil,
                    color: Theme.Colors.primaryLight
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedType = nil
                    }
                }
                
                ForEach(PlaceType.allCases, id: \.self) { type in
                    MapFilterChip(
                        title: type.localizedName,
                        isSelected: selectedType == type,
                        color: type.swiftUIColor
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedType = selectedType == type ? nil : type
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    private var mapLoadingPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.92, blue: 0.85),
                    Color(red: 0.75, green: 0.88, blue: 0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                ProgressView()
                Text("common.loading".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .frame(height: 220)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var heroMapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                ForEach(visiblePlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate.clLocationCoordinate) {
                        PlaceAnnotationView(place: place) {
                            selectedPlace = place
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat)) // Flat style is faster
            .frame(height: embeddedMapHeight)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.Colors.primary.opacity(0.4), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Theme.Colors.primary.opacity(0.16), radius: 14, y: 6)
            
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("map.hero_title".localized)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text("map.hero_subtitle".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.84))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: 310, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        mapHeroChip(icon: "mappin.circle.fill", text: "\(filteredPlaces.count)")
                        mapHeroChip(icon: "location.fill", text: userLocation == nil ? "—" : "\(nearbyPlaces.count)")
                        mapHeroChip(icon: "clock.fill", text: "\(openNowCount)")
                    }
                }
                .scrollDisabled(true)

                Spacer(minLength: 8)

                if let featuredPlace {
                    Button {
                        selectedPlace = featuredPlace
                    } label: {
                        MapHeroFeaturedCard(
                            place: featuredPlace,
                            distanceText: distanceText(for: featuredPlace),
                            badge: featuredPlace == bestMatches.first ? "map.best_match".localized : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(embeddedMapCollapseProgress > 0.35 ? 0 : 1)
                    .scaleEffect(embeddedMapCollapseProgress > 0.35 ? 0.96 : 1)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(embeddedMapOverlayOpacity)

            Button {
                centerOnUserLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.primaryLight, Theme.Colors.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .accessibilityLabel("map.center_on_me.label".localized)
            .accessibilityHint("map.center_on_me.hint".localized)
            .padding(12)
        }
        .padding(.horizontal)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: embeddedMapHeight)
    }
    
    private func mapHeroChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private var discoverySections: some View {
        VStack(alignment: .leading, spacing: 18) {
            mapSectionHeader("map.best_matches".localized, count: bestMatches.count)
            if bestMatches.isEmpty {
                mapSectionEmptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(bestMatches.enumerated()), id: \.element.id) { index, place in
                            MapDiscoveryPlaceCard(
                                place: place,
                                distanceText: distanceText(for: place),
                                badge: index == 0 ? "map.best_match".localized : nil,
                                action: { selectedPlace = place }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            mapSectionHeader("map.nearby_now".localized, count: nearbyNow.count)
            if userLocation == nil {
                MapLocationPermissionCard(
                    title: locationCardTitle,
                    subtitle: locationCardSubtitle,
                    buttonTitle: locationCardButtonTitle
                ) {
                    handleLocationAction()
                }
                .padding(.horizontal, 16)
            } else if nearbyNow.isEmpty {
                mapSectionEmptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(nearbyNow) { place in
                            MapDiscoveryPlaceCard(
                                place: place,
                                distanceText: distanceText(for: place),
                                badge: place.isOpen() ? "map.open_now".localized : nil,
                                action: { selectedPlace = place }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            mapSectionHeader("map.popular_services".localized, count: popularTypes.count)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(popularTypes, id: \.type) { item in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedType = selectedType == item.type ? nil : item.type
                            }
                        } label: {
                            MapPopularTypeCard(
                                type: item.type,
                                count: item.count,
                                isSelected: selectedType == item.type
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            mapSectionHeader("map.all_places".localized, count: allPlacesSorted.count)
            if allPlacesSorted.isEmpty {
                mapSectionEmptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(allPlacesSorted.prefix(24)) { place in
                        PlaceLiteRow(place: place)
                            .onTapGesture {
                                selectedPlace = place
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func mapSectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.adaptiveCard)
                            .overlay(
                                Capsule().stroke(Theme.Colors.adaptiveBorder.opacity(0.55), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var mapSectionEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.slash")
                .font(.title3)
                .foregroundColor(Theme.Colors.textTertiary)
            Text("map.no_places".localized)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.horizontal, 16)
    }
    
    private func score(for place: Place) -> Double {
        var total = 0.0
        
        if let selectedType, place.type == selectedType {
            total += 18
        }
        if place.isOpen() {
            total += 16
        }
        if place.supportsLanguage(currentLanguageCode) {
            total += 14
        }
        if place.supportsLanguage("uk") {
            total += 10
        }
        if place.verifiedAt != nil {
            total += 8
        }
        if place.isAccessible {
            total += 5
        }
        total += min(place.rating ?? 0, 5) * 2
        total += min(Double(place.reviewCount), 25) * 0.25
        total += min(Double(place.services.count), 6)
        
        if let userLocation {
            let distance = place.distance(from: userLocation)
            total += max(0, 30 - min(distance / 500, 30))
            if distance <= nearbyRadiusMeters {
                total += 12
            }
        }
        
        return total
    }
    
    private func distanceText(for place: Place) -> String? {
        guard let userLocation else { return nil }
        let distance = place.distance(from: userLocation)
        if distance < 1000 {
            return "\(Int(distance)) \("common.unit.meters".localized)"
        }
        return String(format: "%.1f %@", distance / 1000, "common.unit.kilometers".localized)
    }
    
    private func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadiusKm = 6_371.0
        
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadiusKm * c * 1_000 // meters
    }
    
    private func loadPlacesOnce() {
        guard places.isEmpty else { return }
        
        Task {
            let loadedPlaces = appContainer.contentService.places
            if !loadedPlaces.isEmpty {
                await MainActor.run {
                    places = loadedPlaces
                    isLoading = false
                }
                return
            }
            
            for _ in 1...5 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                let retryPlaces = await MainActor.run { appContainer.contentService.places }
                if !retryPlaces.isEmpty {
                    await MainActor.run {
                        places = retryPlaces
                        isLoading = false
                    }
                    return
                }
            }
            
            await MainActor.run {
                places = appContainer.contentService.places
                isLoading = false
            }
        }
    }
    
    private func centerOnUserLocation() {
        guard let location = appContainer.locationService.currentLocation else {
            handleLocationAction()
            return
        }
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }
    
    private var locationCardTitle: String {
        switch appContainer.locationService.authorizationStatus {
        case .denied, .restricted:
            return "map.location_denied_title".localized
        default:
            return "map.location_permission".localized
        }
    }
    
    private var locationCardSubtitle: String {
        switch appContainer.locationService.authorizationStatus {
        case .denied, .restricted:
            return "map.location_denied_subtitle".localized
        default:
            return "map.nearby_requires_location".localized
        }
    }
    
    private var locationCardButtonTitle: String {
        switch appContainer.locationService.authorizationStatus {
        case .denied, .restricted:
            return "map.open_settings".localized
        default:
            return "map.enable_location".localized
        }
    }
    
    private func handleLocationAction() {
        switch appContainer.locationService.authorizationStatus {
        case .denied, .restricted:
            appContainer.locationService.openAppSettings()
        case .authorizedAlways, .authorizedWhenInUse:
            appContainer.locationService.startLocationUpdates()
            autoCenterIfNeeded(force: true)
        case .notDetermined:
            appContainer.locationService.requestLocationPermission()
        @unknown default:
            appContainer.locationService.requestLocationPermission()
        }
    }
    
    private func ensureLocationFlow() {
        guard rangeMode == .nearby else { return }
        switch appContainer.locationService.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            appContainer.locationService.startLocationUpdates()
            autoCenterIfNeeded()
        case .notDetermined:
            appContainer.locationService.requestLocationPermission()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
    
    private func applyPendingMapFocus() {
        guard let target = MapFocusRouter.pending else { return }
        MapFocusRouter.pending = nil
        hasAutoCenteredOnUser = true
        rangeMode = .all
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: target.latitude, longitude: target.longitude),
                    span: MKCoordinateSpan(latitudeDelta: target.spanDelta, longitudeDelta: target.spanDelta)
                )
            )
        }
    }

    private func autoCenterIfNeeded(force: Bool = false) {
        guard let location = appContainer.locationService.currentLocation else { return }
        guard force || !hasAutoCenteredOnUser else { return }
        hasAutoCenteredOnUser = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            )
        }
    }
}

private struct OptimizedMapScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct MapHeroFeaturedCard: View {
    let place: Place
    let distanceText: String?
    let badge: String?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(place.type.swiftUIColor.opacity(0.22))
                    .frame(width: 46, height: 46)
                Image(systemName: place.type.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(place.type.swiftUIColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(place.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange.opacity(0.9)))
                            .fixedSize()
                    }
                }
                
                Text(place.type.localizedName)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let distanceText {
                        mapMeta(text: distanceText, color: Theme.Colors.primaryLight)
                    }
                    mapMeta(text: place.isOpen() ? "map.open".localized : "map.closed".localized, color: place.isOpen() ? .green : .red)
                }
                .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func mapMeta(text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct MapDiscoveryPlaceCard: View {
    let place: Place
    let distanceText: String?
    let badge: String?
    let action: () -> Void
    @EnvironmentObject private var appContainer: AppContainer

    private var localizedDescription: String? {
        place.localizedDescription(for: appContainer.currentLocale)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(place.type.swiftUIColor.opacity(0.18))
                            .frame(width: 52, height: 52)
                        Image(systemName: place.type.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(place.type.swiftUIColor)
                    }
                    
                    Spacer()
                    
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.orange.opacity(0.85)))
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                    Text(place.type.localizedName)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    statusCapsule(text: place.isOpen() ? "map.open".localized : "map.closed".localized, color: place.isOpen() ? .green : .red)
                    if let distanceText {
                        statusCapsule(text: distanceText, color: Theme.Colors.primaryLight)
                    }
                    if place.verifiedAt != nil {
                        statusCapsule(text: "map.verified".localized, color: Theme.Colors.primary)
                    }
                }
                
                if let description = localizedDescription, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(width: 270, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.Colors.adaptiveCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func statusCapsule(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

private struct MapPopularTypeCard: View {
    let type: PlaceType
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(type.swiftUIColor.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: type.iconName)
                    .foregroundColor(type.swiftUIColor)
            }
            
            Text(type.localizedName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
            
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? type.swiftUIColor : Theme.Colors.textPrimary)
        }
        .frame(width: 140, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? type.swiftUIColor.opacity(0.12) : Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isSelected ? type.swiftUIColor.opacity(0.5) : Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

private struct MapLocationPermissionCard: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "location.slash.fill")
                    .foregroundColor(Theme.Colors.primary)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
            
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                    Text(buttonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.Colors.primary)
                .foregroundColor(Theme.Colors.textOnPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

// MARK: - Place Annotation View (lightweight)
struct PlaceAnnotationView: View {
    let place: Place
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(place.type.swiftUIColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Image(systemName: place.type.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(place.type.swiftUIColor)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Place Detail Sheet (enhanced winter design)
struct PlaceDetailSheet: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @State private var distanceText: String?

    private var localizedDescription: String? {
        place.localizedDescription(for: appContainer.currentLocale)
    }
    
    private var todayHours: String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        if let hours = place.openingHours.first(where: { $0.weekday == weekday }) {
            if hours.isClosed { return "map.closed_today".localized }
            return "\(hours.openTime.formatted) – \(hours.closeTime.formatted)"
        }
        return "map.hours_unknown".localized
    }
    
    private var languageFlags: String {
        place.languages.prefix(4).map { code -> String in
            switch code {
            case "uk": return "🇺🇦"
            case "de": return "🇩🇪"
            case "fr": return "🇫🇷"
            case "en": return "🇬🇧"
            case "it": return "🇮🇹"
            case "ru": return "🇷🇺"
            default: return "🌐"
            }
        }.joined(separator: " ")
    }
    
    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 8, darkness: 0.74)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with icon and status
                    headerSection
                    
                    // Quick info chips
                    quickInfoSection
                    
                    // Description if available
                    if let desc = localizedDescription, !desc.isEmpty {
                        descriptionSection(desc)
                    }
                    
                    // Services if available
                    if !place.services.isEmpty {
                        servicesSection
                    }
                    
                    // Action buttons
                    actionButtonsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .journeyScreen(.city, darkness: 0.74)
        .onAppear {
            calculateDistance()
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(place.type.swiftUIColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: place.type.iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(place.type.swiftUIColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(place.type.localizedName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                
                // Rating if available
                if let rating = place.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption.bold())
                            .foregroundColor(.yellow)
                        Text("(\(place.reviewCount))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            Spacer()
            
            // Open/Closed badge
            VStack(spacing: 4) {
                Circle()
                    .fill(place.isOpen() ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: place.isOpen() ? .green.opacity(0.5) : .red.opacity(0.5), radius: 4)
                Text(place.isOpen() ? "map.open".localized : "map.closed".localized)
                    .font(.caption.bold())
                    .foregroundColor(place.isOpen() ? .green : .red)
            }
        }
    }
    
    // MARK: - Quick Info Chips
    private var quickInfoSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Distance
                if let dist = distanceText {
                    infoChip(icon: "location.fill", text: dist, color: Theme.Colors.primaryLight)
                }
                
                // Today's hours
                infoChip(icon: "clock.fill", text: todayHours, color: .orange)
                
                // Languages
                if !place.languages.isEmpty {
                    infoChip(icon: nil, text: languageFlags, color: .purple)
                }
                
                // Accessible
                if place.isAccessible {
                    infoChip(icon: "figure.roll", text: "map.accessible".localized, color: Theme.Colors.primary)
                }
            }
        }
    }
    
    private func infoChip(icon: String?, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            if let iconName = icon {
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundColor(color)
            }
            Text(text)
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Description
    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("map.description".localized, systemImage: "text.alignleft")
                .font(.caption.bold())
                .foregroundColor(Theme.Colors.primaryLight)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Colors.adaptiveSurface, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Services
    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("map.services_label".localized, systemImage: "checkmark.seal.fill")
                .font(.caption.bold())
                .foregroundColor(Theme.Colors.primaryLight)
            
            FlowLayout(spacing: 8) {
                ForEach(place.services.prefix(6), id: \.self) { service in
                    Text(service)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.primary.opacity(0.15))
                        )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Colors.adaptiveSurface, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary action - Directions
            Button {
                openInMaps()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    Text("map.directions".localized)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Theme.Colors.primaryLight, Theme.Colors.primary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 8, y: 4)
            }
            
            // Secondary actions
            HStack(spacing: 12) {
                if let phone = place.phoneNumber {
                    Button {
                        if let url = URL(string: "tel:\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("map.call".localized)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.adaptiveSurface)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                
                if let website = place.website {
                    Button {
                        if let url = URL(string: website) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "safari.fill")
                            Text("map.website".localized)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.adaptiveSurface)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .font(.subheadline.weight(.medium))
            
            // Address with copy
            Button {
                UIPasteboard.general.string = place.formattedAddress
            } label: {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.orange)
                    Text(place.formattedAddress)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                .font(.caption)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Helpers
    private func openInMaps() {
        let coordinate = place.coordinate.clLocationCoordinate
        let mapItem = MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil
        )
        mapItem.name = place.name
        mapItem.openInMaps()
    }
    
    private func calculateDistance() {
        guard let userLoc = appContainer.locationService.currentLocation else { return }
        let distance = place.distance(from: userLoc)
        if distance < 1000 {
            distanceText = "\(Int(distance)) \("common.unit.meters".localized)"
        } else {
            distanceText = String(format: "%.1f %@", distance / 1000, "common.unit.kilometers".localized)
        }
    }
}

// MARK: - Map Filter Chip
struct MapFilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [color.opacity(0.55), color.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Theme.Colors.adaptiveCard, Theme.Colors.adaptiveCard.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color.opacity(0.45) : Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
                )
                .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
                .shadow(color: isSelected ? color.opacity(0.25) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Place Lite Row
struct PlaceLiteRow: View {
    let place: Place
    @EnvironmentObject private var appContainer: AppContainer
    
    private var distanceText: String? {
        guard let userLocation = appContainer.locationService.currentLocation else { return nil }
        let distance = place.distance(from: userLocation)
        if distance < 1000 {
            return "\(Int(distance)) \("common.unit.meters".localized)"
        }
        return String(format: "%.1f %@", distance / 1000, "common.unit.kilometers".localized)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [place.type.swiftUIColor.opacity(0.35), place.type.swiftUIColor.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                
                Image(systemName: place.type.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(place.type.swiftUIColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(place.type.localizedName)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(place.isOpen() ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(place.isOpen() ? "map.open".localized : "map.closed".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(place.isOpen() ? .green : .red)
                }
                
                HStack(spacing: 6) {
                    if let distanceText {
                        rowBadge(text: distanceText, color: Theme.Colors.primaryLight)
                    }
                    if place.verifiedAt != nil {
                        rowBadge(text: "map.verified".localized, color: Theme.Colors.primary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                openInMaps()
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.Colors.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }
    
    private func rowBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }
    
    private func openInMaps() {
        let coordinate = place.coordinate.clLocationCoordinate
        let mapItem = MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil
        )
        mapItem.name = place.name
        mapItem.openInMaps()
    }
}


// MARK: - Optimized Home View
struct HomeSimplifiedView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    
    @State private var userName = ""
    @State private var guidesCount = 0
    @State private var totalXP = 0
    @State private var level = 1
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Card
                    welcomeCard
                    
                    // Stats Row
                    statsRow
                    
                    // Quick Actions
                    quickActionsGrid
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle("Sweezy")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        NotificationCenter.default.post(name: .openDeepLinkDestination, object: DeepLink.settings)
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .journeyScreen(.lake, darkness: 0.68)
        .onAppear { loadData() }
    }
    
    private func loadData() {
        userName = lockManager.userName.isEmpty ? "User" : lockManager.userName
        guidesCount = appContainer.userStats.guidesReadCount
        totalXP = appContainer.gamification.totalXP
        level = appContainer.gamification.level()
    }
    
    // MARK: - Welcome Card
    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("home.welcome_name_format".localized(with: userName))
                .font(.title2.bold())
            Text("home.subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }
    
    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "home.stats.guides_short".localized, value: "\(guidesCount)", icon: "book.fill", color: .blue)
            StatCard(title: "XP", value: "\(totalXP)", icon: "star.fill", color: .orange)
            StatCard(title: "home.stats.level".localized, value: "\(level)", icon: "trophy.fill", color: .purple)
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("home.quick_actions".localized)
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickAction(title: "guides.title".localized, icon: "book.fill", color: .blue, tab: 1)
                QuickAction(title: "qa.map".localized, icon: "map.fill", color: .orange, tab: 2)
                QuickAction(title: "marketplace.tab".localized, icon: "bag.fill", color: Theme.Colors.primary, tab: 3)
                QuickAction(title: "journey.tab.people".localized, icon: "person.2.fill", color: JourneyVisual.lime, tab: 4)
            }
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Quick Action Component
struct QuickAction: View {
    let title: String
    let icon: String
    let color: Color
    let tab: Int
    
    var body: some View {
        Button {
            NotificationCenter.default.post(name: .switchTab, object: tab)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("home.open_format".localized(with: title))
    }
}

// MARK: - Guides Lite View
struct GuidesLiteView: View {
    @EnvironmentObject private var appContainer: AppContainer
    
    @State private var guides: [Guide] = []
    @State private var searchText = ""
    @State private var selectedCategory: GuideCategory?
    @State private var isLoading = true
    
    var filteredGuides: [Guide] {
        var result = guides
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.subtitle?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("common.loading".localized)
                } else if guides.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("home.guides_coming_soon".localized)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        // Category filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                LiteCategoryChip(
                                    title: "common.all".localized,
                                    isSelected: selectedCategory == nil,
                                    color: .blue
                                ) {
                                    selectedCategory = nil
                                }
                                
                                ForEach(GuideCategory.allCases, id: \.self) { category in
                                    LiteCategoryChip(
                                        title: category.localizedName,
                                        isSelected: selectedCategory == category,
                                        color: category.swiftUIColor
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        
                        // Guides list
                        ForEach(filteredGuides) { guide in
                            NavigationLink {
                                GuideDetailView(guide: guide)
                            } label: {
                                GuideRow(guide: guide)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .journeyForm()
                }
            }
            .navigationTitle("guides.title".localized)
            .searchable(text: $searchText, prompt: Text("guides.search_placeholder".localized))
        }
        .journeyScreen(.alpine, darkness: 0.7)
        .onAppear {
            AppLogger.ui("GuidesLiteView appeared")
            loadGuides()
        }
    }
    
    private func loadGuides() {
        Task {
            // Wait for content service to load (retry up to 10 times)
            for attempt in 1...10 {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                let loadedGuides = await MainActor.run { appContainer.contentService.guides }
                if !loadedGuides.isEmpty {
                    await MainActor.run {
                        guides = loadedGuides
                        isLoading = false
                        AppLogger.content("Loaded \(guides.count) guides on attempt \(attempt)")
                    }
                    return
                }
            }
            // Fallback: show empty state
            await MainActor.run {
                guides = appContainer.contentService.guides
                isLoading = false
                AppLogger.content("Loaded \(guides.count) guides (final)")
            }
        }
    }
}

// MARK: - Guide Row
struct GuideRow: View {
    let guide: Guide
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: guide.category.iconName)
                .font(.title2)
                .foregroundColor(guide.category.swiftUIColor)
                .frame(width: 44, height: 44)
                .background(guide.category.swiftUIColor.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(guide.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(guide.category.localizedName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if guide.isNew {
                        Text("NEW")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    if guide.isPremium {
                        Text("PLUS")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.accent.opacity(0.18))
                            .foregroundColor(Theme.Colors.accent)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Category Chip (scoped for Lite views to avoid name clashes)
struct LiteCategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Checklists Lite View
struct ChecklistsLiteView: View {
    @EnvironmentObject private var appContainer: AppContainer
    
    @State private var checklists: [Checklist] = []
    @State private var isLoading = true
    @State private var completedStepsByChecklist: [UUID: Set<UUID>] = [:]
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("common.loading".localized)
                } else if checklists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checklist")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("home.checklists_coming_soon".localized)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(checklists) { checklist in
                            NavigationLink {
                                ChecklistDetailLiteView(
                                    checklist: checklist,
                                    completedStepIds: Binding(
                                        get: { completedStepsByChecklist[checklist.id] ?? [] },
                                        set: { completedStepsByChecklist[checklist.id] = $0 }
                                    )
                                )
                            } label: {
                                ChecklistRow(
                                    checklist: checklist,
                                    completedStepIds: completedStepsByChecklist[checklist.id] ?? []
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                    .journeyForm()
                }
            }
            .navigationTitle("checklists.title".localized)
        }
        .journeyScreen(.alpine, darkness: 0.7)
        .onAppear {
            AppLogger.ui("ChecklistsLiteView appeared")
            loadChecklists()
        }
    }
    
    private func loadChecklists() {
        Task {
            // Wait for content service to load (retry up to 10 times)
            for attempt in 1...10 {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                let loadedChecklists = await MainActor.run { appContainer.contentService.checklists }
                if !loadedChecklists.isEmpty {
                    await MainActor.run {
                        checklists = loadedChecklists
                        isLoading = false
                        AppLogger.content("Loaded \(checklists.count) checklists on attempt \(attempt)")
                    }
                    return
                }
            }
            // Fallback: show empty state
            await MainActor.run {
                checklists = appContainer.contentService.checklists
                isLoading = false
                AppLogger.content("Loaded \(checklists.count) checklists (final)")
            }
        }
    }
}

// MARK: - Checklist Row
struct ChecklistRow: View {
    let checklist: Checklist
    let completedStepIds: Set<UUID>
    
    var completedSteps: Int {
        checklist.steps.filter { completedStepIds.contains($0.id) }.count
    }
    
    var progress: Double {
        guard !checklist.steps.isEmpty else { return 0 }
        return Double(completedSteps) / Double(checklist.steps.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: checklist.category.iconName)
                    .font(.title2)
                    .foregroundColor(checklist.category.swiftUIColor)
                    .frame(width: 40, height: 40)
                    .background(checklist.category.swiftUIColor.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(checklist.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    
                    Text("home.steps_format".localized(with: completedSteps, checklist.steps.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if progress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.Colors.primaryLight.opacity(0.15))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.Colors.primary)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Checklist Detail Lite View
struct ChecklistDetailLiteView: View {
    let checklist: Checklist
    @Binding var completedStepIds: Set<UUID>
    
    var body: some View {
        List {
            ForEach(checklist.steps) { step in
                let done = completedStepIds.contains(step.id)
                ChecklistStepRow(
                    step: step,
                    checklistId: checklist.id,
                    isCompleted: done
                ) {
                    if done {
                        completedStepIds.remove(step.id)
                    } else {
                        completedStepIds.insert(step.id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .journeyForm()
        .navigationTitle(checklist.title)
        .journeyScreen(.alpine, darkness: 0.72)
    }
}

// MARK: - Checklist Step Row
struct ChecklistStepRow: View {
    let step: ChecklistStep
    let checklistId: UUID
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? Theme.Colors.primary : Theme.Colors.textTertiary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline)
                        .strikethrough(isCompleted, color: Theme.Colors.textTertiary)
                        .foregroundColor(isCompleted ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    
                    if !step.description.isEmpty {
                        Text(step.description)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Lite View
struct SettingsLiteView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var totalXP = 0
    @State private var level = 1
    @State private var guidesRead = 0
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 60, height: 60)
                            
                            Text(String(userName.prefix(1)).uppercased())
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName)
                                .font(.headline)
                            Text(userEmail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Gamification Card
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("home.level_format".localized(with: level))
                                    .font(.headline)
                                Text("\(totalXP) XP")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "trophy.fill")
                                .font(.title)
                                .foregroundColor(.yellow)
                        }
                        
                        // Progress to next level
                        let nextLevelXP = level * 100
                        let progress = min(Double(totalXP) / Double(nextLevelXP), 1.0)
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * progress, height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Label("gamification.guides_count_format".localized(with: guidesRead), systemImage: "book.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("gamification.to_level_xp_format".localized(with: level + 1, nextLevelXP - totalXP))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // App Settings
                Section("settings.title".localized) {
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        Label("settings.language".localized, systemImage: "globe")
                    }
                    
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("settings.notifications".localized, systemImage: "bell")
                    }
                    
                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        Label("settings.theme.title".localized, systemImage: "paintbrush")
                    }
                }
                
                // Support
                Section("settings.support".localized) {
                    if let emailURL = URL(string: "mailto:support@sweezy.world") {
                        Link(destination: emailURL) {
                            Label("settings.email_support".localized, systemImage: "envelope")
                        }
                    }
                }
                
                // About
                Section("settings.about".localized) {
                    HStack {
                        Text("settings.version_label".localized)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Text("privacy.title".localized)
                    }
                    
                    NavigationLink(destination: TermsOfUseView()) {
                        Text("settings.terms".localized)
                    }
                }
                
                // Logout
                Section {
                    Button(role: .destructive) {
                        performLogout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("settings.logout".localized)
                            Spacer()
                        }
                    }
                }
            }
            .journeyForm()
            .navigationTitle("settings.title".localized)
            .refreshable {
                loadData()
            }
        }
        .journeyScreen(.city, darkness: 0.72)
        .onAppear {
            AppLogger.ui("SettingsLiteView appeared")
            loadData()
        }
    }
    
    private func loadData() {
        userName = lockManager.userName.isEmpty ? "User" : lockManager.userName
        userEmail = lockManager.userEmail
        totalXP = appContainer.gamification.totalXP
        level = appContainer.gamification.level()
        guidesRead = appContainer.userStats.guidesReadCount
    }
    
    private func performLogout() {
        KeychainStore.delete("access_token")
        KeychainStore.delete("refresh_token")
        lockManager.isRegistered = false
        lockManager.userName = ""
        lockManager.userEmail = ""
    }
}

// MARK: - Settings Sub-Views
struct LanguageSettingsView: View {
    var body: some View {
        List {
            Text("language.ukrainian".localized)
            Text("English")
            Text("Deutsch")
        }
        .journeyForm()
        .navigationTitle("settings.language".localized)
        .journeyScreen(.city, darkness: 0.72)
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var notificationsEnabled = NotificationPreference.isEnabled
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingCount = 0
    @State private var isWorking = false
    @State private var showSettingsPrompt = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.notifications.eyebrow".localized)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(JourneyVisual.lime)

                    Text("settings.notifications.title".localized)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("settings.notifications.subtitle".localized)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                notificationMasterCard
                notificationStatusCard

                Text("settings.notifications.privacy".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("common.done".localized) { dismiss() }
                    .foregroundColor(JourneyVisual.lime)
            }
        }
        .journeyScreen(.city, darkness: 0.72)
        .task { await refreshState() }
        .alert("settings.notifications.disabled_title".localized, isPresented: $showSettingsPrompt) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("settings.notifications.open_settings".localized) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
        } message: {
            Text("settings.notifications.disabled_message".localized)
        }
    }

    private var notificationMasterCard: some View {
        JourneyGlassPanel(cornerRadius: 26) {
            VStack(spacing: 15) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(notificationsEnabled ? JourneyVisual.lime : Color.white.opacity(0.08))
                            .frame(width: 54, height: 54)
                        Image(systemName: notificationsEnabled ? "bell.badge.fill" : "bell.slash.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(notificationsEnabled ? .black : .white.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.notifications.master".localized)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        Text(notificationsEnabled
                             ? "settings.notifications.master_on".localized
                             : "settings.notifications.master_off".localized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.58))
                    }

                    Spacer()

                    if isWorking {
                        ProgressView().tint(JourneyVisual.lime)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { notificationsEnabled },
                            set: { newValue in Task { await setNotificationsEnabled(newValue) } }
                        ))
                        .labelsHidden()
                        .tint(JourneyVisual.lime)
                        .accessibilityLabel("settings.notifications.master".localized)
                        .accessibilityIdentifier("settings.notifications.masterToggle")
                    }
                }

                Divider().overlay(Color.white.opacity(0.12))

                HStack(spacing: 8) {
                    notificationBenefit(icon: "calendar.badge.clock", title: "settings.notifications.deadlines".localized)
                    notificationBenefit(icon: "bubble.left.and.bubble.right.fill", title: "settings.notifications.chat".localized)
                    notificationBenefit(icon: "person.crop.circle.badge.clock", title: "settings.notifications.appointments".localized)
                }
            }
            .padding(18)
        }
    }

    private var notificationStatusCard: some View {
        JourneyGlassPanel(cornerRadius: 24) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(statusColor.opacity(0.16))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: statusIcon)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(statusColor)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings.notifications.system_status".localized)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(statusTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(statusColor)
                    }
                    Spacer()
                    Text("\(pendingCount)")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("settings.notifications.pending".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.48))
                }
                .padding(17)

                if authorizationStatus == .denied {
                    Divider().overlay(Color.white.opacity(0.12))
                    Button {
                        showSettingsPrompt = true
                    } label: {
                        HStack {
                            Text("settings.notifications.open_settings".localized)
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .foregroundColor(JourneyVisual.lime)
                        .padding(17)
                    }
                    .accessibilityIdentifier("settings.notifications.openSystemSettings")
                }
            }
        }
    }

    private func notificationBenefit(icon: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(JourneyVisual.lime)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.66))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 58)
    }

    private var statusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: return JourneyVisual.lime
        case .denied: return .orange
        default: return .white.opacity(0.66)
        }
    }

    private var statusIcon: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "checkmark.circle.fill"
        case .denied: return "exclamationmark.triangle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var statusTitle: String {
        switch authorizationStatus {
        case .authorized: return "settings.notifications.status_allowed".localized
        case .provisional, .ephemeral: return "settings.notifications.status_quiet".localized
        case .denied: return "settings.notifications.status_denied".localized
        case .notDetermined: return "settings.notifications.status_not_asked".localized
        @unknown default: return "settings.notifications.status_unknown".localized
        }
    }

    @MainActor
    private func refreshState() async {
        await appContainer.notificationService.refreshAuthorizationStatus()
        authorizationStatus = appContainer.notificationService.authorizationStatus
        if UserDefaults.standard.object(forKey: NotificationPreference.enabledKey) == nil,
           appContainer.notificationService.isAuthorized {
            NotificationPreference.isEnabled = true
        }
        notificationsEnabled = NotificationPreference.isEnabled && appContainer.notificationService.isAuthorized
        pendingCount = await appContainer.notificationService.getPendingNotifications().count
    }

    @MainActor
    private func setNotificationsEnabled(_ enabled: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        if enabled {
            await appContainer.notificationService.refreshAuthorizationStatus()
            authorizationStatus = appContainer.notificationService.authorizationStatus
            if authorizationStatus == .denied {
                notificationsEnabled = false
                NotificationPreference.isEnabled = false
                showSettingsPrompt = true
                return
            }
            var granted = appContainer.notificationService.isAuthorized
            if !granted {
                granted = await appContainer.notificationService.requestPermission()
            }
            NotificationPreference.isEnabled = granted
            notificationsEnabled = granted
            if granted {
                await SweezyAppDelegate.registerForChatPush()
            }
        } else {
            NotificationPreference.isEnabled = false
            notificationsEnabled = false
            appContainer.notificationService.cancelAllNotifications()
            await SweezyAppDelegate.disableChatPush()
        }
        await refreshState()
    }
}

struct ThemeSettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "system"
    
    var body: some View {
        List {
            ForEach(["system", "light", "dark"], id: \.self) { theme in
                HStack {
                    Text(theme == "system" ? "settings.theme.system".localized : theme == "light" ? "settings.theme.light".localized : "settings.theme.dark".localized)
                    Spacer()
                    if selectedTheme == theme {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTheme = theme
                }
            }
        }
        .journeyForm()
        .navigationTitle("settings.theme.title".localized)
        .journeyScreen(.city, darkness: 0.72)
    }
}

// MARK: - Tab switching notification
extension Notification.Name {
    static let switchTab = Notification.Name("SwitchTab")
    static let setJourneyBottomBarHidden = Notification.Name("SetJourneyBottomBarHidden")
}

#Preview {
    let lockManager = AppLockManager()
    lockManager.userEmail = "preview@sweezy.app"
    lockManager.userName = "Preview"
    lockManager.isRegistered = true
    
    return MainTabView()
        .environmentObject(AppContainer())
        .environmentObject(lockManager)
        .environmentObject(ThemeManager())
        .environmentObject(SessionManager(lockManager: lockManager))
}
