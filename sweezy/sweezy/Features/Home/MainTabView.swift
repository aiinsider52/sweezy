//
//  MainTabView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI
import MapKit

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var requestedDovidnykSection: DovidnykRouteSection? = nil
    @State private var requestedDovidnykRouteID = UUID()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0 - Home
            HomeViewRedesigned()
                .tabItem {
                    Label {
                        Text("tab.home".localized)
                    } icon: {
                        NewYearTabIcon(baseSystemName: "house.fill", isSelected: selectedTab == 0)
                    }
                }
                .tag(0)
            
            // Tab 1 - Довідник (Guides + Checklists unified)
            LazyDovidnykWrapper(
                requestedSection: requestedDovidnykSection,
                routeID: requestedDovidnykRouteID
            )
                .tabItem {
                    Label {
                        Text("guides.title".localized)
                    } icon: {
                        NewYearTabIcon(baseSystemName: "book.fill", isSelected: selectedTab == 1)
                    }
                }
                .tag(1)
            
            // Tab 2 - Map
            LazyMapWrapper(isSelected: selectedTab == 2)
                .tabItem {
                    Label {
                        Text("map.title".localized)
                    } icon: {
                        NewYearTabIcon(baseSystemName: "map.fill", isSelected: selectedTab == 2)
                    }
                }
                .tag(2)
            
            // Tab 3 - Marketplace
            MarketplaceView()
                .tabItem {
                    Label {
                        Text("marketplace.tab".localized)
                    } icon: {
                        NewYearTabIcon(baseSystemName: "bag.fill", isSelected: selectedTab == 3)
                    }
                }
                .tag(3)
            
            // Tab 4 - Settings
            SettingsView()
                .tabItem {
                    Label {
                        Text("settings.title".localized)
                    } icon: {
                        NewYearTabIcon(baseSystemName: "gearshape.fill", isSelected: selectedTab == 4)
                    }
                }
                .tag(4)
        }
        .onAppear {
            AppLogger.ui("MainTabView appeared")
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { output in
            if let payload = output.object as? SwitchTabPayload {
                selectedTab = payload.tab
                if payload.tab == 1 {
                    requestedDovidnykSection = payload.section
                    requestedDovidnykRouteID = payload.routeID
                }
            } else if let index = output.object as? Int {
                selectedTab = index
            }
        }
    }
}

enum DovidnykRouteSection: String {
    case guides
    case checklists
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
            .background(
                LinearGradient(
                    colors: [
                        Theme.Colors.primaryDark,
                        Theme.Colors.primary.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("map.title_short".localized)
        }
    }
}

// MARK: - Optimized Map View (full functionality, optimized performance)
struct OptimizedMapView: View {
    @EnvironmentObject private var appContainer: AppContainer
    
    // Режим диапазона: только рядом или все сервисы
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
            center: CLLocationCoordinate2D(latitude: 46.8182, longitude: 8.2275), // Switzerland center
            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
        )
    )
    @State private var rangeMode: RangeMode = .nearby
    
    /// Радиус "поруч" — 10 км
    private let nearbyRadiusMeters: Double = 10_000
    
    private var filteredPlaces: [Place] {
        // Сначала фильтр по типу сервиса
        let typedPlaces: [Place]
        if let type = selectedType {
            typedPlaces = places.filter { $0.type == type }
        } else {
            typedPlaces = places
        }
        
        // Затем — опциональный фильтр "поруч" по геолокации
        guard rangeMode == .nearby,
              let userLocation = appContainer.locationService.currentLocation else {
            return typedPlaces
        }
        
        let userCoord = userLocation.coordinate
        return typedPlaces.filter { place in
            let coord = place.coordinate.clLocationCoordinate
            let distance = distanceMeters(from: userCoord, to: coord)
            return distance <= nearbyRadiusMeters
        }
    }
    
    // Limit annotations for performance
    private var visiblePlaces: [Place] {
        Array(filteredPlaces.prefix(50))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdaptivePageBackground()
                
                VStack(spacing: 0) {
                    // Filters - lightweight horizontal scroll
                    filtersSection
                    
                    // Map section
                    if isLoading {
                        mapLoadingPlaceholder
                    } else {
                        mapSection
                    }
                    
                    // Places list
                    placesListSection
                }
            }
            .navigationTitle("map.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            loadPlacesOnce()
        }
    }
    
    // MARK: - Filters
    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Диапазон: рядом или вся Швейцария
                MapFilterChip(
                    title: "map.range.nearby_10km".localized,
                    isSelected: rangeMode == .nearby,
                    color: .cyan
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
                
                // Разделитель по смыслу: ниже — фильтр по типу сервиса
                MapFilterChip(
                    title: "common.all".localized,
                    isSelected: selectedType == nil,
                    color: .blue
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
    
    // MARK: - Map Loading Placeholder
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
    
    // MARK: - Map Section
    private var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                // Limit annotations to prevent lag
                ForEach(visiblePlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate.clLocationCoordinate) {
                        PlaceAnnotationView(place: place) {
                            selectedPlace = place
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat)) // Flat style is faster
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.45), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.cyan.opacity(0.18), radius: 14, y: 6)
            
            // Location button
            Button {
                centerOnUserLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue.opacity(0.85)],
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
        .sheet(item: $selectedPlace) { place in
            PlaceDetailSheet(place: place)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
    }
    
    // MARK: - Places List
    private var placesListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rangeMode == .nearby ? "map.nearby_services".localized : "map.services".localized)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                if !filteredPlaces.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                        Text("\(filteredPlaces.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.16))
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.25), lineWidth: 1))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if filteredPlaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("map.no_places".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                // Use List for efficient scrolling
                List {
                    ForEach(filteredPlaces.prefix(30)) { place in
                        PlaceLiteRow(place: place)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                selectedPlace = place
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden) // show winter gradient behind list
                .background(Color.clear)
            }
        }
    }
    
    // MARK: - Distance helper
    /// Лёгкая по ресурсам функция для расчёта расстояния между двумя точками (метры)
    private func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadiusKm = 6_371.0
        
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadiusKm * c * 1_000 // в метры
    }
    
    // MARK: - Actions
    private func loadPlacesOnce() {
        guard places.isEmpty else { return }
        
        Task {
            // Quick check first
            let loadedPlaces = appContainer.contentService.places
            if !loadedPlaces.isEmpty {
                await MainActor.run {
                    places = loadedPlaces
                    isLoading = false
                }
                return
            }
            
            // Retry if needed
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
        guard let location = appContainer.locationService.currentLocation else { return }
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
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
            // Winter gradient background
            LinearGradient(
                colors: [
                    Theme.Colors.darkBackground,
                    Theme.Colors.primaryDark.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with icon and status
                    headerSection
                    
                    // Quick info chips
                    quickInfoSection
                    
                    // Description if available
                    if let desc = place.description, !desc.isEmpty {
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
                    infoChip(icon: "location.fill", text: dist, color: .cyan)
                }
                
                // Today's hours
                infoChip(icon: "clock.fill", text: todayHours, color: .orange)
                
                // Languages
                if !place.languages.isEmpty {
                    infoChip(icon: nil, text: languageFlags, color: .purple)
                }
                
                // Accessible
                if place.isAccessible {
                    infoChip(icon: "figure.roll", text: "map.accessible".localized, color: .blue)
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
                .foregroundColor(.cyan)
            
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
                .foregroundColor(.cyan)
            
            FlowLayout(spacing: 8) {
                ForEach(place.services.prefix(6), id: \.self) { service in
                    Text(service)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.cyan.opacity(0.15))
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
                        colors: [Color.cyan, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: .cyan.opacity(0.3), radius: 8, y: 4)
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
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = place.name
        mapItem.openInMaps()
    }
    
    private func calculateDistance() {
        guard let userLoc = appContainer.locationService.currentLocation else { return }
        let distance = place.distance(from: userLoc)
        if distance < 1000 {
            distanceText = "\(Int(distance)) м"
        } else {
            distanceText = String(format: "%.1f км", distance / 1000)
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
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon (compact gradient tile)
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
            
            // Info
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
            }
            
            Spacer()
            
            // Direction button
            Button {
                openInMaps()
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cyan)
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
    
    private func openInMaps() {
        let coordinate = place.coordinate.clLocationCoordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
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
            .background(AdaptivePageBackground())
            .navigationTitle("Sweezy")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        NotificationCenter.default.post(name: .switchTab, object: 4)
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
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
                QuickAction(title: "settings.title".localized, icon: "gearshape.fill", color: .gray, tab: 4)
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
                }
            }
            .navigationTitle("guides.title".localized)
            .searchable(text: $searchText, prompt: Text("guides.search_placeholder".localized))
        }
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
                    
                    // TEMPORARY: IAP removed; do not show subscription-related badges.
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
                }
            }
            .navigationTitle("checklists.title".localized)
        }
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
        .navigationTitle(checklist.title)
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
            .navigationTitle("settings.title".localized)
            .refreshable {
                loadData()
            }
        }
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
            Text("Українська")
            Text("English")
            Text("Deutsch")
        }
        .navigationTitle("settings.language".localized)
    }
}

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    var body: some View {
        List {
            Toggle("settings.notifications".localized, isOn: $notificationsEnabled)
        }
        .navigationTitle("settings.notifications".localized)
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
        .navigationTitle("settings.theme.title".localized)
    }
}

// MARK: - Tab switching notification
extension Notification.Name {
    static let switchTab = Notification.Name("SwitchTab")
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
