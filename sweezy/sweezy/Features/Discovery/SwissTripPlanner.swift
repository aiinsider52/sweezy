import SwiftUI

enum SwissTripTransport: String, CaseIterable, Identifiable {
    case publicTransit, car, walking
    var id: String { rawValue }
    var title: String { ["publicTransit": "Без авто", "car": "Авто", "walking": "Пішки"][rawValue] ?? rawValue }
    var icon: String { self == .car ? "car.fill" : (self == .walking ? "figure.walk" : "tram.fill") }
}

enum SwissTripWeather: String, CaseIterable, Identifiable {
    case any, sun, rain, snow
    var id: String { rawValue }
    var title: String { ["any": "Будь-яка", "sun": "Сонце", "rain": "Дощ", "snow": "Сніг"][rawValue] ?? rawValue }
}

struct SwissTripPlan: Identifiable {
    let id = UUID()
    let place: SwissDiscoveryPlace
    let budgetCHF: Int
    let transport: SwissTripTransport
    let family: Bool
    let availableHours: Int
    var rationale: String? = nil
    var itinerary: [String] = []
    var generatedByAI = false
    var shareText: String {
        "Sweezy route: \(place.title) · \(place.region)\n\(place.route)\nBudget: up to CHF \(budgetCHF) · \(transport.title) · \(availableHours) h"
    }
}

enum SwissTripPlanner {
    static func plan(origin: String, budget: Int, transport: SwissTripTransport, family: Bool, weather: SwissTripWeather, availableHours: Int = 8) -> SwissTripPlan? {
        var candidates = SwissDiscoveryCatalog.places
        if family { candidates = candidates.filter { $0.filters.contains(.family) || $0.filters.contains(.easy) } }
        if transport == .publicTransit { candidates = candidates.filter { $0.filters.contains(.easy) || $0.settings.contains(.city) } }
        switch weather {
        case .rain: candidates = candidates.filter { $0.filters.contains(.culture) || $0.settings.contains(.city) }
        case .snow: candidates = candidates.filter { $0.settings.contains(.mountain) }
        case .sun: candidates = candidates.filter { $0.filters.contains(.nature) || $0.settings.contains(.lake) }
        case .any: break
        }
        guard !candidates.isEmpty else { candidates = SwissDiscoveryCatalog.places; return candidates.first.map { SwissTripPlan(place: $0, budgetCHF: budget, transport: transport, family: family, availableHours: availableHours) } }
        let seed = origin.unicodeScalars.reduce(budget + availableHours) { $0 + Int($1.value) } + Calendar.current.ordinality(of: .day, in: .year, for: Date())!
        return SwissTripPlan(place: candidates[abs(seed) % candidates.count], budgetCHF: budget, transport: transport, family: family, availableHours: availableHours)
    }
}

struct SwissTripPlannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var origin = "Zürich"
    @State private var budget = 80.0
    @State private var transport: SwissTripTransport = .publicTransit
    @State private var weather: SwissTripWeather = .any
    @State private var family = false
    @State private var availableHours = 8.0
    @State private var result: SwissTripPlan?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: "swiss-discovery-interlaken", blurRadius: 10, darkness: 0.78)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("AI-план поїздки").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("План формується з перевірених місць Sweezy під бюджет, транспорт, склад групи й погоду.").foregroundStyle(.white.opacity(0.65))
                        field("Звідки", text: $origin)
                        VStack(alignment: .leading) {
                            Text("Бюджет до CHF \(Int(budget))").font(.headline).foregroundStyle(.white)
                            Slider(value: $budget, in: 20...300, step: 10).tint(JourneyVisual.lime)
                        }.padding(16).background(.black.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading) {
                            Text("Час: до \(Int(availableHours)) год").font(.headline).foregroundStyle(.white)
                            Slider(value: $availableHours, in: 2...12, step: 1).tint(JourneyVisual.lime)
                        }.padding(16).background(.black.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 18))
                        Picker("Транспорт", selection: $transport) { ForEach(SwissTripTransport.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                        Picker("Погода", selection: $weather) { ForEach(SwissTripWeather.allCases) { Text($0.title).tag($0) } }.pickerStyle(.menu).tint(JourneyVisual.lime)
                        Toggle("Сімейний маршрут", isOn: $family).tint(JourneyVisual.lime).foregroundStyle(.white)
                        if let result { resultCard(result) }
                        Button { Task { await createPlan() } } label: {
                            Group { if isGenerating { ProgressView() } else { Label("Створити маршрут", systemImage: "sparkles") } }.font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity, minHeight: 56).background(JourneyVisual.lime).clipShape(RoundedRectangle(cornerRadius: 18))
                        }.disabled(isGenerating).accessibilityIdentifier("trip.planner.create")
                    }.padding(20).padding(.bottom, 30)
                }
            }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } } }
                .accessibilityIdentifier("trip.planner.screen")
                .alert("AI-план", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") }
        }
    }
    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text).textFieldStyle(.plain).foregroundStyle(.white).padding(16).background(.black.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 18))
    }
    private func resultCard(_ plan: SwissTripPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("РЕКОМЕНДАЦІЯ").font(.caption.bold()).tracking(1.6).foregroundStyle(JourneyVisual.lime)
            Text(plan.place.title).font(.title2.bold()).foregroundStyle(.white)
            Text(plan.place.route).foregroundStyle(.white.opacity(0.72))
            if let rationale = plan.rationale { Text(rationale).font(.subheadline).foregroundStyle(.white.opacity(0.72)) }
            ForEach(Array(plan.itinerary.enumerated()), id: \.offset) { index, step in Label("\(index + 1). \(step)", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.white.opacity(0.72)) }
            HStack { Label(plan.transport.title, systemImage: plan.transport.icon); Spacer(); Text("до CHF \(plan.budgetCHF)") }.font(.caption.bold()).foregroundStyle(JourneyVisual.lime)
            ShareLink(item: plan.shareText) { Label("Поділитися планом", systemImage: "person.2.fill").frame(maxWidth: .infinity, minHeight: 46) }.buttonStyle(.bordered).tint(JourneyVisual.lime)
        }.padding(18).background(.black.opacity(0.62)).clipShape(RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(JourneyVisual.lime.opacity(0.35)))
    }

    @MainActor private func createPlan() async {
        guard let fallback = SwissTripPlanner.plan(origin: origin, budget: Int(budget), transport: transport, family: family, weather: weather, availableHours: Int(availableHours)) else { return }
        result = fallback
        guard KeychainStore.get("access_token") != nil else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let ai = try await APIClient.createTripPlan(origin: origin, budget: Int(budget), transport: transport.rawValue, weather: weather.rawValue, family: family, availableHours: Int(availableHours), candidates: SwissDiscoveryCatalog.places)
            guard let place = SwissDiscoveryCatalog.places.first(where: { $0.id == ai.selectedPlaceID }) else { return }
            result = SwissTripPlan(place: place, budgetCHF: Int(budget), transport: transport, family: family, availableHours: Int(availableHours), rationale: ai.rationale, itinerary: ai.itinerary, generatedByAI: ai.generatedByAI)
        } catch { errorMessage = "Не вдалося оновити AI-план. Показано безпечну локальну рекомендацію." }
    }
}
