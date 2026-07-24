//
//  CityHubData.swift
//  sweezy
//

import Foundation
import CoreLocation

enum CityHubData {
    static let zurich = CityHubDefinition(
        id: "zurich",
        title: "Zürich",
        heroImageName: "swiss-moment-zurich",
        canton: .zurich,
        mapCenter: CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
        mapSpanDelta: 0.09,
        jobsCityQuery: "Zürich",
        facts: [
            CityHubFact(id: "canton", labelKey: "cityhub.fact.canton", valueKey: "cityhub.zurich.fact.canton_value", icon: "map"),
            CityHubFact(id: "language", labelKey: "cityhub.fact.language", valueKey: "cityhub.zurich.fact.language_value", icon: "character.bubble"),
            CityHubFact(id: "population", labelKey: "cityhub.fact.population", valueKey: "cityhub.zurich.fact.population_value", icon: "person.3"),
            CityHubFact(id: "rent", labelKey: "cityhub.fact.rent", valueKey: "cityhub.zurich.fact.rent_value", icon: "house")
        ],
        mustSee: [
            CityHubSpot(
                id: "grossmuenster",
                titleKey: "cityhub.zurich.mustsee.grossmuenster.title",
                whyKey: "cityhub.zurich.mustsee.grossmuenster.why",
                tipKey: "cityhub.zurich.mustsee.grossmuenster.tip",
                icon: "building.columns",
                imageName: "cityhub-zurich-grossmuenster",
                kind: .mustSee,
                latitude: 47.3701,
                longitude: 8.5439
            ),
            CityHubSpot(
                id: "limmat",
                titleKey: "cityhub.zurich.mustsee.limmat.title",
                whyKey: "cityhub.zurich.mustsee.limmat.why",
                tipKey: "cityhub.zurich.mustsee.limmat.tip",
                icon: "water.waves",
                imageName: "cityhub-zurich-limmat",
                kind: .mustSee,
                latitude: 47.3730,
                longitude: 8.5410
            ),
            CityHubSpot(
                id: "lake",
                titleKey: "cityhub.zurich.mustsee.lake.title",
                whyKey: "cityhub.zurich.mustsee.lake.why",
                tipKey: "cityhub.zurich.mustsee.lake.tip",
                icon: "sailboat",
                imageName: "cityhub-zurich-lake",
                kind: .mustSee,
                latitude: 47.3660,
                longitude: 8.5480
            ),
            CityHubSpot(
                id: "uetliberg",
                titleKey: "cityhub.zurich.mustsee.uetliberg.title",
                whyKey: "cityhub.zurich.mustsee.uetliberg.why",
                tipKey: "cityhub.zurich.mustsee.uetliberg.tip",
                icon: "mountain.2",
                imageName: "cityhub-zurich-uetliberg",
                kind: .mustSee,
                latitude: 47.3496,
                longitude: 8.4919
            ),
            CityHubSpot(
                id: "oldtown",
                titleKey: "cityhub.zurich.mustsee.oldtown.title",
                whyKey: "cityhub.zurich.mustsee.oldtown.why",
                tipKey: "cityhub.zurich.mustsee.oldtown.tip",
                icon: "figure.walk",
                imageName: "cityhub-zurich-oldtown",
                kind: .mustSee,
                latitude: 47.3717,
                longitude: 8.5425
            )
        ],
        culture: [
            CityHubSpot(
                id: "kunsthaus",
                titleKey: "cityhub.zurich.culture.kunsthaus.title",
                whyKey: "cityhub.zurich.culture.kunsthaus.why",
                tipKey: "cityhub.zurich.culture.kunsthaus.tip",
                icon: "paintpalette",
                imageName: "cityhub-zurich-kunsthaus",
                kind: .culture,
                latitude: 47.3710,
                longitude: 8.5485
            ),
            CityHubSpot(
                id: "landesmuseum",
                titleKey: "cityhub.zurich.culture.landesmuseum.title",
                whyKey: "cityhub.zurich.culture.landesmuseum.why",
                tipKey: "cityhub.zurich.culture.landesmuseum.tip",
                icon: "building.2",
                imageName: "cityhub-zurich-landesmuseum",
                kind: .culture,
                latitude: 47.3791,
                longitude: 8.5391
            ),
            CityHubSpot(
                id: "opernhaus",
                titleKey: "cityhub.zurich.culture.opernhaus.title",
                whyKey: "cityhub.zurich.culture.opernhaus.why",
                tipKey: "cityhub.zurich.culture.opernhaus.tip",
                icon: "theatermasks",
                imageName: "cityhub-zurich-opernhaus",
                kind: .culture,
                latitude: 47.3653,
                longitude: 8.5482
            ),
            CityHubSpot(
                id: "rietberg",
                titleKey: "cityhub.zurich.culture.rietberg.title",
                whyKey: "cityhub.zurich.culture.rietberg.why",
                tipKey: "cityhub.zurich.culture.rietberg.tip",
                icon: "globe.asia.australia",
                imageName: "cityhub-zurich-rietberg",
                kind: .culture,
                latitude: 47.3589,
                longitude: 8.5264
            ),
            CityHubSpot(
                id: "fraumuenster",
                titleKey: "cityhub.zurich.culture.fraumuenster.title",
                whyKey: "cityhub.zurich.culture.fraumuenster.why",
                tipKey: "cityhub.zurich.culture.fraumuenster.tip",
                icon: "sparkles",
                imageName: "cityhub-zurich-fraumuenster",
                kind: .culture,
                latitude: 47.3697,
                longitude: 8.5389
            )
        ],
        localLife: [
            CityHubSpot(
                id: "viadukt",
                titleKey: "cityhub.zurich.local.viadukt.title",
                whyKey: "cityhub.zurich.local.viadukt.why",
                tipKey: "cityhub.zurich.local.viadukt.tip",
                icon: "basket",
                imageName: "cityhub-zurich-viadukt",
                kind: .local,
                latitude: 47.3850,
                longitude: 8.5240
            ),
            CityHubSpot(
                id: "kreis4",
                titleKey: "cityhub.zurich.local.kreis4.title",
                whyKey: "cityhub.zurich.local.kreis4.why",
                tipKey: "cityhub.zurich.local.kreis4.tip",
                icon: "cup.and.saucer",
                imageName: "cityhub-zurich-kreis4",
                kind: .local,
                latitude: 47.3780,
                longitude: 8.5180
            ),
            CityHubSpot(
                id: "sechselaeutenplatz",
                titleKey: "cityhub.zurich.local.sechselaeutenplatz.title",
                whyKey: "cityhub.zurich.local.sechselaeutenplatz.why",
                tipKey: "cityhub.zurich.local.sechselaeutenplatz.tip",
                icon: "leaf",
                imageName: "cityhub-zurich-sechselaeutenplatz",
                kind: .local,
                latitude: 47.3645,
                longitude: 8.5478
            ),
            CityHubSpot(
                id: "chinagarten",
                titleKey: "cityhub.zurich.local.chinagarten.title",
                whyKey: "cityhub.zurich.local.chinagarten.why",
                tipKey: "cityhub.zurich.local.chinagarten.tip",
                icon: "tree",
                imageName: "cityhub-zurich-chinagarten",
                kind: .local,
                latitude: 47.3618,
                longitude: 8.5552
            )
        ],
        firstSteps: [
            CityHubFirstStep(
                id: "gemeinde",
                titleKey: "cityhub.zurich.step.gemeinde.title",
                detailKey: "cityhub.zurich.step.gemeinde.detail",
                icon: "building.2.crop.circle"
            ),
            CityHubFirstStep(
                id: "migration",
                titleKey: "cityhub.zurich.step.migration.title",
                detailKey: "cityhub.zurich.step.migration.detail",
                icon: "person.text.rectangle"
            ),
            CityHubFirstStep(
                id: "insurance",
                titleKey: "cityhub.zurich.step.insurance.title",
                detailKey: "cityhub.zurich.step.insurance.detail",
                icon: "cross.case"
            ),
            CityHubFirstStep(
                id: "bank",
                titleKey: "cityhub.zurich.step.bank.title",
                detailKey: "cityhub.zurich.step.bank.detail",
                icon: "creditcard"
            ),
            CityHubFirstStep(
                id: "rav",
                titleKey: "cityhub.zurich.step.rav.title",
                detailKey: "cityhub.zurich.step.rav.detail",
                icon: "briefcase"
            )
        ],
        costFacts: [
            CityHubCostFact(
                id: "rent",
                labelKey: "cityhub.cost.rent_label",
                valueKey: "cityhub.zurich.cost.rent_value",
                icon: "house.fill"
            ),
            CityHubCostFact(
                id: "kk",
                labelKey: "cityhub.cost.kk_label",
                valueKey: "cityhub.zurich.cost.kk_value",
                icon: "heart.text.square"
            ),
            CityHubCostFact(
                id: "tax",
                labelKey: "cityhub.cost.tax_label",
                valueKey: "cityhub.zurich.cost.tax_value",
                icon: "percent"
            ),
            CityHubCostFact(
                id: "transit",
                labelKey: "cityhub.cost.transit_label",
                valueKey: "cityhub.zurich.cost.transit_value",
                icon: "tram.fill"
            )
        ]
    )
}
