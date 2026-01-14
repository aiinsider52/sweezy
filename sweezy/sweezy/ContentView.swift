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
    @StateObject private var appContainer = AppContainer()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var lockManager = AppLockManager()
    private static let appStartTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    init() {
        print("🚀 SweezyApp init started")
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppContent()
                .environmentObject(appContainer)
                .environmentObject(themeManager)
                .environmentObject(lockManager)
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
    
    var body: some View {
        Group {
            if appContainer.isOnboardingCompleted {
                if lockManager.isRegistered {
                    MainTabView()
                } else {
                    RegistrationView()
                }
            } else {
                OnboardingViewRedesigned()
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .environment(\.locale, appContainer.currentLocale)
    }
}
