import Foundation

enum ResidenceCountry: String, CaseIterable, Codable, Hashable, Identifiable {
    case switzerland = "CH"
    case germany = "DE"
    case austria = "AT"

    var id: String { rawValue }

    var name: String {
        "country.name.\(rawValue.lowercased())".localized
    }

    var nativeName: String {
        switch self {
        case .switzerland: return "Schweiz"
        case .germany: return "Deutschland"
        case .austria: return "Österreich"
        }
    }

    var flag: String {
        switch self {
        case .switzerland: return "🇨🇭"
        case .germany: return "🇩🇪"
        case .austria: return "🇦🇹"
        }
    }

    var subdivisionTitle: String {
        switch self {
        case .switzerland: return "country.subdivision.canton".localized
        case .germany, .austria: return "country.subdivision.federal_state".localized
        }
    }

    var currencyCode: String { self == .switzerland ? "CHF" : "EUR" }

    func localizedName(languageIdentifier: String) -> String {
        let language = languageIdentifier
            .split(whereSeparator: { $0 == "_" || $0 == "-" })
            .first
            .map(String.init) ?? "uk"

        switch (language, self) {
        case ("de", .switzerland): return "Schweiz"
        case ("de", .germany): return "Deutschland"
        case ("de", .austria): return "Österreich"
        case ("en", .switzerland): return "Switzerland"
        case ("en", .germany): return "Germany"
        case ("en", .austria): return "Austria"
        default: return name
        }
    }

    /// Country fragment for Home hero. Ukrainian copy supplies "у" on previous line;
    /// English and German fragments include their own preposition.
    func homeHeroName(languageIdentifier: String) -> String {
        let language = languageIdentifier
            .split(whereSeparator: { $0 == "_" || $0 == "-" })
            .first
            .map(String.init) ?? "uk"

        switch (language, self) {
        case ("de", .switzerland): return "in der Schweiz"
        case ("de", .germany): return "in Deutschland"
        case ("de", .austria): return "in Österreich"
        case ("en", .switzerland): return "in Switzerland"
        case ("en", .germany): return "in Germany"
        case ("en", .austria): return "in Austria"
        case (_, .switzerland): return "Швейцарії"
        case (_, .germany): return "Німеччині"
        case (_, .austria): return "Австрії"
        }
    }

    /// "у Швейцарії" / "in der Schweiz" / "in Switzerland": insert whole, never glue "у" + name.
    var inCountryPhrase: String { "country.in.\(rawValue.lowercased())".localized }

    /// "Для ринку Швейцарії" / "Für den Schweizer Arbeitsmarkt".
    var jobMarketPhrase: String { "country.job_market.\(rawValue.lowercased())".localized }

    var ukrainianGenitiveName: String {
        switch self {
        case .switzerland: return "Швейцарії"
        case .germany: return "Німеччини"
        case .austria: return "Австрії"
        }
    }

    var timeZoneIdentifier: String {
        switch self {
        case .switzerland: return "Europe/Zurich"
        case .germany: return "Europe/Berlin"
        case .austria: return "Europe/Vienna"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .switzerland: return "de_CH"
        case .germany: return "de_DE"
        case .austria: return "de_AT"
        }
    }

    var defaultSubdivisionCode: String {
        switch self {
        case .switzerland: return "ZH"
        case .germany: return "DE-BE"
        case .austria: return "AT-9"
        }
    }

    var defaultResidenceStatusCode: String {
        switch self {
        case .switzerland: return "S"
        case .germany: return "temporary_protection_24"
        case .austria: return "displaced_person"
        }
    }
}

struct AdministrativeArea: Identifiable, Codable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}

struct ResidenceStatusOption: Identifiable, Codable, Hashable {
    let code: String
    let title: String
    let detail: String
    var id: String { code }
}

enum CountryCatalog {
    static func subdivisions(for country: ResidenceCountry) -> [AdministrativeArea] {
        switch country {
        case .switzerland:
            return Canton.sortedByName.map { AdministrativeArea(code: $0.rawValue, name: $0.localizedName) }
        case .germany:
            return [
                ("DE-BW", "Baden-Württemberg"), ("DE-BY", "Bayern"), ("DE-BE", "Berlin"),
                ("DE-BB", "Brandenburg"), ("DE-HB", "Bremen"), ("DE-HH", "Hamburg"),
                ("DE-HE", "Hessen"), ("DE-MV", "Mecklenburg-Vorpommern"),
                ("DE-NI", "Niedersachsen"), ("DE-NW", "Nordrhein-Westfalen"),
                ("DE-RP", "Rheinland-Pfalz"), ("DE-SL", "Saarland"), ("DE-SN", "Sachsen"),
                ("DE-ST", "Sachsen-Anhalt"), ("DE-SH", "Schleswig-Holstein"), ("DE-TH", "Thüringen")
            ].map { AdministrativeArea(code: $0.0, name: $0.1) }
        case .austria:
            return [
                ("AT-1", "Burgenland"), ("AT-2", "Kärnten"), ("AT-3", "Niederösterreich"),
                ("AT-4", "Oberösterreich"), ("AT-5", "Salzburg"), ("AT-6", "Steiermark"),
                ("AT-7", "Tirol"), ("AT-8", "Vorarlberg"), ("AT-9", "Wien")
            ].map { AdministrativeArea(code: $0.0, name: $0.1) }
        }
    }

    static func statuses(for country: ResidenceCountry) -> [ResidenceStatusOption] {
        switch country {
        case .switzerland:
            // "Other" matches PermitType.other.rawValue, which legacy profiles persist.
            return [
                .init(code: "S", title: "residence.status.ch.s".localized, detail: "residence.detail.temporary_protection".localized),
                .init(code: "B", title: "residence.status.ch.b".localized, detail: "residence.detail.residence_permit".localized),
                .init(code: "C", title: "residence.status.ch.c".localized, detail: "residence.detail.permanent_residence".localized),
                .init(code: "F", title: "residence.status.ch.f".localized, detail: "residence.detail.provisional_admission".localized),
                .init(code: "N", title: "residence.status.ch.n".localized, detail: "residence.detail.asylum".localized),
                .init(code: "L", title: "residence.status.ch.l".localized, detail: "residence.detail.short_term".localized),
                .init(code: PermitType.other.rawValue, title: "residence.status.other".localized, detail: "residence.detail.other".localized)
            ]
        case .germany:
            return [
                .init(code: "temporary_protection_24", title: "§24 AufenthG", detail: "residence.detail.temporary_protection".localized),
                .init(code: "residence_permit", title: "Aufenthaltserlaubnis", detail: "residence.detail.residence_permit".localized),
                .init(code: "permanent_residence", title: "Niederlassungserlaubnis", detail: "residence.detail.permanent_residence".localized),
                .init(code: "eu_eea", title: "EU/EWR", detail: "residence.detail.free_movement".localized),
                .init(code: "asylum", title: "Asylverfahren", detail: "residence.detail.asylum".localized),
                .init(code: "other", title: "residence.status.other".localized, detail: "residence.detail.other".localized)
            ]
        case .austria:
            return [
                .init(code: "displaced_person", title: "Ausweis für Vertriebene", detail: "residence.detail.temporary_protection".localized),
                .init(code: "residence_permit", title: "Aufenthaltstitel", detail: "residence.detail.residence_permit".localized),
                .init(code: "red_white_red", title: "Rot-Weiß-Rot", detail: "residence.detail.work_and_residence".localized),
                .init(code: "eu_eea", title: "EU/EWR", detail: "residence.detail.free_movement".localized),
                .init(code: "asylum", title: "Asylverfahren", detail: "residence.detail.asylum".localized),
                .init(code: "other", title: "residence.status.other".localized, detail: "residence.detail.other".localized)
            ]
        }
    }

    static func subdivisionName(country: ResidenceCountry, code: String) -> String {
        subdivisions(for: country).first(where: { $0.code == code })?.name ?? code
    }

    static func currency(_ amountMinor: Int, country: ResidenceCountry) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = country.currencyCode
        formatter.locale = Locale(identifier: country.localeIdentifier)
        return formatter.string(from: NSNumber(value: Double(amountMinor) / 100))
            ?? "\(country.currencyCode) \(Double(amountMinor) / 100)"
    }
}
