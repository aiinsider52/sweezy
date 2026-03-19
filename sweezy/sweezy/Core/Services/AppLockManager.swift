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
    @Published private(set) var isBiometryAvailable: Bool = false
    @Published private(set) var biometryUnavailableReason: String?
    
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
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        let type = context.biometryType
        
        _cachedBiometryType = type
        isBiometryAvailable = available && type != .none
        biometryUnavailableReason = isBiometryAvailable ? nil : availabilityMessage(for: error)
        
        // Avoid persisting a lock mode that cannot be fulfilled on this device.
        if biometricsEnabled && !isBiometryAvailable {
            biometricsEnabled = false
            isLocked = false
        }
    }
    
    func appDidEnterBackground() {
        guard biometricsEnabled, isBiometryAvailable else { return }
        isLocked = true
    }
    
    func appDidBecomeActive() {
        guard biometricsEnabled else { return }
        guard isBiometryAvailable else {
            biometricsEnabled = false
            isLocked = false
            return
        }
        guard isLocked else { return }
        Task { _ = await authenticate(reason: "Unlock Sweezy") }
    }
    
    func setBiometricsEnabled(_ enabled: Bool) async -> Bool {
        loadBiometryType()
        
        guard enabled else {
            biometricsEnabled = false
            isLocked = false
            lastAuthErrorDescription = nil
            return true
        }
        
        guard isBiometryAvailable else {
            biometricsEnabled = false
            isLocked = false
            lastAuthErrorDescription = biometryUnavailableReason
            return false
        }
        
        biometricsEnabled = true
        isLocked = true
        
        let ok = await authenticate(reason: "Enable \(biometryDisplayName)")
        if !ok {
            biometricsEnabled = false
        }
        return ok
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
    
    private func availabilityMessage(for error: NSError?) -> String {
        guard let error else {
            return "Biometric authentication is not available on this device."
        }
        
        if let laError = LAError.Code(rawValue: error.code) {
            switch laError {
            case .biometryNotAvailable:
                return "Biometric authentication is not available on this device."
            case .biometryNotEnrolled:
                return "Set up Face ID or Touch ID in device settings to use app lock."
            case .passcodeNotSet:
                return "Set a device passcode before enabling biometric lock."
            default:
                break
            }
        }
        
        return error.localizedDescription
    }
}
