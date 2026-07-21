import MapKit
import SwiftUI

struct JourneyMapView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.openURL) private var openURL

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
            distance: 6_800,
            heading: 18,
            pitch: 72
        )
    )
    @State private var selectedType: PlaceType?
    @State private var selectedPlace: Place?
    @State private var searchText = ""
    @State private var activeRoute: MKRoute?
    @State private var isCalculatingRoute = false
    @State private var showsPlaceList = false

    private let filters: [(PlaceType?, String, String)] = [
        (nil, "Усі", "square.grid.2x2"),
        (.government, "Установи", "building.columns"),
        (.healthcare, "Здоров’я", "cross.case"),
        (.education, "Освіта", "graduationcap"),
        (.employment, "Робота", "briefcase"),
        (.community, "Спільнота", "person.2")
    ]

    var body: some View {
        ZStack {
            mapLayer
            mapReadabilityGradient

            VStack(spacing: 10) {
                topControls
                filterBar
                Spacer(minLength: 16)
                nearbyPlacesRail
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 108)
        }
        .task {
            if appContainer.contentService.places.isEmpty {
                await appContainer.contentService.refreshContent()
            }
            appContainer.locationService.requestLocationPermission()
            appContainer.locationService.startLocationUpdates()
            selectFirstVisiblePlace()
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
        }
        .sheet(isPresented: $showsPlaceList) {
            placeListSheet
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            if let activeRoute {
                MapPolyline(activeRoute.polyline)
                    .stroke(
                        JourneyVisual.lime,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
            }

            UserAnnotation()

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
        .mapStyle(.imagery(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .ignoresSafeArea()
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
            JourneySearchField(text: $searchText, prompt: "Пошук на карті")

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
            .accessibilityLabel("Показати список місць")
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.1) { type, title, icon in
                    JourneyFilterChip(title: title, icon: icon, isSelected: selectedType == type) {
                        applyFilter(type)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 1, for: .scrollContent)
    }

    private var nearbyPlacesRail: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Text(selectedType == nil ? "Поруч із вами" : filterTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("\(displayedPlaces.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 23)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())

                Spacer()

                Button("Усі місця") {
                    showsPlaceList = true
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.78))
            }
            .shadow(color: .black.opacity(0.65), radius: 6, y: 2)

            if displayedPlaces.isEmpty {
                emptyPlacesCard
            } else {
                placeCarousel
            }
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
        .frame(height: 170)
    }

    private var emptyPlacesCard: some View {
        JourneyGlassPanel(cornerRadius: 24) {
            HStack(spacing: 13) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(JourneyVisual.lime)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Нічого не знайдено")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Змініть пошук або виберіть іншу категорію")
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
                    .frame(width: 118, height: 170)
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
                    .frame(height: 25)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
                    .padding(10)
            }
            .frame(width: 118, height: 170)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(place.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        appContainer.savedItems.togglePlace(place.id)
                    } label: {
                        Image(systemName: appContainer.savedItems.isPlaceSaved(place.id) ? "heart.fill" : "heart")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(appContainer.savedItems.isPlaceSaved(place.id) ? JourneyVisual.lime : .white.opacity(0.72))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Зберегти місце")
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
                            Text("Маршрут")
                                .lineLimit(1)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 39)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if let bookingURL = bookingURL(for: place) {
                        Button {
                            openURL(bookingURL)
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 39, height: 39)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Записатися")
                    }
                }
            }
            .padding(12)
        }
        .frame(height: 170)
        .background(.ultraThinMaterial.opacity(0.84))
        .background(Color(red: 0.035, green: 0.075, blue: 0.05).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.44), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.42), radius: 22, y: 10)
        .onTapGesture {
            focus(on: place)
        }
    }

    private var placeListSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.025, green: 0.045, blue: 0.032)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 11) {
                        ForEach(displayedPlaces) { place in
                            placeListRow(place)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Місця поруч")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
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

    private var filterTitle: String {
        filters.first(where: { $0.0 == selectedType })?.1 ?? "Поруч із вами"
    }

    private func applyFilter(_ type: PlaceType?) {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedType = type
            activeRoute = nil
        }
        selectFirstVisiblePlace()
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

    private func focus(on place: Place) {
        selectedPlace = place
        withAnimation(.easeInOut(duration: 0.3)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: place.coordinate.clLocationCoordinate,
                    distance: 3_600,
                    heading: 18,
                    pitch: 72
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
        case .government: return "Установа"
        case .healthcare: return "Здоров’я"
        case .education: return "Освіта"
        case .employment: return "Робота"
        case .community, .social: return "Спільнота"
        case .housing: return "Житло"
        case .legal: return "Право"
        case .transport: return "Транспорт"
        case .banking: return "Фінанси"
        case .shopping: return "Покупки"
        case .emergency: return "Допомога"
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
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate.clLocationCoordinate))
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
        if meters < 1_000 { return "\(Int(meters.rounded())) м" }
        return String(format: "%.1f км", meters / 1_000)
    }

    private func locationLine(for place: Place) -> String {
        let city = place.address.city.trimmingCharacters(in: .whitespacesAndNewlines)
        return city.isEmpty ? place.canton.localizedName : "\(city) · \(place.canton.rawValue)"
    }

    private func todayHours(for place: Place) -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        guard let hours = place.openingHours.first(where: { $0.weekday == weekday }) else {
            return "Години уточнюються"
        }
        if hours.isClosed { return "Сьогодні зачинено" }
        let prefix = place.isOpen() ? "Відкрито" : "Сьогодні"
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
