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

        print("🚀 SweezyApp init started")
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppContent()
                .environmentObject(appContainer)
                .environmentObject(themeManager)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
                .onAppear {
                    print("🎉 App UI appeared")
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
                    lockManager.loadBiometryType()
                    
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
    
    var body: some View {
        Group {
            if appContainer.isOnboardingCompleted {
                // IMPORTANT (App Store 5.1.1):
                // Do NOT force account creation on launch.
                // Guest users can access all public (non-account-based) content from the main app.
                MainTabView()
            } else {
                OnboardingViewRedesigned()
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .environment(\.locale, appContainer.currentLocale)
    }
}
