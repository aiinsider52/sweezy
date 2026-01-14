//
//  ContentService.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import Combine

/// Protocol for content management
@MainActor
protocol ContentServiceProtocol: ObservableObject {
    var guides: [Guide] { get }
    var checklists: [Checklist] { get }
    var places: [Place] { get }
    var templates: [DocumentTemplate] { get }
    var benefitRules: [BenefitRule] { get }
    var news: [NewsItem] { get }
    var isLoading: Bool { get }
    var lastUpdated: Date? { get }
    
    func loadContent() async
    func refreshContent() async
    func searchGuides(query: String, category: GuideCategory?, canton: Canton?) -> [Guide]
    func searchPlaces(query: String, type: PlaceType?, canton: Canton?) -> [Place]
    func latestNews(limit: Int, language: String?) -> [NewsItem]
    func getGuide(by id: UUID) -> Guide?
    func getChecklist(by id: UUID) -> Checklist?
    func getPlace(by id: UUID) -> Place?
    func getTemplate(by id: UUID) -> DocumentTemplate?
    
    // Multi-language content access
    func getGuidesForLocale(_ locale: String) -> [Guide]
    func getChecklistsForLocale(_ locale: String) -> [Checklist]
    func getTemplatesForLocale(_ locale: String) -> [DocumentTemplate]
    func getBenefitRulesForLocale(_ locale: String) -> [BenefitRule]
    func loadLocalizedContent(for language: String) async
}

/// Content service implementation with local JSON and remote updates
@MainActor
class ContentService: ContentServiceProtocol {
    @Published var guides: [Guide] = []
    @Published var checklists: [Checklist] = []
    @Published var places: [Place] = []
    @Published var templates: [DocumentTemplate] = []
    @Published var benefitRules: [BenefitRule] = []
    @Published var news: [NewsItem] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    
    private let fileManager = FileManager.default
    private let bundle: Bundle
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    // Preferred language for localized content; defaults to Ukrainian until user explicitly changes язык
    private var preferredLanguage: String = (UserDefaults.standard.string(forKey: "selected_locale") ?? "uk")
    // Флаг: guides были успешно загружены з бекенду (Render). Если true — не перезаписываем их локальними JSON.
    private var didLoadRemoteGuides: Bool = false
    private let errorHandler: any ErrorHandlingServiceProtocol
    
    private var cacheDirectory: URL {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("SweezyContent")
    }
    
    init(bundle: Bundle = .main, errorHandler: (any ErrorHandlingServiceProtocol)? = nil, autoLoad: Bool = true) {
        self.bundle = bundle
        self.errorHandler = errorHandler ?? ErrorHandlingService()
        setupDecoder()
        createCacheDirectoryIfNeeded()
        if autoLoad {
            Task { [weak self] in
                await self?.loadContent()
            }
        }
    }
    
    private func setupDecoder() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
    }
    
    private func createCacheDirectoryIfNeeded() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func loadContent() async {
        isLoading = true
        // Load content in parallel for better startup time
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadGuides() }
            group.addTask { await self.loadChecklists() }
            group.addTask { await self.loadPlaces() }
            group.addTask { await self.loadTemplates() }
            group.addTask { await self.loadBenefitRules() }
            group.addTask { await self.loadNews() }
            await group.waitForAll()
        }
        lastUpdated = Date()
        isLoading = false
    }
    
    func refreshContent() async {
        // Reload                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  base content, then re‑apply localization for the preferred language
        await loadContent()
        await loadLocalizedContent(for: preferredLanguage)
    }
    
    // MARK: - Search Methods
    
    func searchGuides(query: String, category: GuideCategory? = nil, canton: Canton? = nil) -> [Guide] {
        var results = guides
        if let category = category {
            results = results.filter { $0.category == category }
        }
        if let canton = canton {
            results = results.filter { $0.appliesTo(canton: canton) }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            return results.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.lastUpdated > rhs.lastUpdated
            }
        }
        return results
            .map { guide -> (Guide, Double) in
                let relevance = guide.searchRelevance(for: q)
                let priorityWeight = Double(guide.priority) * 2.0
                let days = max(1.0, Date().timeIntervalSince(guide.lastUpdated) / 86400.0)
                let freshnessWeight = max(0.0, 5.0 - log(days))
                return (guide, relevance * 10.0 + priorityWeight + freshnessWeight)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
    
    func searchPlaces(query: String, type: PlaceType? = nil, canton: Canton? = nil) -> [Place] {
        var filteredPlaces = places
        
        // Filter by type
        if let type = type {
            filteredPlaces = filteredPlaces.filter { $0.type == type }
        }
        
        // Filter by canton
        if let canton = canton {
            filteredPlaces = filteredPlaces.filter { $0.canton == canton }
        }
        
        // Search by query
        if !query.isEmpty {
            let lowercaseQuery = query.lowercased()
            filteredPlaces = filteredPlaces.filter { place in
                place.name.lowercased().contains(lowercaseQuery) ||
                place.description?.lowercased().contains(lowercaseQuery) == true ||
                place.services.contains { $0.lowercased().contains(lowercaseQuery) }
            }
        }
        
        return filteredPlaces
    }
    
    // MARK: - Getter Methods
    
    func getGuide(by id: UUID) -> Guide? {
        guides.first { $0.id == id }
    }
    
    func getChecklist(by id: UUID) -> Checklist? {
        checklists.first { $0.id == id }
    }
    
    func getPlace(by id: UUID) -> Place? {
        places.first { $0.id == id }
    }
    
    func getTemplate(by id: UUID) -> DocumentTemplate? {
        templates.first { $0.id == id }
    }
    
    func latestNews(limit: Int = 5, language: String? = nil) -> [NewsItem] {
        var items = news.sorted { $0.publishedAt > $1.publishedAt }
        if let lang = language {
            items = items.filter { $0.language == lang }
        }
        return Array(items.prefix(limit))
    }
    
    // MARK: - Private Loading Methods
    
    private func loadGuides() async {
        do {
            // 1) Пробуем забрать всі гайды з бекенду (публічний ендпоінт /api/v1/guides).
            //    Якщо є access_token у Keychain — він буде доданий автоматично як Bearer.
            do {
                let remote = try await APIClient.fetchGuides()
                if !remote.isEmpty {
                    self.guides = remote.map { g in
                        Guide(
                            title: g.title,
                            subtitle: g.description,
                            bodyMarkdown: g.content ?? "",
                            tags: [],
                            category: GuideCategory(rawValue: g.category ?? "documents") ?? .documents,
                            cantonCodes: [],
                            links: [],
                            priority: 0,
                            isNew: false,
                            estimatedReadingTime: 5,
                            // Сейчас весь контент з бекенду українською, тому ставимо language = "uk".
                            // Коли з'являться інші мови, бекенд отримає окреме поле language,
                            // і меппінг тут можна буде оновити.
                            language: "uk",
                            verifiedAt: nil,
                            source: nil,
                            heroImage: g.image_url
                        )
                    }
                    didLoadRemoteGuides = true
                    try? saveToCache(self.guides, filename: "guides.json")
                } else {
                    // 2) Якщо бекенд повернув пустий список — падаємо на локальний JSON / cache.
                    if let bundleGuides = try loadFromBundle("guides.json", type: [Guide].self) {
                        guides = bundleGuides
                        try? saveToCache(guides, filename: "guides.json")
                    } else if let cachedGuides = try loadFromCache("guides.json", type: [Guide].self) {
                        guides = cachedGuides
                    }
                }
            } catch {
                // 3) На будь-яку помилку мережі — використовуємо локальний контент.
                if let bundleGuides = try loadFromBundle("guides.json", type: [Guide].self) {
                    guides = bundleGuides
                    try? saveToCache(guides, filename: "guides.json")
                } else if let cachedGuides = try loadFromCache("guides.json", type: [Guide].self) {
                    guides = cachedGuides
                }
            }
            await loadAdditionalGuides()
        } catch {
            print("Error loading guides: \(error)")
            guides = []
        }
    }
    
    private func loadChecklists() async {
        do {
            if let token = KeychainStore.get("access_token"), !token.isEmpty {
                do {
                    let remote = try await APIClient.fetchChecklists()
                    if !remote.isEmpty {
                        self.checklists = remote.enumerated().map { idx, c in
                            let steps: [ChecklistStep] = c.items.enumerated().map { i, s in
                                ChecklistStep(
                                    title: s,
                                    description: s,
                                    estimatedTime: nil,
                                    isOptional: false,
                                    links: [],
                                    requiredDocuments: [],
                                    tips: [],
                                    order: i
                                )
                            }
                            return Checklist(
                                title: c.title,
                                description: c.description ?? "",
                                category: .integration,
                                estimatedDuration: "—",
                                difficulty: .medium,
                                steps: steps,
                                tags: [],
                                cantonCodes: [],
                                priority: 0,
                                isNew: false,
                                language: nil,
                                verifiedAt: nil,
                                source: nil,
                                heroImage: nil
                            )
                        }
                        try? saveToCache(self.checklists, filename: "checklists.json")
                    } else if let bundleChecklists = try loadFromBundle("checklists.json", type: [Checklist].self) {
                        checklists = bundleChecklists
                        try? saveToCache(checklists, filename: "checklists.json")
                    } else if let cachedChecklists = try loadFromCache("checklists.json", type: [Checklist].self) {
                        checklists = cachedChecklists
                    }
                } catch {
                    if let bundleChecklists = try loadFromBundle("checklists.json", type: [Checklist].self) {
                        checklists = bundleChecklists
                        try? saveToCache(checklists, filename: "checklists.json")
                    } else if let cachedChecklists = try loadFromCache("checklists.json", type: [Checklist].self) {
                        checklists = cachedChecklists
                    }
                }
            } else {
                if let bundleChecklists = try loadFromBundle("checklists.json", type: [Checklist].self) {
                    checklists = bundleChecklists
                    try? saveToCache(checklists, filename: "checklists.json")
                } else if let cachedChecklists = try loadFromCache("checklists.json", type: [Checklist].self) {
                    checklists = cachedChecklists
                }
            }
            await loadAdditionalChecklists()
        } catch {
            print("Error loading checklists: \(error)")
            checklists = []
        }
    }
    
    private func loadPlaces() async {
        do {
            if let bundlePlaces = try loadFromBundle("places.json", type: [Place].self) {
                places = bundlePlaces
                try? saveToCache(places, filename: "places.json")
            } else if let cachedPlaces = try loadFromCache("places.json", type: [Place].self) {
                places = cachedPlaces
            }
            await loadAdditionalPlaces()
        } catch {
            print("Error loading places: \(error)")
            places = []
        }
    }
    
    private func loadTemplates() async {
        do {
            if let token = KeychainStore.get("access_token"), !token.isEmpty {
                do {
                    let remote = try await APIClient.fetchTemplates()
                    if !remote.isEmpty {
                        self.templates = remote.map { t in
                            DocumentTemplate(
                                title: t.name,
                                description: "",
                                category: .government,
                                templateType: .letter,
                                content: t.content,
                                placeholders: []
                            )
                        }
                        try? saveToCache(self.templates, filename: "templates.json")
                    } else if let bundleTemplates = try loadFromBundle("templates.json", type: [DocumentTemplate].self) {
                        templates = bundleTemplates
                        try? saveToCache(templates, filename: "templates.json")
                    } else if let cachedTemplates = try loadFromCache("templates.json", type: [DocumentTemplate].self) {
                        templates = cachedTemplates
                    }
                } catch {
                    if let bundleTemplates = try loadFromBundle("templates.json", type: [DocumentTemplate].self) {
                        templates = bundleTemplates
                        try? saveToCache(templates, filename: "templates.json")
                    } else if let cachedTemplates = try loadFromCache("templates.json", type: [DocumentTemplate].self) {
                        templates = cachedTemplates
                    }
                }
            } else {
                if let bundleTemplates = try loadFromBundle("templates.json", type: [DocumentTemplate].self) {
                    templates = bundleTemplates
                    try? saveToCache(templates, filename: "templates.json")
                } else if let cachedTemplates = try loadFromCache("templates.json", type: [DocumentTemplate].self) {
                    templates = cachedTemplates
                }
            }
            await loadAdditionalTemplates()
        } catch {
            print("Error loading templates: \(error)")
            templates = []
        }
    }
    
    private func loadBenefitRules() async {
        do {
            if let bundleRules = try loadFromBundle("benefit_rules.json", type: [BenefitRule].self) {
                benefitRules = bundleRules
                try? saveToCache(benefitRules, filename: "benefit_rules.json")
            } else if let cachedRules = try loadFromCache("benefit_rules.json", type: [BenefitRule].self) {
                benefitRules = cachedRules
            }
            await loadAdditionalBenefitRules()
        } catch {
            print("Error loading benefit rules: \(error)")
            benefitRules = []
        }
    }
    
    private func loadNews() async {
        do {
            if let token = KeychainStore.get("access_token"), !token.isEmpty {
                do {
                    let remote = try await APIClient.fetchNews(limit: 50, language: preferredLanguage)
                    if !remote.isEmpty {
                        self.news = remote.map { n in
                            let parsedDate: Date = {
                                let iso = ISO8601DateFormatter()
                                if let d = iso.date(from: n.published_at) { return d }
                                let f = DateFormatter()
                                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                                f.timeZone = TimeZone(abbreviation: "UTC")
                                return f.date(from: n.published_at) ?? Date()
                            }()
                            return NewsItem(
                                title: n.title,
                                summary: n.summary,
                                url: n.url,
                                content: n.content,
                                source: n.source,
                                language: n.language,
                                publishedAt: parsedDate,
                                tags: [],
                                imageURL: n.image_url
                            )
                        }
                        try? saveToCache(self.news, filename: "news.json")
                    } else if let bundled = try loadFromBundle("news.json", type: [NewsItem].self) {
                        news = bundled
                        try? saveToCache(news, filename: "news.json")
                    } else if let cached = try loadFromCache("news.json", type: [NewsItem].self) {
                        news = cached
                    }
                } catch {
                    if let bundled = try loadFromBundle("news.json", type: [NewsItem].self) {
                        news = bundled
                        try? saveToCache(news, filename: "news.json")
                    } else if let cached = try loadFromCache("news.json", type: [NewsItem].self) {
                        news = cached
                    }
                }
            } else {
                if let bundled = try loadFromBundle("news.json", type: [NewsItem].self) {
                    news = bundled
                    try? saveToCache(news, filename: "news.json")
                } else if let cached = try loadFromCache("news.json", type: [NewsItem].self) {
                    news = cached
                }
            }
            await loadAdditionalNews()
        } catch {
            print("Error loading news: \\(error)")
            news = []
        }
    }

    // MARK: - Cache Management
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
    }
    func resetContent() async {
        clearCache()
        await loadContent()
    }

    // MARK: - Additional seed loading (optional *_extra / *_ru / *_en / *_new files)
    private func loadAdditionalGuides(language: String? = nil) async {
        _ = language // reserved for future use
        
        // Load all language-specific guides to have comprehensive multilingual content
        // Order matters: category-specific guides first, then comprehensive, then basic, then extras
        let languageFiles = [
            // Category-specific comprehensive guides (6+ per category, all languages)
            "guides_documents_all.json",
            "guides_housing_all.json",
            "guides_work_finance_all.json",
            "guides_health_insurance_all.json",
            // Education & Integration - all three languages
            "guides_education_integration_all.json",
            "guides_education_integration_en.json",
            "guides_education_integration_de.json",
            // Legal & Emergency
            "guides_legal_emergency_all.json",
            // Transport & Banking
            "guides_transport_banking_all.json",
            // Comprehensive insider guides
            "guides_comprehensive_uk.json",
            "guides_comprehensive_en.json",
            "guides_comprehensive_de.json",
            // Basic guides
            "guides_uk.json",
            "guides_en.json", 
            "guides_de.json",
            // Extended/extra content
            "guides_expanded_uk.json",
            "guides_extra.json"
        ]
        
        for filename in languageFiles {
            if let extra = try? loadFromBundle(filename, type: [Guide].self) {
                // Avoid duplicates by checking ID
                let existingIDs = Set(guides.map { $0.id })
                let newGuides = extra.filter { !existingIDs.contains($0.id) }
                guides.append(contentsOf: newGuides)
                print("📚 Loaded \(newGuides.count) guides from \(filename)")
            } else if let cached = try? loadFromCache(filename, type: [Guide].self) {
                let existingIDs = Set(guides.map { $0.id })
                let newGuides = cached.filter { !existingIDs.contains($0.id) }
                guides.append(contentsOf: newGuides)
                print("📚 Loaded \(newGuides.count) cached guides from \(filename)")
            }
        }
        
        print("📚 Total guides loaded: \(guides.count)")
    }
    private func loadAdditionalChecklists(language: String? = nil) async {
        _ = language // reserved for future language-specific extras
        for filename in ["checklists_extra.json"] {
            if let extra = try? loadFromBundle(filename, type: [Checklist].self) {
                checklists.append(contentsOf: extra)
            } else if let cached = try? loadFromCache(filename, type: [Checklist].self) {
                checklists.append(contentsOf: cached)
            }
        }
    }
    private func loadAdditionalPlaces() async {
        // Load all additional place files including Ukrainian community hubs
        let placeFiles = [
            "places_extra.json",
            "places_new.json",
            "places_ukrainian_community.json"
        ]
        
        for filename in placeFiles {
            if let extra = try? loadFromBundle(filename, type: [Place].self) {
                // Avoid duplicates by ID
                let existingIDs = Set(places.map { $0.id })
                let newPlaces = extra.filter { !existingIDs.contains($0.id) }
                places.append(contentsOf: newPlaces)
            } else if let cached = try? loadFromCache(filename, type: [Place].self) {
                let existingIDs = Set(places.map { $0.id })
                let newPlaces = cached.filter { !existingIDs.contains($0.id) }
                places.append(contentsOf: newPlaces)
            }
        }
    }
    private func loadAdditionalTemplates() async {
        for filename in ["templates_extra.json", "templates_new.json", "templates_bilingual.json"] {
            if let extra = try? loadFromBundle(filename, type: [DocumentTemplate].self) {
                // Avoid duplicates by ID
                let existingIDs = Set(templates.map { $0.id })
                let newTemplates = extra.filter { !existingIDs.contains($0.id) }
                templates.append(contentsOf: newTemplates)
            } else if let cached = try? loadFromCache(filename, type: [DocumentTemplate].self) {
                let existingIDs = Set(templates.map { $0.id })
                let newTemplates = cached.filter { !existingIDs.contains($0.id) }
                templates.append(contentsOf: newTemplates)
            }
        }
    }
    private func loadAdditionalNews() async {
        if let extra = try? loadFromBundle("news_extra.json", type: [NewsItem].self) {
            news.append(contentsOf: extra)
        } else if let cached = try? loadFromCache("news_extra.json", type: [NewsItem].self) {
            news.append(contentsOf: cached)
        }
    }
    private func loadAdditionalBenefitRules() async {
        for filename in ["benefit_rules_new.json"] {
            if let extra = try? loadFromBundle(filename, type: [BenefitRule].self) {
                benefitRules.append(contentsOf: extra)
            } else if let cached = try? loadFromCache(filename, type: [BenefitRule].self) {
                benefitRules.append(contentsOf: cached)
            }
        }
    }
    
    // MARK: - File System Helpers
    
    private func loadFromCache<T: Codable>(_ filename: String, type: T.Type) throws -> T? {
        let url = cacheDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }
    
    private func loadFromBundle<T: Codable>(_ filename: String, type: T.Type) throws -> T? {
        let resourceName = filename.replacingOccurrences(of: ".json", with: "")
        
        // First: try root of bundle (where we just copied files)
        if let url = bundle.url(forResource: resourceName, withExtension: "json") {
            #if DEBUG
            print("✅ Found \(filename) in bundle root")
            #endif
            do {
                let data = try Data(contentsOf: url)
                return try decoder.decode(type, from: data)
            } catch let error as DecodingError {
                errorHandler.handle(.decodingError(error))
                throw error
            } catch {
                errorHandler.handle(.contentLoadFailed(filename))
                throw error
            }
        }
        
        // Try subdirectories as fallback
        let possiblePaths = [
            "AppContent/seeds",
            "Resources/AppContent/seeds",
            "seeds"
        ]
        
        for subdirectory in possiblePaths {
            if let url = bundle.url(forResource: resourceName, withExtension: "json", subdirectory: subdirectory) {
                #if DEBUG
                print("✅ Found \(filename) in bundle at \(subdirectory)")
                #endif
                do {
                    let data = try Data(contentsOf: url)
                    return try decoder.decode(type, from: data)
                } catch let error as DecodingError {
                    errorHandler.handle(.decodingError(error))
                    throw error
                } catch {
                    errorHandler.handle(.contentLoadFailed(filename))
                    throw error
                }
            }
        }
        
        #if DEBUG
        print("⚠️ Could not find \(filename) in bundle (searched root + subdirectories)")
        #endif
        errorHandler.handle(.fileNotFound(filename))
        return nil
    }
    
    private func saveToCache<T: Codable>(_ object: T, filename: String) throws {
        let url = cacheDirectory.appendingPathComponent(filename)
        let data = try encoder.encode(object)
        try data.write(to: url)
    }
    
    // MARK: - Multi-language Content Access
    
    /// Get guides for a specific locale.
    ///
    /// Returns guides in the following priority:
    /// 1. Exact language match (e.g., "en" for English)
    /// 2. Fallback to Ukrainian ("uk") if no translation exists
    /// 3. Any guide without language specified
    ///
    /// Each unique guide topic is shown only once in the best available language.
    func getGuidesForLocale(_ locale: String) -> [Guide] {
        let normalizedLocale = normalizeLocale(locale)
        
        // First, try to get guides matching the requested language
        let matchingGuides = guides.filter { guide in
            guard let lang = guide.language?.lowercased() else { return false }
            return lang == normalizedLocale || guide.tags.contains("lang:\(normalizedLocale)")
        }
        
        if !matchingGuides.isEmpty {
            return matchingGuides.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.lastUpdated > rhs.lastUpdated
            }
        }
        
        // Fallback to Ukrainian if no exact match
        let ukrainianGuides = guides.filter { guide in
            guard let lang = guide.language?.lowercased() else { return true } // nil = Ukrainian
            return lang == "uk" || guide.tags.contains("lang:uk")
        }
        
        if !ukrainianGuides.isEmpty {
            return ukrainianGuides.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.lastUpdated > rhs.lastUpdated
            }
        }
        
        // Ultimate fallback: return all guides sorted by priority
        return guides.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.lastUpdated > rhs.lastUpdated
        }
    }
    
    /// Get checklists for a specific locale with fallback to Ukrainian
    func getChecklistsForLocale(_ locale: String) -> [Checklist] {
        let normalizedLocale = normalizeLocale(locale)
        
        let exactMatches = checklists.filter { $0.language == normalizedLocale }
        if !exactMatches.isEmpty {
            return exactMatches.sorted { $0.priority > $1.priority }
        }
        
        let ukrainianMatches = checklists.filter { $0.language == "uk" || $0.language == nil }
        if !ukrainianMatches.isEmpty {
            return ukrainianMatches.sorted { $0.priority > $1.priority }
        }
        
        return checklists.sorted { $0.priority > $1.priority }
    }
    
    /// Get templates for a specific locale with fallback
    func getTemplatesForLocale(_ locale: String) -> [DocumentTemplate] {
        let normalizedLocale = normalizeLocale(locale)
        
        // Templates already have language field, use it
        let exactMatches = templates.filter { $0.language == normalizedLocale }
        if !exactMatches.isEmpty {
            return exactMatches
        }
        
        // Fallback to Ukrainian or English
        let fallbackMatches = templates.filter { $0.language == "uk" || $0.language == "en" }
        if !fallbackMatches.isEmpty {
            return fallbackMatches
        }
        
        return templates
    }
    
    /// Get benefit rules for a specific locale with fallback
    func getBenefitRulesForLocale(_ locale: String) -> [BenefitRule] {
        let normalizedLocale = normalizeLocale(locale)
        
        let exactMatches = benefitRules.filter { $0.language == normalizedLocale }
        if !exactMatches.isEmpty {
            return exactMatches
        }
        
        let ukrainianMatches = benefitRules.filter { $0.language == "uk" || $0.language == nil }
        if !ukrainianMatches.isEmpty {
            return ukrainianMatches
        }
        
        return benefitRules
    }
    
    // MARK: - Helpers
    
    /// Normalize locale code (e.g., "en_US" -> "en", "ru-RU" -> "ru")
    private func normalizeLocale(_ locale: String) -> String {
        let components = locale.split(separator: "_")
        if let first = components.first {
            return String(first).lowercased()
        }
        return locale.lowercased()
    }
    
    /// Sort guides by priority and date
    private func sortedByPriority(_ guides: [Guide]) -> [Guide] {
        return guides.sorted { guide1, guide2 in
            if guide1.priority != guide2.priority {
                return guide1.priority > guide2.priority
            }
            return guide1.lastUpdated > guide2.lastUpdated
        }
    }

    // MARK: - Localized content loader
    func loadLocalizedContent(for language: String) async {
        let lang = normalizeLocale(language)
        
        // Load ALL guides from all language files to have comprehensive multilingual content.
        // This ensures users can access any guide in their preferred language, even when the
        // backend is unavailable and we rely purely on bundled JSON.
        if !didLoadRemoteGuides {
            var allGuides: [Guide] = []
            var seenIDs = Set<UUID>()
            
            // Priority order: requested language first, then Ukrainian, then other languages,
            // then legacy/base files. Category‑specific *_all.json bundles contain guides for
            // multiple languages and are always included.
            let languageFiles = [
                // 1) Language‑specific main files
                "guides_\(lang).json",
                "guides_uk.json",
                "guides_en.json",
                "guides_de.json",
                
                // 2) Category‑specific comprehensive guides (all languages in one file)
                "guides_documents_all.json",
                "guides_housing_all.json",
                "guides_work_finance_all.json",
                "guides_health_insurance_all.json",
                "guides_education_integration_all.json",
                "guides_education_integration_en.json",
                "guides_education_integration_de.json",
                "guides_legal_emergency_all.json",
                "guides_transport_banking_all.json",
                
                // 3) Comprehensive insider guides per language
                "guides_comprehensive_uk.json",
                "guides_comprehensive_en.json",
                "guides_comprehensive_de.json",
                
                // 4) Legacy/base content
                "guides.json",
                "guides_expanded_uk.json",
                "guides_extra.json"
            ]
            
            for filename in languageFiles {
                if let arr = try? self.loadFromBundle(filename, type: [Guide].self) {
                    for guide in arr where !seenIDs.contains(guide.id) {
                        allGuides.append(guide)
                        seenIDs.insert(guide.id)
                    }
                } else if let cached = try? self.loadFromCache(filename, type: [Guide].self) {
                    for guide in cached where !seenIDs.contains(guide.id) {
                        allGuides.append(guide)
                        seenIDs.insert(guide.id)
                    }
                }
            }
            
            self.guides = allGuides
        }
        self.preferredLanguage = lang

        // Load locale-specific checklists
        do {
            if let arr = try self.loadFromBundle("checklists_\(lang).json", type: [Checklist].self) {
                self.checklists = arr
            } else if let cached = try self.loadFromCache("checklists_\(lang).json", type: [Checklist].self) {
                self.checklists = cached
            } else if let fallback = try self.loadFromBundle("checklists.json", type: [Checklist].self) {
                // Fallback to base (Ukrainian) bundle content if locale-specific is missing
                self.checklists = fallback
            } else if let cachedFallback = try self.loadFromCache("checklists.json", type: [Checklist].self) {
                self.checklists = cachedFallback
            } else {
                // Keep existing content as last resort
                // (prevents empty UI if localized files are absent)
            }
        } catch {
            // Keep existing content on error to avoid blank lists
        }
        await self.loadAdditionalChecklists(language: lang)

        // Benefit rules (optional per language; missing file is not treated as error)
        if let url = bundle.url(forResource: "benefit_rules_\(lang)", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let arr = try? decoder.decode([BenefitRule].self, from: data) {
            self.benefitRules = arr
        } else if let cached = try? self.loadFromCache("benefit_rules_\(lang).json", type: [BenefitRule].self) {
            self.benefitRules = cached
        } else {
            // Keep existing benefitRules loaded from base files to avoid empty state and noisy errors
        }
        await self.loadAdditionalBenefitRules()
    }
}
