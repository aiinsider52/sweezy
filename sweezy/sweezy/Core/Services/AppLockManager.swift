//
//  AppLockManager.swift
//  sweezy
//
//  Created by AI Assistant on 16.10.2025.
//

import SwiftUI
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userEmail") var userEmail: String = ""
    @AppStorage("isRegistered") var isRegistered: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("biometricsEnabled") var biometricsEnabled: Bool = false
    @Published var isLocked: Bool = false
    @Published var lastAuthErrorDescription: String?
    
    // Cached biometry type to avoid repeated LAContext calls during body evaluation
    private var _cachedBiometryType: LABiometryType?
    
    var biometryDisplayName: String {
        // Return cached value if available to avoid blocking main thread
        if let cached = _cachedBiometryType {
            return displayName(for: cached)
        }
        // Fallback: return generic name immediately; actual type will be resolved lazily
        return "Biometrics"
    }
    
    private func displayName(for type: LABiometryType) -> String {
        switch type {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }
    
    /// Call this once after app launch (e.g., in onAppear or task) to cache biometry type safely
    func loadBiometryType() {
        // Already cached
        guard _cachedBiometryType == nil else { return }
        
        // Evaluate on the main actor; this call is lightweight and avoids Swift 6 isolation issues
        Task { @MainActor in
            let context = LAContext()
            var error: NSError?
            _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
            let type = context.biometryType
            _cachedBiometryType = type
            objectWillChange.send()
        }
    }
    
    func appDidEnterBackground() {
        guard biometricsEnabled else { return }
        isLocked = true
    }
    
    func appDidBecomeActive() {
        guard biometricsEnabled, isLocked else { return }
        Task { _ = await authenticate(reason: "Unlock Sweezy") }
    }
    
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "Use Passcode")
        
        do {
            guard try canEvaluateBiometrics(context) else {
                isLocked = false
                return true
            }
        } catch {
            lastAuthErrorDescription = error.localizedDescription
            return false
        }
        
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, error in
                Task { @MainActor in
                    if success {
                        self?.isLocked = false
                        self?.lastAuthErrorDescription = nil
                    } else {
                        self?.isLocked = true
                        self?.lastAuthErrorDescription = (error as NSError?)?.localizedDescription
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    private func canEvaluateBiometrics(_ context: LAContext) throws -> Bool {
        var authError: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError)
        if let authError { throw authError }
        return canEvaluate
    }
}
