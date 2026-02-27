//
//  SubscriptionView.swift
//  sweezy
//
//  TEMPORARY (App Store review):
//  This build ships with ALL features fully unlocked.
//  In-App Purchases / paywall / subscription logic are intentionally removed.
//  Keep this file as a lightweight placeholder so IAP can be reintroduced later
//  without changing navigation structure.
//

import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptivePageBackground()

                VStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.cyan)

                    Text("All features unlocked")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("This version has no subscriptions and no in-app purchases.\nEverything is available for everyone.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    PrimaryButton("common.close".localized) {
                        dismiss()
                    }
                    .frame(maxWidth: 220)
                    .padding(.top, 6)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.Colors.adaptiveCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    SubscriptionView()
}
#endif
