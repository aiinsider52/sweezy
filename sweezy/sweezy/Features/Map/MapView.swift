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
    private let mapExpandedHeight: CGFloat = 380
    private let mapCollapsedHeight: CGFloat = 168
    private var mapCurrentHeight: CGFloat {
        let delta = min(max(scrollOffset, 0), mapExpandedHeight - mapCollapsedHeight)
        return mapExpandedHeight - delta
    }
    private var mapCollapseProgress: CGFloat {
        let range = max(1, mapExpandedHeight - mapCollapsedHeight)
        return min(max(scrollOffset / range, 0), 1)
    }
    private var mapHeroOpacity: CGFloat {
        max(0, 1 - (mapCollapseProgress * 1.45))
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
                
                VStack(spacing: 0) {
                    // Filters (compact horizontal scroll)
                    filtersSection
                        .padding(.top, Theme.Spacing.sm)
                    
                    // Map or placeholder (collapsible)
                    Group {
                        if networkMonitor.isOnline || !offlineCache.hasSnapshot() {
                            mapSection
                        } else if let img = offlineCache.loadSnapshot() {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: mapCurrentHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(colors: [Theme.Colors.primary.opacity(0.5), Color.white.opacity(0.15)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                                            lineWidth: 1.5
                                        )
                                )
                                .padding(.horizontal, Theme.Spacing.md)
                        } else {
                            mapSection
                        }
                    }
                    .animation(.spring(response: 0.36, dampingFraction: 0.86), value: mapCurrentHeight)
                    .padding(.top, Theme.Spacing.sm)
                    
                    // Places list
                    placesListSection
                        .padding(.top, Theme.Spacing.md)
                }
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .coordinateSpace(name: "mapScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minY in
                let offset = max(0, -minY)
                scrollOffset = min(offset, mapExpandedHeight - mapCollapsedHeight)
            }
            .navigationTitle("map.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
            .onAppear {
                requestLocationPermission()
            }
            .featureOnboarding(.map)
        }
        .journeyScreen(.city, darkness: 0.7)
    }
    
    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MapPillFilterChip(
                    title: "common.all".localized,
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedPlaceType == nil
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedPlaceType = nil
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                
                ForEach(PlaceType.allCases, id: \.self) { type in
                    MapPillFilterChip(
                        title: type.localizedName,
                        icon: type.iconName,
                        isSelected: selectedPlaceType == type,
                        accentColor: type.swiftUIColor
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedPlaceType = selectedPlaceType == type ? nil : type
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
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
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                // Elegant frost border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.Colors.primary.opacity(0.55), Color.white.opacity(0.2), Theme.Colors.primary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Theme.Colors.primary.opacity(0.25), radius: 16, y: 6)
            .sheet(item: $selectedPlace) { place in
                WinterPlaceBottomSheet(place: place)
                    .presentationDetents([.height(340), .medium])
                    .presentationDragIndicator(.visible)
            }

            mapHeroOverlay
                .opacity(mapHeroOpacity)
                .allowsHitTesting(false)
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
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
                    color: Theme.Colors.primary
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

    private var mapHeroOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Знайдіть потрібний сервіс швидше")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)

            Text("Показуємо найближчі відкриті місця та корисні категорії без зайвого шуму.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.84)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        }
        .frame(maxWidth: 300, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.26))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
    }
    
    private var placesListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header — count badge + title
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("map.nearby_services".localized)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Count badge
                if !filteredPlaces.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.primary)
                        Text("\(filteredPlaces.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.Colors.primary.opacity(0.18))
                            .overlay(Capsule().stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 1))
                    )
                }
            }
            .padding(.horizontal, 16)
            
            // Content
            if appContainer.contentService.isLoading {
                VStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        WinterPlaceShimmer()
                            .padding(.horizontal, 16)
                    }
                }
            } else if filteredPlaces.isEmpty {
                WinterEmptyState(
                    icon: "mappin.slash",
                    title: "map.nearby_services".localized,
                    subtitle: "guides.no_results_subtitle".localized
                )
            } else {
                // Beautiful rounded card container
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredPlaces.enumerated()), id: \.element.id) { index, place in
                        WinterPlaceRow(place: place)
                        
                        if index < filteredPlaces.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                                .padding(.leading, 78)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Theme.Colors.primary.opacity(0.35), Color.white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
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
                        .foregroundColor(Theme.Colors.textSecondary)
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
                    .foregroundColor(Theme.Colors.textTertiary)
                Text(todayHoursLine)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                if let liveWait {
                    Text("·")
                        .foregroundColor(Theme.Colors.textTertiary)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("\(liveWait) min")
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            
            // Address
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Theme.Colors.textSecondary)
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
        .journeyScreen(.city, darkness: 0.72)
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
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Text(place.type.localizedName)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        HStack(spacing: 6) {
                            openBadge
                            if let today = place.openingHours.first(where: { $0.weekday == Calendar.current.component(.weekday, from: Date()) }) {
                                Text("\(today.openTime.formatted)–\(today.closeTime.formatted)")
                                    .font(Theme.Typography.caption2)
                                    .foregroundColor(Theme.Colors.textTertiary)
                            }
                        }
                        
                        if let description = place.description {
                            Text(description)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
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
                        .foregroundColor(Theme.Colors.textTertiary)
                    
                    Text(place.formattedAddress)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textTertiary)
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

// MARK: - Map Filter Chip (new, replaces WinterFilterChip for map page)

struct MapPillFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var accentColor: Color = Theme.Colors.primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .white : accentColor.opacity(0.8))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected
                        ? LinearGradient(
                            colors: [accentColor.opacity(0.55), accentColor.opacity(0.35)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(
                            colors: [Color.white.opacity(0.09), Color.white.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: isSelected ? accentColor.opacity(0.35) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Compact Place Row (beautiful iOS-style row inside grouped card)

struct WinterPlaceRow: View {
    let place: Place
    @State private var showDetail = false
    
    private var isOpen: Bool { place.isOpen() }
    
    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 14) {
                // Colored icon square
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    place.type.swiftUIColor.opacity(0.35),
                                    place.type.swiftUIColor.opacity(0.18)
                                ],
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(place.type.localizedName)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    // Status dot + text
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isOpen ? Color.green : Color(red: 1.0, green: 0.35, blue: 0.35))
                            .frame(width: 6, height: 6)
                        Text(isOpen ? "map.open".localized : "map.closed".localized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isOpen ? Color.green : Color(red: 1.0, green: 0.42, blue: 0.42))
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlaceRowPressStyle())
        .sheet(isPresented: $showDetail) {
            WinterPlaceBottomSheet(place: place)
                .presentationDetents([.height(340), .medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct PlaceRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed
                ? Color.white.opacity(0.06)
                : Color.clear)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Legacy WinterFilterChip (kept for compatibility)
struct WinterFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        MapPillFilterChip(title: title, icon: icon, isSelected: isSelected, action: action)
    }
}

struct WinterMapPin: View {
    let place: Place
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(Theme.Colors.primary.opacity(0.2))
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
                        colors: [Color.white.opacity(0.6), Theme.Colors.primary.opacity(0.4)],
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
                        .stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 1)
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    
                    Text(place.type.localizedName)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                    
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
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Address
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.primary.opacity(0.7))
                
                Text(place.formattedAddress)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
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
                .fill(Theme.Colors.adaptiveCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(
                    LinearGradient(
                        colors: [Theme.Colors.primary.opacity(0.3), Theme.Colors.adaptiveSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Theme.Colors.primary.opacity(0.1), radius: 8, y: 4)
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
            .foregroundColor(isPrimary ? .white : Theme.Colors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isPrimary
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Theme.Colors.primaryLight.opacity(0.8), Theme.Colors.primary.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ))
                    : AnyShapeStyle(Theme.Colors.primary.opacity(0.15))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isPrimary ? Theme.Colors.primary.opacity(0.5) : Theme.Colors.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct WinterPlaceShimmer: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Theme.Colors.primary.opacity(0.1))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.primary.opacity(0.1))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.primary.opacity(0.08))
                    .frame(width: 160, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.primary.opacity(0.05))
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
                .stroke(Theme.Colors.primary.opacity(0.15), lineWidth: 1)
        )
        .overlay(
            LinearGradient(
                colors: [Color.clear, Theme.Colors.primary.opacity(0.2), Color.clear],
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
                    .fill(Theme.Colors.primary.opacity(0.1))
                    .frame(width: 80, height: 80)
                Circle()
                    .stroke(Theme.Colors.primary.opacity(0.25), lineWidth: 1)
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(Theme.Colors.primary.opacity(0.7))
            }
            
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
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
            JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 8, darkness: 0.74)
            
            VStack(alignment: .leading, spacing: 0) {
                // Drag handle area
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [place.type.swiftUIColor.opacity(0.4), place.type.swiftUIColor.opacity(0.2)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)
                        
                        Image(systemName: place.type.iconName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(place.type.swiftUIColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                        Text(place.type.localizedName)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 20)
                
                // Status row
                HStack(spacing: 8) {
                    Circle().fill(openNowLine.color).frame(width: 8, height: 8)
                    Text(openNowLine.text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(openNowLine.color)
                    Text("·")
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text(todayHoursLine)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    if let liveWait {
                        Text("·")
                            .foregroundColor(Theme.Colors.textSecondary)
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("\(liveWait) min")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.primary)
                    }
                }
                .padding(.bottom, 16)
                
                // Address card
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(place.address.street) \(place.address.houseNumber)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("\(place.address.postalCode) \(place.address.city)")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.Colors.adaptiveCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: 1)
                        )
                )
                .padding(.bottom, 20)
                
                // Action buttons
                HStack(spacing: 10) {
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
            .padding(.horizontal, 20)
        }
        .journeyScreen(.city, darkness: 0.74)
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
                        .tint(isPrimary ? Theme.Colors.textOnPrimary : Theme.Colors.primary)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isPrimary ? Theme.Colors.textOnPrimary : Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                isPrimary
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Theme.Colors.primaryLight, Theme.Colors.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ))
                    : AnyShapeStyle(Theme.Colors.adaptiveCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isPrimary ? Theme.Colors.primary.opacity(0.4) : Theme.Colors.adaptiveBorder.opacity(0.6),
                        lineWidth: 1
                    )
            )
            .shadow(color: isPrimary ? Theme.Colors.primary.opacity(0.3) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MapView()
        .environmentObject(AppContainer())
}
