//
//  SessionManager.swift
//  sweezy
//
//  Guest mode + authentication state tracking.
//  This is used to comply with App Store Guideline 5.1.1:
//  - The app must be usable for general (non-account) content without sign-in.
//  - Only account-based features (saving, personalization, subscriptions/IAP) are gated.
//

import Foundation
import Combine

/// Lightweight representation of an authenticated user for app-wide session state.
/// We intentionally keep it minimal so it can be created from local persisted data (offline-safe).
struct User: Codable, Equatable, Hashable, Identifiable {
    /// Stable identifier for UI lists; we use email because backend "me" endpoint is not guaranteed here.
    var id: String { email.lowercased() }
    let email: String
    let name: String?
}

/// Central session state used across the app to separate guest vs authenticated experiences.
enum UserSessionState: Equatable {
    /// User explicitly uses the app without an account.
    case guest
    /// User is signed in (or locally registered) and we can safely enable account-based features.
    case authenticated(User)
    /// Transitional state while restoring session (e.g., on launch).
    case unauthenticated
}

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var state: UserSessionState = .unauthenticated

    private let lockManager: AppLockManager
    private var cancellables = Set<AnyCancellable>()

    init(lockManager: AppLockManager) {
        self.lockManager = lockManager

        // Default to guest unless an existing authenticated session is found.
        recomputeStateFromStorage()

        // Keep session state in sync with existing auth persistence used throughout the app.
        // `AppLockManager.isRegistered` is already the single source of truth used by the old flow.
        lockManager.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.recomputeStateFromStorage()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Convenience

    var isGuest: Bool {
        if case .guest = state { return true }
        return false
    }

    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }

    var currentUser: User? {
        if case .authenticated(let user) = state { return user }
        return nil
    }

    // MARK: - Intent API

    /// Called from the Login screen.
    /// We do NOT force sign-in on launch; guest mode is the default experience.
    func continueAsGuest() {
        // If user is already authenticated, we keep the current session.
        // "Continue as guest" is mainly for unauthenticated users dismissing the auth modal.
        if !lockManager.isRegistered {
            state = .guest
        }
    }

    /// Centralized sign out (keeps the app usable as a guest afterwards).
    /// Call this instead of manually toggling `isRegistered` + clearing Keychain in multiple places.
    func signOut() {
        KeychainStore.delete("access_token")
        KeychainStore.delete("refresh_token")

        // Clear local identity fields
        lockManager.userName = ""
        lockManager.userEmail = ""
        lockManager.isRegistered = false

        // Guest is the default "logged out" experience in this app.
        state = .guest
    }

    /// Force an immediate authenticated state update after login/registration.
    /// This avoids waiting for downstream storage propagation before the whole app reacts.
    func activateAuthenticatedSession(email: String, name: String?) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        state = .authenticated(
            User(
                email: trimmedEmail.isEmpty ? "user@local" : trimmedEmail,
                name: (trimmedName?.isEmpty == false) ? trimmedName : nil
            )
        )
    }

    // MARK: - Internal

    private func recomputeStateFromStorage() {
        let hasToken = !(KeychainStore.get("access_token") ?? "").isEmpty
        if lockManager.isRegistered && hasToken {
            let email = lockManager.userEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = lockManager.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let user = User(email: email.isEmpty ? "user@local" : email, name: name.isEmpty ? nil : name)
            state = .authenticated(user)
        } else {
            // IMPORTANT: default to guest so general content is accessible without an account.
            state = .guest
        }
    }
}

