//
//  MapView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI
import MapKit
import Network

struct MapView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @State private var selectedPlaceType: PlaceType?
    @State private var selectedPlace: Place?
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var offlineCache = OfflineMapCacheService()
    @State private var showingLocationPermissionAlert = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.8182, longitude: 8.2275),
            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
        )
    )
    // Collapsing map header on list scroll
    @State private var scrollOffset: CGFloat = 0
    private let mapExpandedHeight: CGFloat = 320
    private let mapCollapsedHeight: CGFloat = 140
    private var mapCurrentHeight: CGFloat {
        let delta = min(max(scrollOffset, 0), mapExpandedHeight - mapCollapsedHeight)
        return mapExpandedHeight - delta
    }
    
    private var filteredPlaces: [Place] {
        let places = appContainer.contentService.places
        
        if let type = selectedPlaceType {
            return places.filter { $0.type == type }
        }
        
        return places
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                // Track scroll offset for collapsing behavior
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("mapScroll")).minY)
                }
                .frame(height: 0)
                
                VStack(spacing: Theme.Spacing.md) {
                    // Winter-styled header (always festive on Map page)
                    WinterMapHeader(title: "map.title".localized)
                    
                    // Filters
                    filtersSection
                    
                    // Map or placeholder (collapsible)
                    Group {
                        if networkMonitor.isOnline || !offlineCache.hasSnapshot() {
                            mapSection
                        } else if let img = offlineCache.loadSnapshot() {
                            // Offline fallback snapshot
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: mapCurrentHeight)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                        .stroke(Theme.Colors.chipBorder, lineWidth: 1)
                                )
                                .padding(.horizontal, Theme.Spacing.md)
                        } else {
                            mapSection
                        }
                    }
                        .animation(Theme.Animation.smooth, value: mapCurrentHeight)
                    
                    // Places list
                    placesListSection
                }
            }
            .coordinateSpace(name: "mapScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minY in
                let offset = max(0, -minY)
                scrollOffset = min(offset, mapExpandedHeight - mapCollapsedHeight)
            }
            .navigationTitle("map.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .background(
                ZStack {
                    // Deep winter gradient background (always festive on Map page)
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.1, blue: 0.2),
                            Color(red: 0.08, green: 0.15, blue: 0.28),
                            Color(red: 0.06, green: 0.12, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    // Subtle snowfall (lightweight, won't affect performance)
                    WinterSceneLite(intensity: .light)
                }
            )
            .onAppear {
                requestLocationPermission()
            }
            .featureOnboarding(.map)
        }
    }
    
    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                WinterFilterChip(
                    title: "common.all".localized,
                    icon: "square.grid.2x2",
                    isSelected: selectedPlaceType == nil
                ) {
                    selectedPlaceType = nil
                }
                
                ForEach(PlaceType.allCases, id: \.self) { type in
                    WinterFilterChip(
                        title: type.localizedName,
                        icon: type.iconName,
                        isSelected: selectedPlaceType == type
                    ) {
                        selectedPlaceType = selectedPlaceType == type ? nil : type
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(Color.clear) // Transparent to show winter background
    }
    
    private var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition, selection: $selectedPlace) {
                ForEach(filteredPlaces) { place in
                    let coord = place.coordinate.clLocationCoordinate
                    Annotation(place.name, coordinate: coord) {
                        WinterMapPin(place: place)
                            .onTapGesture {
                                selectedPlace = place
                            }
                    }
                    .tag(place)
                }
            }
            .frame(height: mapCurrentHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .overlay(
                // Winter frost border (always active on Map page)
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.6), Color.white.opacity(0.3), Color.cyan.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: Color.cyan.opacity(0.3), radius: 10, y: 4)
            .sheet(item: $selectedPlace) { place in
                WinterPlaceBottomSheet(place: place)
                    .presentationDetents([.height(320), .medium])
                    .presentationDragIndicator(.visible)
            }
            
            // Floating action buttons
            VStack(spacing: 12) {
                // Save offline button
                WinterMapButton(
                    icon: offlineCache.hasSnapshot() ? "arrow.down.circle.fill" : "arrow.down.circle",
                    color: Theme.Colors.ukrainianBlue
                ) {
                    Task { await saveOfflineSnapshot() }
                }
                
                // Use My Location button
                WinterMapButton(
                    icon: "location.fill",
                    color: Color.cyan
                ) {
                    centerOnUserLocation()
                }
            }
            .padding([.bottom, .trailing], 16)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .overlay(
            // Empty state on top of map if no places
            Group {
                if filteredPlaces.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.slash")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.5))
                        Text("map.no_places".localized)
                            .font(Theme.Typography.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                }
            }
        )
    }
    
    private var placesListSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "snowflake")
                        .font(.caption)
                        .foregroundColor(.cyan.opacity(0.7))
                    Text("map.nearby_services".localized)
                        .font(Theme.Typography.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("\(filteredPlaces.count) places")
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.15))
                    )
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            Group {
                if appContainer.contentService.isLoading {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(0..<4, id: \.self) { _ in
                            WinterPlaceShimmer()
                                .padding(.horizontal, Theme.Spacing.md)
                        }
                    }
                } else if filteredPlaces.isEmpty {
                    WinterEmptyState(
                        icon: "mappin.slash",
                        title: "map.nearby_services".localized,
                        subtitle: "guides.no_results_subtitle".localized
                    )
                } else {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(filteredPlaces) { place in
                            WinterPlaceCard(place: place)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
            }
        }
        .background(Color.clear) // Transparent to show winter background
    }
    
    private func requestLocationPermission() {
        appContainer.locationService.requestLocationPermission()
    }
    
    private func centerOnUserLocation() {
        guard let location = appContainer.locationService.currentLocation else {
            showingLocationPermissionAlert = true
            return
        }
        withAnimation {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            cameraPosition = .region(region)
        }
    }
    
    private func saveOfflineSnapshot() async {
        // Snapshot around either the selected place, user location, or Switzerland fallback.
        let center: CLLocationCoordinate2D = {
            if let place = selectedPlace {
                return place.coordinate.clLocationCoordinate
            } else if let loc = appContainer.locationService.currentLocation?.coordinate {
                return loc
            } else {
                return CLLocationCoordinate2D(latitude: 46.8182, longitude: 8.2275)
            }
        }()
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
        )
        await offlineCache.saveSnapshot(center: region.center, span: region.span)
    }
}

// MARK: - Scroll Offset Preference
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Place Bottom Sheet
struct PlaceBottomSheet: View {
    let place: Place
    @EnvironmentObject private var appContainer: AppContainer
    @State private var etaText: String?
    @State private var isCalculating = false
    @State private var liveWait: Int?
    @State private var liveBusy: String?
    
    private var todayHoursLine: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        if let hours = place.openingHours.first(where: { $0.weekday == weekday }) {
            if hours.isClosed { return NSLocalizedString("Closed today", comment: "") }
            return "\(hours.weekdayName): \(hours.openTime.formatted) – \(hours.closeTime.formatted)"
        }
        return NSLocalizedString("Hours unavailable", comment: "")
    }
    
    private var openNowLine: (text: String, color: Color) {
        if place.isOpen() {
            return (NSLocalizedString("Open now", comment: ""), .green)
        } else {
            return (NSLocalizedString("Closed", comment: ""), .red)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            HStack {
                Image(systemName: place.type.iconName)
                    .font(.title2)
                    .foregroundColor(place.type.swiftUIColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(Theme.Typography.headline)
                    Text(place.type.localizedName)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer()
            }
            .padding(.top, Theme.Spacing.md)
            
            // Hours
            HStack(spacing: 8) {
                Circle().fill(openNowLine.color).frame(width: 8, height: 8)
                Text(openNowLine.text)
                    .font(Theme.Typography.caption)
                    .foregroundColor(openNowLine.color)
                Text("·")
                    .foregroundColor(Theme.Colors.tertiaryText)
                Text(todayHoursLine)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                if let liveWait {
                    Text("·")
                        .foregroundColor(Theme.Colors.tertiaryText)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("\(liveWait) min")
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            
            // Address
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Theme.Colors.secondaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(place.address.street) \(place.address.houseNumber)")
                    Text("\(place.address.postalCode) \(place.address.city)")
                }
                .font(Theme.Typography.caption)
            }
            
            // Contact
            HStack(spacing: Theme.Spacing.md) {
                if let phone = place.phoneNumber {
                    Button {
                        if let url = URL(string: "tel:\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("map.call".localized, systemImage: "phone.fill")
                            .font(Theme.Typography.caption)
                    }
                    .buttonStyle(.bordered)
                }
                
                if let website = place.website {
                    Button {
                        if let url = URL(string: website) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("map.website".localized, systemImage: "safari.fill")
                            .font(Theme.Typography.caption)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button {
                    Task { await computeETA() }
                } label: {
                    if let etaText {
                        Label(etaText, systemImage: "car.fill")
                            .font(Theme.Typography.caption)
                    } else if isCalculating {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Label("ETA", systemImage: "car.fill")
                            .font(Theme.Typography.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .onAppear {
            Task { await computeETA() }
            Task { await fetchLiveStatus() }
        }
    }
    
    private func computeETA() async {
        guard let userLoc = appContainer.locationService.currentLocation else { return }
        isCalculating = true
        defer { isCalculating = false }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLoc.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate.clLocationCoordinate))
        request.transportType = .automobile
        do {
            let result = try await MKDirections(request: request).calculateETA()
            let minutes = max(1, Int(result.expectedTravelTime / 60))
            etaText = "\(minutes) min"
        } catch {
            etaText = nil
        }
    }
    
    private func fetchLiveStatus() async {
        let status = await APIClient.fetchPlaceLiveStatus(
            name: place.name,
            category: place.category.rawValue,
            canton: place.canton.rawValue,
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude
        )
        if let status {
            liveWait = status.wait_minutes
            liveBusy = status.busy_level
            // If Overpass provided raw opening_hours text and we don't have local hours, we could surface it later
        }
    }
}

struct PlaceCard: View {
    let place: Place
    
    private var openBadge: some View {
        Group {
            if place.isOpen() {
                Text("Open")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Text("Closed")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(place.name)
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Text(place.type.localizedName)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                        
                        HStack(spacing: 6) {
                            openBadge
                            if let today = place.openingHours.first(where: { $0.weekday == Calendar.current.component(.weekday, from: Date()) }) {
                                Text("\(today.openTime.formatted)–\(today.closeTime.formatted)")
                                    .font(Theme.Typography.caption2)
                                    .foregroundColor(Theme.Colors.tertiaryText)
                            }
                        }
                        
                        if let description = place.description {
                            Text(description)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.tertiaryText)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: place.type.iconName)
                        .font(.title2)
                        .foregroundColor(place.type.swiftUIColor)
                }
                
                // Address
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "location")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                    
                    Text(place.formattedAddress)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
                
                // Actions
                HStack(spacing: Theme.Spacing.md) {
                    if let phone = place.phoneNumber {
                        Button(action: {
                            if let url = URL(string: "tel:\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "phone")
                                Text("map.call".localized)
                            }
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.ukrainianBlue)
                        }
                    }
                    
                    if let website = place.website {
                        Button(action: {
                            if let url = URL(string: website) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "globe")
                                Text("map.website".localized)
                            }
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.ukrainianBlue)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Open in Maps app
                        let coordinate = place.coordinate.clLocationCoordinate
                        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                        mapItem.name = place.name
                        mapItem.openInMaps()
                    }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond")
                            Text("map.directions".localized)
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.ukrainianBlue)
                    }
                }
            }
        }
    }
}

struct PlaceShimmerRow: View {
    @State private var animate = false
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 14)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .overlay(
            LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.3), Color.white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .rotationEffect(.degrees(30))
                .offset(x: animate ? 400 : -400)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// MARK: - Winter Themed Components

struct WinterMapHeader: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Decorative snowflake
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.5), Color.white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "map.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.cyan)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text("Знайди потрібне місце")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Winter decoration
            HStack(spacing: 4) {
                Image(systemName: "snowflake")
                    .font(.caption)
                    .foregroundColor(.cyan.opacity(0.6))
                Image(systemName: "snowflake")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

struct WinterFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ))
                    : AnyShapeStyle(Color.white.opacity(0.08))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.cyan.opacity(0.3) : Color.clear, radius: 6, y: 2)
        }
        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
    }
}

struct WinterMapPin: View {
    let place: Place
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(Color.cyan.opacity(0.2))
                .frame(width: 40, height: 40)
                .blur(radius: 4)
            
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), place.type.swiftUIColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 34, height: 34)
            
            // Border
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.cyan.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: 34, height: 34)
            
            // Icon
            Image(systemName: place.type.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct WinterMapButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [color.opacity(0.9), color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.4), radius: 8, y: 4)
        }
    }
}

struct WinterPlaceCard: View {
    let place: Place
    
    private var openBadge: some View {
        Group {
            if place.isOpen() {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Open")
                        .font(Theme.Typography.caption2)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.green.opacity(0.2)))
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("Closed")
                        .font(Theme.Typography.caption2)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.red.opacity(0.2)))
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                // Icon with winter styling
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [place.type.swiftUIColor.opacity(0.3), place.type.swiftUIColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                    Circle()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: place.type.iconName)
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(place.type.localizedName)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 6) {
                        openBadge
                        if let today = place.openingHours.first(where: { $0.weekday == Calendar.current.component(.weekday, from: Date()) }) {
                            Text("\(today.openTime.formatted)–\(today.closeTime.formatted)")
                                .font(Theme.Typography.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
            }
            
            if let description = place.description {
                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }
            
            // Address
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.cyan.opacity(0.7))
                
                Text(place.formattedAddress)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Actions
            HStack(spacing: Theme.Spacing.md) {
                if let phone = place.phoneNumber {
                    WinterActionButton(icon: "phone.fill", title: "map.call".localized) {
                        if let url = URL(string: "tel:\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                if let website = place.website {
                    WinterActionButton(icon: "globe", title: "map.website".localized) {
                        if let url = URL(string: website) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                Spacer()
                
                WinterActionButton(icon: "arrow.triangle.turn.up.right.diamond.fill", title: "map.directions".localized, isPrimary: true) {
                    let coordinate = place.coordinate.clLocationCoordinate
                    let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                    mapItem.name = place.name
                    mapItem.openInMaps()
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.cyan.opacity(0.1), radius: 8, y: 4)
    }
}

struct WinterActionButton: View {
    let icon: String
    let title: String
    var isPrimary: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(isPrimary ? .white : .cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isPrimary
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ))
                    : AnyShapeStyle(Color.cyan.opacity(0.15))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isPrimary ? Color.cyan.opacity(0.5) : Color.cyan.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct WinterPlaceShimmer: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Color.cyan.opacity(0.1))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cyan.opacity(0.1))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: 160, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cyan.opacity(0.05))
                    .frame(width: 100, height: 12)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
        )
        .overlay(
            LinearGradient(
                colors: [Color.clear, Color.cyan.opacity(0.2), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(30))
            .offset(x: animate ? 400 : -400)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

struct WinterEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.cyan.opacity(0.6))
            }
            
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }
}

// MARK: - Winter Place Bottom Sheet

struct WinterPlaceBottomSheet: View {
    let place: Place
    @EnvironmentObject private var appContainer: AppContainer
    @State private var etaText: String?
    @State private var isCalculating = false
    @State private var liveWait: Int?
    @State private var liveBusy: String?
    
    private var todayHoursLine: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        if let hours = place.openingHours.first(where: { $0.weekday == weekday }) {
            if hours.isClosed { return NSLocalizedString("Closed today", comment: "") }
            return "\(hours.weekdayName): \(hours.openTime.formatted) – \(hours.closeTime.formatted)"
        }
        return NSLocalizedString("Hours unavailable", comment: "")
    }
    
    private var openNowLine: (text: String, color: Color) {
        if place.isOpen() {
            return (NSLocalizedString("Open now", comment: ""), .green)
        } else {
            return (NSLocalizedString("Closed", comment: ""), .red)
        }
    }
    
    var body: some View {
        ZStack {
            // Winter background (always active on Map page)
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color(red: 0.08, green: 0.15, blue: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [place.type.swiftUIColor.opacity(0.3), place.type.swiftUIColor.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 56, height: 56)
                        Circle()
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: place.type.iconName)
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(Theme.Typography.headline)
                            .foregroundColor(.white)
                        Text(place.type.localizedName)
                            .font(Theme.Typography.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.top, Theme.Spacing.md)
                
                // Hours
                HStack(spacing: 8) {
                    Circle().fill(openNowLine.color).frame(width: 8, height: 8)
                    Text(openNowLine.text)
                        .font(Theme.Typography.caption)
                        .foregroundColor(openNowLine.color)
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text(todayHoursLine)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    if let liveWait {
                        Text("·")
                            .foregroundColor(.white.opacity(0.3))
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("\(liveWait) min")
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(.cyan.opacity(0.8))
                    }
                }
                
                // Address
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.cyan.opacity(0.7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(place.address.street) \(place.address.houseNumber)")
                        Text("\(place.address.postalCode) \(place.address.city)")
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
                
                // Contact buttons
                HStack(spacing: Theme.Spacing.sm) {
                    if let phone = place.phoneNumber {
                        WinterSheetButton(icon: "phone.fill", title: "map.call".localized) {
                            if let url = URL(string: "tel:\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    
                    if let website = place.website {
                        WinterSheetButton(icon: "safari.fill", title: "map.website".localized) {
                            if let url = URL(string: website) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    
                    WinterSheetButton(
                        icon: "car.fill",
                        title: etaText ?? "ETA",
                        isLoading: isCalculating,
                        isPrimary: true
                    ) {
                        Task { await computeETA() }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .onAppear {
            Task { await computeETA() }
            Task { await fetchLiveStatus() }
        }
    }
    
    private func computeETA() async {
        guard let userLoc = appContainer.locationService.currentLocation else { return }
        isCalculating = true
        defer { isCalculating = false }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLoc.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate.clLocationCoordinate))
        request.transportType = .automobile
        do {
            let result = try await MKDirections(request: request).calculateETA()
            let minutes = max(1, Int(result.expectedTravelTime / 60))
            etaText = "\(minutes) min"
        } catch {
            etaText = nil
        }
    }
    
    private func fetchLiveStatus() async {
        let status = await APIClient.fetchPlaceLiveStatus(
            name: place.name,
            category: place.category.rawValue,
            canton: place.canton.rawValue,
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude
        )
        if let status {
            liveWait = status.wait_minutes
            liveBusy = status.busy_level
        }
    }
}

struct WinterSheetButton: View {
    let icon: String
    let title: String
    var isLoading: Bool = false
    var isPrimary: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(Theme.Typography.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isPrimary ? .white : .cyan)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isPrimary
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ))
                    : AnyShapeStyle(Color.white.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPrimary ? Color.cyan.opacity(0.5) : Color.cyan.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    MapView()
        .environmentObject(AppContainer())
}
