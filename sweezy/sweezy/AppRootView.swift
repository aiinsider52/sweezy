//
//  AppRootView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showGlobalReset: Bool = false
    @State private var resetToken: String? = nil
    @State private var showPostOnboardingAuthEntry: Bool = false
    
    var body: some View {
        mainContent
            .environment(\.locale, appContainer.currentLocale)
            .preferredColorScheme(themeManager.colorScheme)
            .onChange(of: scenePhase) { _, phase in
                handleScenePhaseChange(phase)
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
            }
            .onAppear {
                updatePostOnboardingAuthPresentation()
            }
            .onChange(of: appContainer.isOnboardingCompleted) { _, _ in
                updatePostOnboardingAuthPresentation()
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
            .task {
                lockManager.loadBiometryType()
            }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if appContainer.isOnboardingCompleted {
            if lockManager.biometricsEnabled && lockManager.isLocked {
                BiometricUnlockView()
            } else {
                MainTabView()
            }
        } else {
            OnboardingViewRedesigned()
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            lockManager.appDidEnterBackground()
        case .active:
            lockManager.appDidBecomeActive()
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
}

#if DEBUG
#Preview {
    AppRootView()
        .environmentObject(AppContainer())
        .environmentObject(ThemeManager())
        .environmentObject(AppLockManager())
        .environmentObject(SessionManager(lockManager: AppLockManager()))
}
#endif

// MARK: - Biometric Unlock Screen

struct BiometricUnlockView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    
    var body: some View {
        ZStack {
            Theme.Colors.primaryBackground.ignoresSafeArea()
            
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                
                Image(systemName: biometricIcon)
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(Theme.Colors.gradientPrimaryAdaptive)
                
                Text("Unlock with \(lockManager.biometryDisplayName)")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                if let error = lockManager.lastAuthErrorDescription {
                    Text(error)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.md)
                }
                
                PrimaryButton("Unlock") {
                    Task { _ = await lockManager.authenticate(reason: "Unlock Sweezy") }
                }
                .frame(maxWidth: 200)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private var biometricIcon: String {
        lockManager.biometryDisplayName == "Face ID" ? "faceid" : "touchid"
    }
}
