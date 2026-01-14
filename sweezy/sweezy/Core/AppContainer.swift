//
//  AppContainer.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI
import Combine

/// Main dependency injection container for the app
/// Uses lazy initialization for heavy services to prevent blocking app startup
@MainActor
class AppContainer: ObservableObject {
    // MARK: - Services (lightweight - safe to init immediately)
    let errorHandler: ErrorHandlingService
    let userStats: UserStatsService
    let localizationService: any LocalizationServiceProtocol
    let gamification: GamificationService
    let analytics: AnalyticsService
    let subscriptionManager: SubscriptionManager
    lazy var roadmapSync: RoadmapSyncService = RoadmapSyncService(app: self)
    let telemetry: TelemetryService
    lazy var performanceMonitor: PerformanceMonitorService = PerformanceMonitorService(telemetry: telemetry)
    
    // MARK: - Services (lazy - initialized on first access to avoid blocking startup)
    private var _contentService: ContentService?
    var contentService: any ContentServiceProtocol {
        if _contentService == nil {
            // We control loading manually to respect current locale
            _contentService = ContentService(bundle: .main, errorHandler: errorHandler, autoLoad: false)
        }
        return _contentService!
    }
    
    private var _locationService: LocationService?
    var locationService: any LocationServiceProtocol {
        if _locationService == nil {
            _locationService = LocationService()
        }
        return _locationService!
    }
    
    private var _notificationService: NotificationService?
    var notificationService: any NotificationServiceProtocol {
        if _notificationService == nil {
            let service = NotificationService()
            service.setupNotificationCategories()
            _notificationService = service
        }
        return _notificationService!
    }
    
    private var _calculatorService: CalculatorService?
    var calculatorService: any CalculatorServiceProtocol {
        if _calculatorService == nil {
            _calculatorService = CalculatorService()
        }
        return _calculatorService!
    }
    
    private var _remoteConfigService: RemoteConfigService?
    var remoteConfigService: any RemoteConfigServiceProtocol {
        if _remoteConfigService == nil {
            let service = RemoteConfigService()
            _remoteConfigService = service
        }
        return _remoteConfigService!
    }
    
    private var _firstWeekService: FirstWeekChecklistService?
    var firstWeekService: FirstWeekChecklistService {
        if _firstWeekService == nil {
            _firstWeekService = FirstWeekChecklistService()
        }
        return _firstWeekService!
    }
    
    private var _roadmapProgress: RoadmapProgressService?
    var roadmapProgress: RoadmapProgressService {
        if _roadmapProgress == nil {
            _roadmapProgress = RoadmapProgressService()
        }
        return _roadmapProgress!
    }
    
    private var _crashReporter: CrashReporterService?
    var crashReporter: CrashReporterService {
        if _crashReporter == nil {
            _crashReporter = CrashReporterService()
        }
        return _crashReporter!
    }
    
    private var _subscriptionLive: SubscriptionLiveService?
    var subscriptionLive: SubscriptionLiveService {
        if _subscriptionLive == nil {
            _subscriptionLive = SubscriptionLiveService(subscriptionManager: subscriptionManager)
        }
        return _subscriptionLive!
    }
    
    // MARK: - State
    @Published var isOnboardingCompleted: Bool
    @Published var currentLocale: Locale
    @Published var userProfile: UserProfile?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize only lightweight services synchronously
        self.errorHandler = ErrorHandlingService()
        self.userStats = UserStatsService()
        self.localizationService = LocalizationService()
        self.gamification = GamificationService()
        self.analytics = AnalyticsService()
        self.subscriptionManager = SubscriptionManager()
        self.telemetry = TelemetryService()
        
        // Configure a modest URLCache to improve offline behavior
        let mem = 50 * 1024 * 1024 // 50 MB
        let disk = 150 * 1024 * 1024 // 150 MB
        URLCache.shared = URLCache(memoryCapacity: mem, diskCapacity: disk)
        
        // Initialize state from UserDefaults (fast)
        if ProcessInfo.processInfo.arguments.contains("--reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: "onboarding_completed")
        }
        self.isOnboardingCompleted = UserDefaults.standard.bool(forKey: "onboarding_completed")
        
        // Prefer previously selected locale, otherwise **always default to Ukrainian**.
        // We intentionally do NOT follow system language so that:
        // - First launch: все контенты и UI будут українською
        // - Only after explicit language selection in onboarding мы змінюємо мову
        let savedLocale = UserDefaults.standard.string(forKey: "selected_locale") ?? "uk"
        self.currentLocale = Locale(identifier: savedLocale)
        // Keep localization service in sync with the same initial locale
        self.localizationService.setLocale(self.currentLocale)
        
        // Load user profile (fast - just UserDefaults read)
        if let profileData = UserDefaults.standard.data(forKey: "user_profile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            self.userProfile = profile
        }
        
        setupBindings()
        
        // Ensure content is loaded and then localized for the current locale
        Task { @MainActor [weak self] in
            guard let self else { return }
            let service = self.contentService
            await service.loadContent()
            await service.loadLocalizedContent(for: self.currentLocale.identifier)
        }
        
        // Activate roadmap sync lazily after init completes
        _ = roadmapSync
        
        // App started
        telemetry.info("app_started", source: "app", message: "AppContainer initialized")
    }
    
    private func setupBindings() {
        // Save locale changes
        $currentLocale
            .dropFirst() // Skip initial value
            .sink { [weak self] locale in
                guard let self else { return }
                UserDefaults.standard.set(locale.identifier, forKey: "selected_locale")
                self.localizationService.setLocale(locale)
                Task { @MainActor in
                    await self.contentService.loadLocalizedContent(for: locale.identifier)
                }
            }
            .store(in: &cancellables)
        
        // Save profile changes
        $userProfile
            .compactMap { $0 }
            .sink { profile in
                if let data = try? JSONEncoder().encode(profile) {
                    UserDefaults.standard.set(data, forKey: "user_profile")
                }
            }
            .store(in: &cancellables)
    }
    
    func completeOnboarding() {
        isOnboardingCompleted = true
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
    }
    
    func updateLocale(_ locale: Locale) {
        currentLocale = locale
        localizationService.setLocale(locale)
    }
}
