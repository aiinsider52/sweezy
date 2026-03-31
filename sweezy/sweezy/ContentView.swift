//
//  SweezyApp.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI
import UserNotifications

@main
struct SweezyApp: App {
    @StateObject private var appContainer: AppContainer
    @StateObject private var themeManager: ThemeManager
    @StateObject private var lockManager: AppLockManager
    @StateObject private var sessionManager: SessionManager
    private static let appStartTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    init() {
        // We must build the object graph here so SessionManager can reference the same lockManager instance.
        let appContainer = AppContainer()
        let themeManager = ThemeManager()
        let lockManager = AppLockManager()
        _appContainer = StateObject(wrappedValue: appContainer)
        _themeManager = StateObject(wrappedValue: themeManager)
        _lockManager = StateObject(wrappedValue: lockManager)
        _sessionManager = StateObject(wrappedValue: SessionManager(lockManager: lockManager))

        AppLogger.debug("SweezyApp init started")
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppContent()
                .environmentObject(appContainer)
                .environmentObject(appContainer.accountManager)
                .environmentObject(appContainer.appointmentRepository)
                .environmentObject(themeManager)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
                .onAppear {
                    AppLogger.ui("App UI appeared")
                    if ProcessInfo.processInfo.environment["UITESTS"] != "1" {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
                    }
                    lockManager.loadBiometryType()
                    
                    AppReviewManager.recordFirstLaunchIfNeeded()
                    
                    // Start crash reporter (no-op if SDK absent)
                    appContainer.crashReporter.start()
                    appContainer.crashReporter.setUser(
                        id: KeychainStore.get("user_id"),
                        email: lockManager.userEmail,
                        username: lockManager.userName
                    )
                    
                    // Performance monitor + TTI
                    appContainer.performanceMonitor.start()
                    let tti = (CFAbsoluteTimeGetCurrent() - SweezyApp.appStartTime) * 1000
                    appContainer.telemetry.info("tti", source: "startup", message: nil, meta: ["ms": String(format: "%.0f", tti)])
                }
        }
    }
}

/// Main content view that shows the appropriate screen based on app state
struct MainAppContent: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showGlobalReset: Bool = false
    @State private var resetToken: String? = nil
    @State private var showPostOnboardingAuthEntry: Bool = false
    
    var body: some View {
        ZStack {
            Group {
                if appContainer.isOnboardingCompleted {
                    // IMPORTANT (App Store 5.1.1):
                    // Do NOT force account creation on launch.
                    // Guest users can access all public (non-account-based) content from the main app.
                    VStack(spacing: 0) {
                        OfflineBanner()
                        MainTabView()
                    }
                } else {
                    OnboardingViewRedesigned()
                }
            }
            .blur(radius: shouldShowLockOverlay ? 3 : 0)
            .disabled(shouldShowLockOverlay)
            
            if shouldShowLockOverlay {
                LockScreenOverlay()
                    .environmentObject(lockManager)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .environment(\.locale, appContainer.currentLocale)
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
        .onOpenURL { url in
            DeepLinkService.shared.handle(url: url)
        }
        .handleDeepLinks { link in
            handleDeepLink(link)
        }
        .sheet(isPresented: $showGlobalReset) {
            PasswordResetSheet(initialEmail: lockManager.userEmail, initialToken: resetToken)
        }
        .fullScreenCover(isPresented: $showPostOnboardingAuthEntry) {
            AuthEntryView(
                showsCloseButton: false,
                onComplete: {
                    appContainer.markInitialAuthChoiceCompleted()
                    showPostOnboardingAuthEntry = false
                }
            )
            .environment(\.locale, appContainer.currentLocale)
        }
        .onAppear {
            updatePostOnboardingAuthPresentation()
            Task {
                await refreshRetentionLoopsOnActive()
            }
        }
        .onChange(of: appContainer.isOnboardingCompleted) { _, _ in
            updatePostOnboardingAuthPresentation()
            Task {
                await refreshRetentionLoopsOnActive()
            }
        }
        .onChange(of: appContainer.shouldPresentInitialAuthEntry) { _, _ in
            updatePostOnboardingAuthPresentation()
        }
        .onChange(of: appContainer.hasCompletedInitialAuthChoice) { _, _ in
            updatePostOnboardingAuthPresentation()
        }
        .onChange(of: lockManager.isRegistered) { _, _ in
            updatePostOnboardingAuthPresentation()
        }
        .onChange(of: sessionManager.isAuthenticated) { _, _ in
            updatePostOnboardingAuthPresentation()
        }
    }
    
    private var shouldShowLockOverlay: Bool {
        lockManager.biometricsEnabled && lockManager.isLocked
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            lockManager.appDidEnterBackground()
            Task {
                await scheduleRetentionLoopsOnBackground()
            }
        case .inactive:
            lockManager.appDidEnterBackground()
        case .active:
            lockManager.appDidBecomeActive()
            Task {
                await refreshRetentionLoopsOnActive()
            }
        @unknown default:
            break
        }
    }
    
    private func handleDeepLink(_ link: DeepLink) {
        switch link {
        case .passwordReset(let token):
            resetToken = token
            showGlobalReset = true
        default:
            break
        }
    }

    private func updatePostOnboardingAuthPresentation() {
        showPostOnboardingAuthEntry =
            appContainer.shouldPresentInitialAuthEntry &&
            !lockManager.isRegistered &&
            !sessionManager.isAuthenticated
    }

    private func refreshRetentionLoopsOnActive() async {
        guard appContainer.isOnboardingCompleted else { return }

        await ensureFirstWeekChecklistSeeded()

        let notificationService = appContainer.notificationService
        await cancelReengagementNotifications(using: notificationService)

        guard notificationService.isAuthorized else { return }
        await appContainer.firstWeekService.scheduleReminders(using: notificationService)
    }

    private func scheduleRetentionLoopsOnBackground() async {
        guard appContainer.isOnboardingCompleted else { return }

        await ensureFirstWeekChecklistSeeded()

        let notificationService = appContainer.notificationService
        await cancelReengagementNotifications(using: notificationService)

        guard notificationService.isAuthorized else { return }

        for day in await configuredReengagementDays() {
            _ = await notificationService.scheduleReengageReminder(afterDays: day)
        }
    }

    private func ensureFirstWeekChecklistSeeded() async {
        guard appContainer.firstWeekService.tasks.isEmpty,
              let profile = appContainer.userProfile else { return }

        appContainer.firstWeekService.generateTasks(for: profile)
    }

    private func configuredReengagementDays() async -> [Int] {
        if let remoteConfig = await appContainer.remoteConfigService.getRemoteConfig(),
           let days = remoteConfig.reengageDays?
            .filter({ $0 > 0 })
            .sorted(),
           !days.isEmpty {
            return Array(Set(days)).sorted()
        }

        return [7, 14, 30]
    }

    private func cancelReengagementNotifications(using notificationService: any NotificationServiceProtocol) async {
        let pendingNotifications = await notificationService.getPendingNotifications()
        for request in pendingNotifications {
            let type = request.content.userInfo["type"] as? String
            if type == "reengage" || request.identifier.hasPrefix("reengage_") {
                notificationService.cancelNotification(with: request.identifier)
            }
        }
    }
}
