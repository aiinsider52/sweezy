//
//  RemoteConfigService.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import Combine

/// Protocol for remote configuration services
@MainActor
protocol RemoteConfigServiceProtocol: ObservableObject {
    var isUpdateAvailable: Bool { get }
    var lastUpdateCheck: Date? { get }
    var currentVersion: String { get }
    var remoteVersion: String? { get }
    
    func checkForUpdates() async
    func shouldUpdateContent() -> Bool
    func downloadUpdates() async -> Bool
    func getRemoteConfig() async -> RemoteConfig?
}

/// Remote configuration service implementation (mock for MVP)
@MainActor
class RemoteConfigService: RemoteConfigServiceProtocol {
    @Published var isUpdateAvailable: Bool = false
    @Published var lastUpdateCheck: Date?
    @Published var currentVersion: String = "1.0.0"
    @Published var remoteVersion: String?
    
    private var baseURL: String { APIClient.baseURL.absoluteString }
    private let httpClient: HTTPClient
    private let fileStorage: FileStorage
    private let clock: Clock
    private let decoder = JSONDecoder()
    
    init(
        httpClient: HTTPClient = URLSession.shared,
        fileStorage: FileStorage = DefaultFileStorage(),
        clock: Clock = SystemClock()
    ) {
        self.httpClient = httpClient
        self.fileStorage = fileStorage
        self.clock = clock
        setupDecoder()
    }
    
    /// Optional configuration entrypoint to trigger auto-checks from app start
    func configure(autoCheck: Bool = false) {
        if autoCheck {
            Task { [weak self] in
                await self?.checkForUpdates()
            }
        }
    }
    
    private func setupDecoder() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        decoder.dateDecodingStrategy = .formatted(formatter)
    }
    
    func checkForUpdates() async {
        lastUpdateCheck = Date()
        // Mock implementation - in real app, this would call actual API
        let config = await getRemoteConfig()
        if let config = config {
            remoteVersion = config.version
            isUpdateAvailable = isVersionNewer(config.version, than: currentVersion)
            if isUpdateAvailable {
                print("✅ Update available: \(config.version)")
            }
        }
    }
    
    /// Check if update is needed (returns true if >24h since last check or never checked)
    func shouldUpdateContent() -> Bool {
        guard let last = lastUpdateCheck else { return true }
        let dayInSeconds: TimeInterval = 24 * 60 * 60
        return clock.now.timeIntervalSince(last) > dayInSeconds
    }
    
    func downloadUpdates() async -> Bool {
        guard isUpdateAvailable else { return false }
        
        // Mock implementation - simulate download
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // In real implementation, this would:
            // 1. Download updated JSON files
            // 2. Validate the data
            // 3. Store in cache directory
            // 4. Update local version
            
            currentVersion = remoteVersion ?? currentVersion
            isUpdateAvailable = false
            
            return true
        } catch {
            print("Failed to download updates: \(error)")
            return false
        }
    }
    
    func getRemoteConfig() async -> RemoteConfig? {
        // Try backend first
        do {
            let url = APIClient.url("remote-config")
            let (data, response) = try await httpClient.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let backend = try JSONDecoder().decode(BackendRemoteConfig.self, from: data)
            // Map backend config to app model
            let endpoints: [String: String] = [
                "guides": APIClient.url("guides").absoluteString,
                "templates": APIClient.url("templates").absoluteString,
                "appointments": APIClient.url("appointments").absoluteString,
                "checklists": APIClient.url("checklists").absoluteString
            ]
            return RemoteConfig(
                version: backend.app_version,
                minSupportedVersion: "1.0.0",
                updateRequired: false,
                contentVersion: backend.app_version,
                features: backend.flags,
                endpoints: endpoints,
                maintenanceMode: false,
                maintenanceMessage: nil,
                announcements: [],
                lastUpdated: Date()
            )
        } catch {
            // Fallback to bundled file or mock
            if let url = Bundle.main.url(forResource: "remote_config", withExtension: "json", subdirectory: "AppContent/remote") {
                do {
                    let data = try Data(contentsOf: url)
                    return try decoder.decode(RemoteConfig.self, from: data)
                } catch {
                    print("Failed to load bundled remote config: \(error)")
                }
            }
            return createMockRemoteConfig()
        }
    }
    
    // MARK: - Private Helpers
    
    private func isVersionNewer(_ version1: String, than version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0
            
            if v1Value > v2Value {
                return true
            } else if v1Value < v2Value {
                return false
            }
        }
        
        return false // Versions are equal
    }
    
    private func createMockRemoteConfig() -> RemoteConfig {
        return RemoteConfig(
            version: "1.0.1",
            minSupportedVersion: "1.0.0",
            updateRequired: false,
            contentVersion: "2023.10.14",
            features: [
                "benefits_calculator": true,
                "appointment_reminders": true,
                "offline_maps": false,
                "push_notifications": true
            ],
            endpoints: [
                "guides": APIClient.url("guides").absoluteString,
                "places": APIClient.url("places").absoluteString,
                "templates": APIClient.url("templates").absoluteString,
                "benefit_rules": APIClient.url("benefit-rules").absoluteString
            ],
            maintenanceMode: false,
            maintenanceMessage: nil,
            announcements: [
                RemoteConfig.Announcement(
                    id: "welcome",
                    title: "Welcome to Sweezy",
                    message: "Your guide to life in Switzerland",
                    type: .info,
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                    targetLanguages: ["uk", "en", "de"]
                )
            ],
            lastUpdated: Date(),
            paywallDefaultPlan: "yearly",
            paywallBenefits: ["AI CV", "AI Letters", "Translations", "Unlimited saves", "PDF export"],
            reengageDays: [7, 14, 30]
        )
    }
}

// MARK: - Remote Config Model

struct RemoteConfig: Codable {
    let version: String
    let minSupportedVersion: String
    let updateRequired: Bool
    let contentVersion: String
    let features: [String: Bool]
    let endpoints: [String: String]
    let maintenanceMode: Bool
    let maintenanceMessage: String?
    let announcements: [Announcement]
    let lastUpdated: Date?
    // Paywall additions
    let paywallDefaultPlan: String?
    let paywallBenefits: [String]?
    // Engagement config
    let reengageDays: [Int]?
    
    init(
        version: String,
        minSupportedVersion: String,
        updateRequired: Bool,
        contentVersion: String,
        features: [String: Bool],
        endpoints: [String: String],
        maintenanceMode: Bool,
        maintenanceMessage: String? = nil,
        announcements: [Announcement] = [],
        lastUpdated: Date? = nil,
        paywallDefaultPlan: String? = nil,
        paywallBenefits: [String]? = nil,
        reengageDays: [Int]? = nil
    ) {
        self.version = version
        self.minSupportedVersion = minSupportedVersion
        self.updateRequired = updateRequired
        self.contentVersion = contentVersion
        self.features = features
        self.endpoints = endpoints
        self.maintenanceMode = maintenanceMode
        self.maintenanceMessage = maintenanceMessage
        self.announcements = announcements
        self.lastUpdated = lastUpdated ?? Date()
        self.paywallDefaultPlan = paywallDefaultPlan
        self.paywallBenefits = paywallBenefits
        self.reengageDays = reengageDays
    }
    
    struct Announcement: Codable, Identifiable {
        let id: String
        let title: String
        let message: String
        let type: AnnouncementType
        let startDate: Date
        let endDate: Date?
        let targetLanguages: [String]
        let actionTitle: String?
        let actionURL: String?
        
        init(
            id: String,
            title: String,
            message: String,
            type: AnnouncementType,
            startDate: Date,
            endDate: Date? = nil,
            targetLanguages: [String] = [],
            actionTitle: String? = nil,
            actionURL: String? = nil
        ) {
            self.id = id
            self.title = title
            self.message = message
            self.type = type
            self.startDate = startDate
            self.endDate = endDate
            self.targetLanguages = targetLanguages
            self.actionTitle = actionTitle
            self.actionURL = actionURL
        }
        
        var isActive: Bool {
            let now = Date()
            guard now >= startDate else { return false }
            
            if let endDate = endDate {
                return now <= endDate
            }
            
            return true
        }
        
        func isTargeted(for language: String) -> Bool {
            return targetLanguages.isEmpty || targetLanguages.contains(language)
        }
    }
    
    enum AnnouncementType: String, Codable {
        case info = "info"
        case warning = "warning"
        case update = "update"
        case maintenance = "maintenance"
        case feature = "feature"
        
        var iconName: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .update: return "arrow.down.circle"
            case .maintenance: return "wrench"
            case .feature: return "star"
            }
        }
        
        var color: String {
            switch self {
            case .info: return "blue"
            case .warning: return "orange"
            case .update: return "green"
            case .maintenance: return "red"
            case .feature: return "purple"
            }
        }
    }
    
    /// Check if a feature is enabled
    func isFeatureEnabled(_ feature: String) -> Bool {
        return features[feature] ?? false
    }
    
    /// Get endpoint URL for a service
    func getEndpoint(_ service: String) -> String? {
        return endpoints[service]
    }
    
    /// Get active announcements for a language
    func getActiveAnnouncements(for language: String) -> [Announcement] {
        return announcements.filter { announcement in
            announcement.isActive && announcement.isTargeted(for: language)
        }
    }
}

// MARK: - Content Update Manager

extension RemoteConfigService {
    /// Get content update URLs
    func getContentUpdateURLs() async -> [String: String] {
        guard let config = await getRemoteConfig() else { return [:] }
        
        return [
            "guides": config.getEndpoint("guides") ?? "",
            "places": config.getEndpoint("places") ?? "",
            "templates": config.getEndpoint("templates") ?? "",
            "benefit_rules": config.getEndpoint("benefit_rules") ?? ""
        ]
    }
    
    /// Download and cache updated content
    func updateContent(for contentType: String, from url: String) async -> Bool {
        guard let url = URL(string: url) else { return false }
        
        do {
            let (data, response) = try await httpClient.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            // Save to cache directory
            let cacheDirectory = fileStorage.cachesDirectory().appendingPathComponent("SweezyContent")
            try fileStorage.createDirectory(at: cacheDirectory)
            let fileName = "\(contentType).json"
            let fileURL = cacheDirectory.appendingPathComponent(fileName)
            try fileStorage.write(data: data, to: fileURL)
            
            print("Updated content for \(contentType)")
            return true
        } catch {
            print("Failed to update content for \(contentType): \(error)")
            return false
        }
    }
}

// MARK: - DI Protocols

protocol HTTPClient {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

protocol FileStorage {
    func cachesDirectory() -> URL
    func createDirectory(at url: URL) throws
    func write(data: Data, to url: URL) throws
}

struct DefaultFileStorage: FileStorage {
    func cachesDirectory() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }
    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func write(data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}

protocol Clock {
    var now: Date { get }
    func sleep(seconds: TimeInterval) async throws
}

struct SystemClock: Clock {
    var now: Date { Date() }
    func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
