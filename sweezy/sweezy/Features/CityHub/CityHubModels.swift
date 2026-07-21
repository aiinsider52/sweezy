//
//  CityHubModels.swift
//  sweezy
//

import Foundation
import CoreLocation

enum CityHubIntent: String, CaseIterable, Identifiable {
    case living
    case considering
    case exploring

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .living: return "cityhub.intent.living"
        case .considering: return "cityhub.intent.considering"
        case .exploring: return "cityhub.intent.exploring"
        }
    }
}

enum CityHubSpotKind: String, Codable {
    case mustSee
    case culture
    case local
}

struct CityHubSpot: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let whyKey: String
    let tipKey: String?
    let icon: String
    let imageName: String?
    let kind: CityHubSpotKind
    let latitude: Double?
    let longitude: Double?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct CityHubFirstStep: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let detailKey: String
    let icon: String
}

struct CityHubCostFact: Identifiable, Hashable {
    let id: String
    let labelKey: String
    let valueKey: String
    let icon: String
}

struct CityHubFact: Identifiable, Hashable {
    let id: String
    let labelKey: String
    let valueKey: String
    let icon: String
}

struct CityHubDefinition: Identifiable {
    let id: String
    let title: String
    let heroImageName: String
    let canton: Canton
    let mapCenter: CLLocationCoordinate2D
    let mapSpanDelta: Double
    let jobsCityQuery: String
    let facts: [CityHubFact]
    let mustSee: [CityHubSpot]
    let culture: [CityHubSpot]
    let localLife: [CityHubSpot]
    let firstSteps: [CityHubFirstStep]
    let costFacts: [CityHubCostFact]

    var discoverTitleKey: String { "cityhub.discover.title_format" }
    var cultureTitleKey: String { "cityhub.culture.title" }
    var localTitleKey: String { "cityhub.local.title" }
    var firstStepsTitleKey: String { "cityhub.first_steps.title" }
    var costTitleKey: String { "cityhub.cost.title" }
    var placesTitleKey: String { "cityhub.places.title" }
    var guidesTitleKey: String { "cityhub.guides.title" }
}

enum CityHubRegistry {
    static func hub(for slug: String) -> CityHubDefinition? {
        switch slug {
        case "zurich": return CityHubData.zurich
        default: return nil
        }
    }
}

enum CityHubProgressStore {
    private static func visitedKey(cityId: String) -> String { "cityhub.\(cityId).visited" }
    private static func stepsKey(cityId: String) -> String { "cityhub.\(cityId).steps" }

    static func visitedSpotIDs(cityId: String) -> Set<String> {
        let raw = UserDefaults.standard.string(forKey: visitedKey(cityId: cityId)) ?? ""
        return Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    static func setVisited(_ visited: Bool, spotId: String, cityId: String) {
        var ids = visitedSpotIDs(cityId: cityId)
        if visited { ids.insert(spotId) } else { ids.remove(spotId) }
        UserDefaults.standard.set(ids.sorted().joined(separator: ","), forKey: visitedKey(cityId: cityId))
    }

    static func completedStepIDs(cityId: String) -> Set<String> {
        let raw = UserDefaults.standard.string(forKey: stepsKey(cityId: cityId)) ?? ""
        return Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    static func setStepCompleted(_ completed: Bool, stepId: String, cityId: String) {
        var ids = completedStepIDs(cityId: cityId)
        if completed { ids.insert(stepId) } else { ids.remove(stepId) }
        UserDefaults.standard.set(ids.sorted().joined(separator: ","), forKey: stepsKey(cityId: cityId))
    }

    static func discoveryProgress(cityId: String, totalSpots: Int) -> Double {
        guard totalSpots > 0 else { return 0 }
        return Double(visitedSpotIDs(cityId: cityId).count) / Double(totalSpots)
    }
}

enum JobsSearchPreset {
    static var pendingCanton: String?
    static var pendingCity: String?
}
