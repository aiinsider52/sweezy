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
                .foregroundColor(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
}


