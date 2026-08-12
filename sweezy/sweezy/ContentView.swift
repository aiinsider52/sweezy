//
//  SweezyApp.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct SweezyApp: App {
    @UIApplicationDelegateAdaptor(SweezyAppDelegate.self) private var appDelegate
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
                    lockManager.loadBiometryType()
                    
                    AppReviewManager.recordFirstLaunchIfNeeded()
                    
                    // Start crash reporter (no-op if SDK absent)
                    appContainer.crashReporter.start()
                    appContainer.crashReporter.setUser(
                        id: KeychainStore.get("user_id"),
                        email: nil,
                        username: nil
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
    @State private var deepLinkedConversation: ChatConversation?
    
    var body: some View {
        ZStack {
            if isArticleLayoutUITest {
                JourneyGuideArticleView(guide: Self.articleLayoutFixture)
            } else if isCareerHubUITest {
                JobsView()
            } else if isCareerToolsUITest {
                JourneyDirectoryView(requestedSection: .tools, routeID: UUID())
            } else if isFriendsUITest {
                FriendNetworkView()
            } else if isNetworkUITest || isNetworkGateUITest {
                ProfessionalNetworkView()
            } else if isPaywallScreenshot {
                SubscriptionView(source: .profile)
            } else if isCVGateScreenshot {
                Color(red: 0.025, green: 0.03, blue: 0.028).ignoresSafeArea()
                CVPlusGateSheet(freeActionsUsed: 3, openPlus: {}, dismiss: {})
                    .frame(maxHeight: .infinity, alignment: .bottom)
            } else if isEmailVerificationUITest {
                EmailVerificationSheet(initialEmail: "olena.kovalenko@email.com")
            } else {
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
            }
            
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
            #if canImport(GoogleSignIn)
            if GIDSignIn.sharedInstance.handle(url) {
                return
            }
            #endif
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
            .environmentObject(appContainer)
            .environmentObject(lockManager)
            .environmentObject(sessionManager)
        }
        .fullScreenCover(item: $deepLinkedConversation) { conversation in
            ChatConversationView(conversation: conversation)
                .environmentObject(appContainer)
        }
        .onAppear {
            updatePostOnboardingAuthPresentation()
            Task {
                await refreshRetentionLoopsOnActive()
                await startAccountServicesIfNeeded()
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
        .onChange(of: sessionManager.isAuthenticated) { _, authenticated in
            updatePostOnboardingAuthPresentation()
            Task {
                if authenticated { await startAccountServicesIfNeeded() }
                else { appContainer.chatStore.stop() }
            }
        }
    }
    
    private var shouldShowLockOverlay: Bool {
        lockManager.biometricsEnabled && lockManager.isLocked
    }

    private var isEmailVerificationUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["UITESTS"] == "1" &&
            ProcessInfo.processInfo.arguments.contains("--ui-test-email-verification")
        #else
        false
        #endif
    }

    private var isPaywallScreenshot: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "screenshotPaywall")
        #else
        false
        #endif
    }

    private var isCVGateScreenshot: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "screenshotCVGate")
        #else
        false
        #endif
    }

    private var isArticleLayoutUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-test-article-layout")
        #else
        false
        #endif
    }

    private var isCareerHubUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["UITESTS"] == "1" &&
            ProcessInfo.processInfo.arguments.contains("--ui-test-career-hub")
        #else
        false
        #endif
    }

    private var isNetworkUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["UITESTS"] == "1" &&
            ProcessInfo.processInfo.arguments.contains("--ui-test-network")
        #else
        false
        #endif
    }

    private var isNetworkGateUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["UITESTS"] == "1" &&
            ProcessInfo.processInfo.arguments.contains("--ui-test-network-gate")
        #else
        false
        #endif
    }

    private var isCareerToolsUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["UITESTS"] == "1" &&
            ProcessInfo.processInfo.arguments.contains("--ui-test-career-tools")
        #else
        false
        #endif
    }

    private var isFriendsUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["UITESTS"] == "1" &&
            (ProcessInfo.processInfo.arguments.contains("--ui-test-friends") ||
             ProcessInfo.processInfo.arguments.contains("--ui-test-friends-profile") ||
             ProcessInfo.processInfo.arguments.contains("--ui-test-friends-editor"))
        #else
        false
        #endif
    }

    private static let articleLayoutFixture = Guide(
        title: "Grundlagen der Krankenversicherung in der Schweiz",
        summary: "Verständliche Orientierung zu Versicherung, Franchise und kantonalen Verfahren.",
        bodyMarkdown: """
        # Krankenversicherung verstehen

        Die Grundversicherung ist obligatorisch. Wählen Sie eine Franchise, die zu Ihrem Budget passt, und prüfen Sie auf der Kantonsseite, ob Sie Anspruch auf Prämienverbilligung haben.

        ## Education System in Switzerland

        Education is free and compulsory for children aged 4–15. Requirements and procedures may differ between cantons and personal situations.

        > Important: Check current requirements with your canton before submitting documents.

        - Krankenversicherung: Auswahl und Optimierung
        - Kindergarten und Primarschule
        """,
        category: .insurance,
        isNew: true,
        estimatedReadingTime: 6,
        language: "de",
        verifiedAt: Date(),
        source: "https://www.ch.ch/en/insurance/health-insurance/",
        sourceTitle: "ch.ch — Health insurance",
        heroImage: "swiss-moment-luzern"
    )
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            lockManager.appDidEnterBackground()
            Task {
                await scheduleRetentionLoopsOnBackground()
            }
        case .inactive:
            // Temporary interruptions (Control Center, system alerts, biometric
            // prompts) must not lock or disable the app. A subsequent real
            // background transition is the only event that arms app lock.
            break
        case .active:
            lockManager.appDidBecomeActive()
            Task {
                await refreshRetentionLoopsOnActive()
                await startAccountServicesIfNeeded()
                appContainer.chatStore.reconnect()
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
        case .chat(let id):
            guard sessionManager.isAuthenticated else { return }
            Task {
                await appContainer.chatStore.start()
                deepLinkedConversation = await appContainer.chatStore.conversation(id: id)
            }
        default:
            break
        }
    }

    private func startAccountServicesIfNeeded() async {
        guard sessionManager.isAuthenticated else { return }
        await SubscriptionManager.shared.load()
        await appContainer.chatStore.start()
        if NotificationPreference.isEnabled {
            await SweezyAppDelegate.registerForChatPush()
        }
    }

    private func updatePostOnboardingAuthPresentation() {
        guard !isEmailVerificationUITest else {
            showPostOnboardingAuthEntry = false
            return
        }
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
        _ = await appContainer.firstWeekService.scheduleReminders(using: notificationService)
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
