//
//  LockOverlayView.swift
//  sweezy
//
//  Created by AI Assistant on 16.10.2025.
//

import SwiftUI

struct LockOverlayView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(Theme.Colors.ukrainianBlue)
            Text(message)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}

struct LockScreenOverlay: View {
    @EnvironmentObject private var lockManager: AppLockManager
    
    var body: some View {
        ZStack {
            Theme.Colors.primaryBackground
                .ignoresSafeArea()
                .overlay {
                    Rectangle()
                        .fill(.black.opacity(0.28))
                        .ignoresSafeArea()
                }
            
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
                .frame(maxWidth: 220)
                
                Spacer()
            }
            .padding()
        }
        .transition(.opacity)
        .zIndex(1)
    }
    
    private var biometricIcon: String {
        lockManager.biometryDisplayName == "Face ID" ? "faceid" : "touchid"
    }
}


