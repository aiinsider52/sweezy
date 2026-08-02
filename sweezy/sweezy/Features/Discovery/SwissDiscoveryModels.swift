import Foundation
import CoreLocation

enum SwissDiscoveryFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case nature
    case culture
    case family
    case easy

    var id: String { rawValue }

    var title: String {
        "swiss.discovery.filter.\(rawValue)".localized
    }

    var icon: String {
        switch self {
        case .all: return "sparkles"
        case .nature: return "mountain.2.fill"
        case .culture: return "building.columns.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .easy: return "tram.fill"
        }
    }
}

struct SwissDiscoveryPlace: Identifiable, Hashable {
    let id: String
    let imageNames: [String]
    let titleKey: String
    let regionKey: String
    let summaryKey: String
    let tipKey: String
    let seasonKey: String
    let durationKey: String
    let routeKey: String
    let filters: Set<SwissDiscoveryFilter>
    let latitude: Double
    let longitude: Double
    let officialURLString: String

    var title: String { titleKey.localized }
    var imageName: String { imageNames.first ?? "swiss-discovery-aletsch" }
    var region: String { regionKey.localized }
    var summary: String { summaryKey.localized }
    var details: String {
        let key = summaryKey.replacingOccurrences(of: ".summary", with: ".details")
        let value = key.localized
        return value == key ? summary : value
    }
    var tip: String { tipKey.localized }
    var season: String { seasonKey.localized }
    var duration: String { durationKey.localized }
    var route: String { routeKey.localized }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var officialURL: URL { URL(string: officialURLString)! }

    func matches(query: String, filter: SwissDiscoveryFilter) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesFilter = filter == .all || filters.contains(filter)
        let haystack = [title, region, summary, season].joined(separator: " ")
        return matchesFilter && (trimmedQuery.isEmpty || haystack.localizedCaseInsensitiveContains(trimmedQuery))
    }
}

enum SwissDiscoveryCatalog {
    static let verifiedAt = "02.08.2026"

    static let places: [SwissDiscoveryPlace] = [
        SwissDiscoveryPlace(
            id: "aletsch",
            imageNames: ["swiss-discovery-aletsch", "swiss-discovery-aletsch-2", "swiss-discovery-aletsch-3"],
            titleKey: "swiss.discovery.aletsch.title",
            regionKey: "swiss.discovery.aletsch.region",
            summaryKey: "swiss.discovery.aletsch.summary",
            tipKey: "swiss.discovery.aletsch.tip",
            seasonKey: "swiss.discovery.aletsch.season",
            durationKey: "swiss.discovery.aletsch.duration",
            routeKey: "swiss.discovery.aletsch.route",
            filters: [.nature, .family, .easy],
            latitude: 46.4319,
            longitude: 8.0938,
            officialURLString: "https://www.myswitzerland.com/ru/destinations/aletsch-arena-1/"
        ),
        SwissDiscoveryPlace(
            id: "lavaux",
            imageNames: ["swiss-discovery-lavaux", "swiss-discovery-lavaux-2", "swiss-discovery-lavaux-3"],
            titleKey: "swiss.discovery.lavaux.title",
            regionKey: "swiss.discovery.lavaux.region",
            summaryKey: "swiss.discovery.lavaux.summary",
            tipKey: "swiss.discovery.lavaux.tip",
            seasonKey: "swiss.discovery.lavaux.season",
            durationKey: "swiss.discovery.lavaux.duration",
            routeKey: "swiss.discovery.lavaux.route",
            filters: [.nature, .culture, .easy],
            latitude: 46.4888,
            longitude: 6.7294,
            officialURLString: "https://www.myswitzerland.com/ru/destinations/lavaux-vineyard-terraces/"
        ),
        SwissDiscoveryPlace(
            id: "creux-du-van",
            imageNames: ["swiss-discovery-creux", "swiss-discovery-creux-2", "swiss-discovery-creux-3"],
            titleKey: "swiss.discovery.creux.title",
            regionKey: "swiss.discovery.creux.region",
            summaryKey: "swiss.discovery.creux.summary",
            tipKey: "swiss.discovery.creux.tip",
            seasonKey: "swiss.discovery.creux.season",
            durationKey: "swiss.discovery.creux.duration",
            routeKey: "swiss.discovery.creux.route",
            filters: [.nature],
            latitude: 46.9305,
            longitude: 6.7270,
            officialURLString: "https://www.myswitzerland.com/en-us/experiences/creux-du-van-natural-spectacle/"
        ),
        SwissDiscoveryPlace(
            id: "rhine-falls",
            imageNames: ["swiss-discovery-rhine-falls", "swiss-discovery-rhine-falls-2", "swiss-discovery-rhine-falls-3"],
            titleKey: "swiss.discovery.rhine.title",
            regionKey: "swiss.discovery.rhine.region",
            summaryKey: "swiss.discovery.rhine.summary",
            tipKey: "swiss.discovery.rhine.tip",
            seasonKey: "swiss.discovery.rhine.season",
            durationKey: "swiss.discovery.rhine.duration",
            routeKey: "swiss.discovery.rhine.route",
            filters: [.nature, .family, .easy],
            latitude: 47.6779,
            longitude: 8.6154,
            officialURLString: "https://www.myswitzerland.com/en-us/experiences/the-rhine-falls/"
        ),
        SwissDiscoveryPlace(
            id: "oeschinensee",
            imageNames: ["swiss-discovery-oeschinen", "swiss-discovery-oeschinen-2", "swiss-discovery-oeschinen-3"],
            titleKey: "swiss.discovery.oeschinen.title",
            regionKey: "swiss.discovery.oeschinen.region",
            summaryKey: "swiss.discovery.oeschinen.summary",
            tipKey: "swiss.discovery.oeschinen.tip",
            seasonKey: "swiss.discovery.oeschinen.season",
            durationKey: "swiss.discovery.oeschinen.duration",
            routeKey: "swiss.discovery.oeschinen.route",
            filters: [.nature, .family, .easy],
            latitude: 46.4987,
            longitude: 7.7264,
            officialURLString: "https://www.myswitzerland.com/en-gb/experiences/gondola-to-lake-oeschinen/"
        ),
        SwissDiscoveryPlace(
            id: "ruinaulta",
            imageNames: ["swiss-discovery-ruinaulta", "swiss-discovery-ruinaulta-2", "swiss-discovery-ruinaulta-3"],
            titleKey: "swiss.discovery.ruinaulta.title",
            regionKey: "swiss.discovery.ruinaulta.region",
            summaryKey: "swiss.discovery.ruinaulta.summary",
            tipKey: "swiss.discovery.ruinaulta.tip",
            seasonKey: "swiss.discovery.ruinaulta.season",
            durationKey: "swiss.discovery.ruinaulta.duration",
            routeKey: "swiss.discovery.ruinaulta.route",
            filters: [.nature, .family, .easy],
            latitude: 46.8057,
            longitude: 9.3195,
            officialURLString: "https://www.myswitzerland.com/en-gb/experiences/ruinaulta-switzerlands-grand-canyon/"
        ),
        SwissDiscoveryPlace(
            id: "monte-generoso",
            imageNames: ["swiss-discovery-generoso", "swiss-discovery-generoso-2", "swiss-discovery-generoso-3"],
            titleKey: "swiss.discovery.generoso.title",
            regionKey: "swiss.discovery.generoso.region",
            summaryKey: "swiss.discovery.generoso.summary",
            tipKey: "swiss.discovery.generoso.tip",
            seasonKey: "swiss.discovery.generoso.season",
            durationKey: "swiss.discovery.generoso.duration",
            routeKey: "swiss.discovery.generoso.route",
            filters: [.nature, .culture, .family, .easy],
            latitude: 45.9291,
            longitude: 9.0193,
            officialURLString: "https://www.myswitzerland.com/en-us/experiences/monte-generoso/"
        ),
        SwissDiscoveryPlace(
            id: "st-gallen-abbey",
            imageNames: ["swiss-discovery-st-gallen", "swiss-discovery-st-gallen-2", "swiss-discovery-st-gallen-3"],
            titleKey: "swiss.discovery.st_gallen.title",
            regionKey: "swiss.discovery.st_gallen.region",
            summaryKey: "swiss.discovery.st_gallen.summary",
            tipKey: "swiss.discovery.st_gallen.tip",
            seasonKey: "swiss.discovery.st_gallen.season",
            durationKey: "swiss.discovery.st_gallen.duration",
            routeKey: "swiss.discovery.st_gallen.route",
            filters: [.culture, .family, .easy],
            latitude: 47.4230,
            longitude: 9.3777,
            officialURLString: "https://www.myswitzerland.com/en-ch/experiences/st-gallen-abbey-district/"
        ),
        SwissDiscoveryPlace(
            id: "matterhorn",
            imageNames: ["swiss-discovery-matterhorn", "swiss-discovery-matterhorn-2", "swiss-discovery-matterhorn-3"],
            titleKey: "swiss.discovery.matterhorn.title",
            regionKey: "swiss.discovery.matterhorn.region",
            summaryKey: "swiss.discovery.matterhorn.summary",
            tipKey: "swiss.discovery.matterhorn.tip",
            seasonKey: "swiss.discovery.matterhorn.season",
            durationKey: "swiss.discovery.matterhorn.duration",
            routeKey: "swiss.discovery.matterhorn.route",
            filters: [.nature, .family, .easy],
            latitude: 45.9763,
            longitude: 7.6586,
            officialURLString: "https://www.myswitzerland.com/en-us/destinations/matterhorn/"
        ),
        SwissDiscoveryPlace(
            id: "jungfraujoch",
            imageNames: ["swiss-discovery-jungfraujoch", "swiss-discovery-jungfraujoch-2", "swiss-discovery-jungfraujoch-3"],
            titleKey: "swiss.discovery.jungfraujoch.title",
            regionKey: "swiss.discovery.jungfraujoch.region",
            summaryKey: "swiss.discovery.jungfraujoch.summary",
            tipKey: "swiss.discovery.jungfraujoch.tip",
            seasonKey: "swiss.discovery.jungfraujoch.season",
            durationKey: "swiss.discovery.jungfraujoch.duration",
            routeKey: "swiss.discovery.jungfraujoch.route",
            filters: [.nature, .family, .easy],
            latitude: 46.5475,
            longitude: 7.9856,
            officialURLString: "https://www.myswitzerland.com/en-us/destinations/jungfraujoch/"
        ),
        SwissDiscoveryPlace(
            id: "bern",
            imageNames: ["swiss-discovery-bern", "swiss-discovery-bern-2", "swiss-discovery-bern-3"],
            titleKey: "swiss.discovery.bern.title",
            regionKey: "swiss.discovery.bern.region",
            summaryKey: "swiss.discovery.bern.summary",
            tipKey: "swiss.discovery.bern.tip",
            seasonKey: "swiss.discovery.bern.season",
            durationKey: "swiss.discovery.bern.duration",
            routeKey: "swiss.discovery.bern.route",
            filters: [.culture, .family, .easy],
            latitude: 46.9480,
            longitude: 7.4474,
            officialURLString: "https://www.myswitzerland.com/en-ch/destinations/bern/"
        ),
        SwissDiscoveryPlace(
            id: "rigi",
            imageNames: ["swiss-discovery-rigi", "swiss-discovery-rigi-2", "swiss-discovery-rigi-3"],
            titleKey: "swiss.discovery.rigi.title",
            regionKey: "swiss.discovery.rigi.region",
            summaryKey: "swiss.discovery.rigi.summary",
            tipKey: "swiss.discovery.rigi.tip",
            seasonKey: "swiss.discovery.rigi.season",
            durationKey: "swiss.discovery.rigi.duration",
            routeKey: "swiss.discovery.rigi.route",
            filters: [.nature, .family, .easy],
            latitude: 47.0567,
            longitude: 8.4850,
            officialURLString: "https://www.myswitzerland.com/en-us/destinations/rigi/"
        ),
        SwissDiscoveryPlace(
            id: "zurich",
            imageNames: ["swiss-discovery-zurich", "swiss-discovery-zurich-2", "swiss-discovery-zurich-3"],
            titleKey: "swiss.discovery.zurich.title",
            regionKey: "swiss.discovery.zurich.region",
            summaryKey: "swiss.discovery.zurich.summary",
            tipKey: "swiss.discovery.zurich.tip",
            seasonKey: "swiss.discovery.zurich.season",
            durationKey: "swiss.discovery.zurich.duration",
            routeKey: "swiss.discovery.zurich.route",
            filters: [.culture, .family, .easy],
            latitude: 47.3769,
            longitude: 8.5417,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/zuerich/"
        ),
        SwissDiscoveryPlace(
            id: "geneva",
            imageNames: ["swiss-discovery-geneva", "swiss-discovery-geneva-2", "swiss-discovery-geneva-3"],
            titleKey: "swiss.discovery.geneva.title",
            regionKey: "swiss.discovery.geneva.region",
            summaryKey: "swiss.discovery.geneva.summary",
            tipKey: "swiss.discovery.geneva.tip",
            seasonKey: "swiss.discovery.geneva.season",
            durationKey: "swiss.discovery.geneva.duration",
            routeKey: "swiss.discovery.geneva.route",
            filters: [.culture, .family, .easy],
            latitude: 46.2044,
            longitude: 6.1432,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/geneva/"
        ),
        SwissDiscoveryPlace(
            id: "lucerne",
            imageNames: ["swiss-discovery-lucerne", "swiss-discovery-lucerne-2", "swiss-discovery-lucerne-3"],
            titleKey: "swiss.discovery.lucerne.title",
            regionKey: "swiss.discovery.lucerne.region",
            summaryKey: "swiss.discovery.lucerne.summary",
            tipKey: "swiss.discovery.lucerne.tip",
            seasonKey: "swiss.discovery.lucerne.season",
            durationKey: "swiss.discovery.lucerne.duration",
            routeKey: "swiss.discovery.lucerne.route",
            filters: [.nature, .culture, .family, .easy],
            latitude: 47.0502,
            longitude: 8.3093,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/luzern/"
        ),
        SwissDiscoveryPlace(
            id: "basel",
            imageNames: ["swiss-discovery-basel", "swiss-discovery-basel-2", "swiss-discovery-basel-3"],
            titleKey: "swiss.discovery.basel.title",
            regionKey: "swiss.discovery.basel.region",
            summaryKey: "swiss.discovery.basel.summary",
            tipKey: "swiss.discovery.basel.tip",
            seasonKey: "swiss.discovery.basel.season",
            durationKey: "swiss.discovery.basel.duration",
            routeKey: "swiss.discovery.basel.route",
            filters: [.culture, .family, .easy],
            latitude: 47.5596,
            longitude: 7.5886,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/basel/"
        ),
        SwissDiscoveryPlace(
            id: "lausanne",
            imageNames: ["swiss-discovery-lausanne", "swiss-discovery-lausanne-2", "swiss-discovery-lausanne-3"],
            titleKey: "swiss.discovery.lausanne.title",
            regionKey: "swiss.discovery.lausanne.region",
            summaryKey: "swiss.discovery.lausanne.summary",
            tipKey: "swiss.discovery.lausanne.tip",
            seasonKey: "swiss.discovery.lausanne.season",
            durationKey: "swiss.discovery.lausanne.duration",
            routeKey: "swiss.discovery.lausanne.route",
            filters: [.culture, .family, .easy],
            latitude: 46.5197,
            longitude: 6.6323,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/lausanne/"
        ),
        SwissDiscoveryPlace(
            id: "montreux",
            imageNames: ["swiss-discovery-montreux", "swiss-discovery-montreux-2", "swiss-discovery-montreux-3"],
            titleKey: "swiss.discovery.montreux.title",
            regionKey: "swiss.discovery.montreux.region",
            summaryKey: "swiss.discovery.montreux.summary",
            tipKey: "swiss.discovery.montreux.tip",
            seasonKey: "swiss.discovery.montreux.season",
            durationKey: "swiss.discovery.montreux.duration",
            routeKey: "swiss.discovery.montreux.route",
            filters: [.nature, .culture, .family, .easy],
            latitude: 46.4312,
            longitude: 6.9107,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/montreux/"
        ),
        SwissDiscoveryPlace(
            id: "lugano",
            imageNames: ["swiss-discovery-lugano", "swiss-discovery-lugano-2", "swiss-discovery-lugano-3"],
            titleKey: "swiss.discovery.lugano.title",
            regionKey: "swiss.discovery.lugano.region",
            summaryKey: "swiss.discovery.lugano.summary",
            tipKey: "swiss.discovery.lugano.tip",
            seasonKey: "swiss.discovery.lugano.season",
            durationKey: "swiss.discovery.lugano.duration",
            routeKey: "swiss.discovery.lugano.route",
            filters: [.nature, .culture, .family, .easy],
            latitude: 46.0037,
            longitude: 8.9511,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/lugano/"
        ),
        SwissDiscoveryPlace(
            id: "davos",
            imageNames: ["swiss-discovery-davos", "swiss-discovery-davos-2", "swiss-discovery-davos-3"],
            titleKey: "swiss.discovery.davos.title",
            regionKey: "swiss.discovery.davos.region",
            summaryKey: "swiss.discovery.davos.summary",
            tipKey: "swiss.discovery.davos.tip",
            seasonKey: "swiss.discovery.davos.season",
            durationKey: "swiss.discovery.davos.duration",
            routeKey: "swiss.discovery.davos.route",
            filters: [.nature, .family, .easy],
            latitude: 46.8027,
            longitude: 9.8360,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/davos/"
        ),
        SwissDiscoveryPlace(
            id: "ascona",
            imageNames: ["swiss-discovery-ascona", "swiss-discovery-ascona-2", "swiss-discovery-ascona-3"],
            titleKey: "swiss.discovery.ascona.title",
            regionKey: "swiss.discovery.ascona.region",
            summaryKey: "swiss.discovery.ascona.summary",
            tipKey: "swiss.discovery.ascona.tip",
            seasonKey: "swiss.discovery.ascona.season",
            durationKey: "swiss.discovery.ascona.duration",
            routeKey: "swiss.discovery.ascona.route",
            filters: [.nature, .culture, .family, .easy],
            latitude: 46.1540,
            longitude: 8.7731,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/ascona/"
        ),
        SwissDiscoveryPlace(
            id: "engadin",
            imageNames: ["swiss-discovery-engadin", "swiss-discovery-engadin-2", "swiss-discovery-engadin-3"],
            titleKey: "swiss.discovery.engadin.title",
            regionKey: "swiss.discovery.engadin.region",
            summaryKey: "swiss.discovery.engadin.summary",
            tipKey: "swiss.discovery.engadin.tip",
            seasonKey: "swiss.discovery.engadin.season",
            durationKey: "swiss.discovery.engadin.duration",
            routeKey: "swiss.discovery.engadin.route",
            filters: [.nature, .culture, .family, .easy],
            latitude: 46.4908,
            longitude: 9.8355,
            officialURLString: "https://meetings.myswitzerland.com/ru/meetingcountry/engadin-st-moritz/"
        )
    ]
}

enum SwissDiscoveryProgressStore {
    private static var savedKey: String {
        AccountScopedStorage.namespaced("swiss_discovery.saved_place_ids")
    }

    private static var visitedKey: String {
        AccountScopedStorage.namespaced("swiss_discovery.visited_place_ids")
    }

    static func savedPlaceIDs(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: savedKey) ?? [])
    }

    static func visitedPlaceIDs(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: visitedKey) ?? [])
    }

    static func save(_ ids: Set<String>, defaults: UserDefaults = .standard) {
        defaults.set(Array(ids).sorted(), forKey: savedKey)
    }

    static func saveVisited(_ ids: Set<String>, defaults: UserDefaults = .standard) {
        defaults.set(Array(ids).sorted(), forKey: visitedKey)
    }
}
