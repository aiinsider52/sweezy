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
    let accountManager: AccountManager
    let errorHandler: ErrorHandlingService
    let userStats: UserStatsService
    let localizationService: any LocalizationServiceProtocol
    let gamification: GamificationService
    let analytics: AnalyticsService
    let lifeAdmin: LifeAdminService
    let savedItems: SavedItemsService
    let chatStore: ChatStore
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
            let service = LocationService()
            service.objectWillChange
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
            _locationService = service
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

    private var _appointmentRepository: AppointmentRepository?
    var appointmentRepository: AppointmentRepository {
        if _appointmentRepository == nil {
            _appointmentRepository = AppointmentRepository(notificationService: notificationService)
        }
        return _appointmentRepository!
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
    
    // MARK: - State
    @Published var isOnboardingCompleted: Bool
    @Published var hasCompletedInitialAuthChoice: Bool
    @Published var shouldPresentInitialAuthEntry: Bool
    @Published var currentLocale: Locale
    @Published var userProfile: UserProfile?
    
    private var cancellables = Set<AnyCancellable>()
    private var hasStartedInitialContentLoad = false
    
    init() {
        // Initialize only lightweight services synchronously
        self.accountManager = AccountManager()
        self.errorHandler = ErrorHandlingService()
        self.userStats = UserStatsService()
        self.localizationService = LocalizationService()
        self.gamification = GamificationService()
        let telemetry = TelemetryService()
        self.telemetry = telemetry
        self.analytics = AnalyticsService(telemetry: telemetry)
        self.lifeAdmin = LifeAdminService()
        self.savedItems = SavedItemsService()
        self.chatStore = ChatStore()
        
        // Configure a modest URLCache to improve offline behavior
        let mem = 50 * 1024 * 1024 // 50 MB
        let disk = 150 * 1024 * 1024 // 150 MB
        URLCache.shared = URLCache(memoryCapacity: mem, diskCapacity: disk)
        
        // Initialize state from UserDefaults (fast)
        let launchArguments = ProcessInfo.processInfo.arguments
        if launchArguments.contains("--reset-ui-test-state") {
            [
                "onboarding_completed",
                "initial_auth_choice_completed",
                "pending_initial_auth_entry",
                "selected_locale",
                "preferredLanguage",
                "userName",
                "userEmail",
                "isRegistered",
                "biometricsEnabled"
            ].forEach(UserDefaults.standard.removeObject(forKey:))
            KeychainStore.delete("access_token")
            KeychainStore.delete("refresh_token")
            KeychainStore.delete("user_id")
        } else if launchArguments.contains("--reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: "onboarding_completed")
        }
        self.isOnboardingCompleted = UserDefaults.standard.bool(forKey: "onboarding_completed")
        self.hasCompletedInitialAuthChoice = UserDefaults.standard.bool(forKey: "initial_auth_choice_completed")
        self.shouldPresentInitialAuthEntry = UserDefaults.standard.bool(forKey: "pending_initial_auth_entry")
        
        // Prefer previously selected locale, otherwise **always default to Ukrainian**.
        // We intentionally do NOT follow system language so that:
        // - First launch: все контенты и UI будут українською
        // - Only after explicit language selection in onboarding мы змінюємо мову
        let savedLocale = UserDefaults.standard.string(forKey: "selected_locale") ?? "uk"
        self.currentLocale = Locale(identifier: savedLocale)
        // Keep localization service in sync with the same initial locale
        self.localizationService.setLocale(self.currentLocale)
        
        // Load the protected, account-scoped profile (with one-time soft migration).
        loadUserProfileForCurrentScope()
        lifeAdmin.prepareDocuments(for: userProfile)
        
        setupBindings()
        
        // Onboarding does not consume the content catalog. Deferring its many
        // network requests and JSON files keeps first-launch controls responsive,
        // especially on older devices.
        if isOnboardingCompleted {
            startInitialContentLoadIfNeeded()
            _ = roadmapSync
        }
        
        // App started
        telemetry.info("app_started", source: "app", message: "AppContainer initialized")
    }
    
    private func setupBindings() {
        // Forward nested store changes so screens observing AppContainer refresh immediately.
        lifeAdmin.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        savedItems.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Save locale changes
        $currentLocale
            .dropFirst() // Skip initial value
            .sink { [weak self] locale in
                guard let self else { return }
                UserDefaults.standard.set(locale.identifier, forKey: "selected_locale")
                self.localizationService.setLocale(locale)
                guard self.isOnboardingCompleted else { return }
                Task { @MainActor in
                    await self.contentService.loadLocalizedContent(for: locale.identifier)
                }
            }
            .store(in: &cancellables)
        
        // Save profile changes
        $userProfile
            .sink { profile in
                if let profile,
                   let data = try? JSONEncoder().encode(profile) {
                    try? ProtectedLocalStore.write(data, for: AccountScopedStorage.userProfileKey)
                } else {
                    ProtectedLocalStore.remove(
                        AccountScopedStorage.userProfileKey,
                        legacyDefaultsKey: AccountScopedStorage.userProfileKey
                    )
                }
                self.lifeAdmin.prepareDocuments(for: profile)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .accountScopeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadUserProfileForCurrentScope()
            }
            .store(in: &cancellables)
    }
    
    func completeOnboarding() {
        isOnboardingCompleted = true
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        shouldPresentInitialAuthEntry = true
        UserDefaults.standard.set(true, forKey: "pending_initial_auth_entry")
        startInitialContentLoadIfNeeded()
        _ = roadmapSync
    }

    func markInitialAuthChoiceCompleted() {
        hasCompletedInitialAuthChoice = true
        UserDefaults.standard.set(true, forKey: "initial_auth_choice_completed")
        shouldPresentInitialAuthEntry = false
        UserDefaults.standard.set(false, forKey: "pending_initial_auth_entry")
    }
    
    func updateLocale(_ locale: Locale) {
        guard currentLocale.identifier != locale.identifier else { return }
        currentLocale = locale
    }

    private func startInitialContentLoadIfNeeded() {
        guard !hasStartedInitialContentLoad else { return }
        hasStartedInitialContentLoad = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Let the first interactive frame commit before any local decoding.
            await Task.yield()
            let service = self.contentService
            await service.loadContent()
            await service.loadLocalizedContent(for: self.currentLocale.identifier)
        }
    }

    private func loadUserProfileForCurrentScope() {
        if let profileData = ProtectedLocalStore.data(
            for: AccountScopedStorage.userProfileKey,
            migratingFrom: AccountScopedStorage.userProfileKey
        ),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            userProfile = profile
        } else {
            userProfile = nil
        }
    }
}
