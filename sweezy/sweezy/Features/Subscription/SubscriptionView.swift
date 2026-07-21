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
                JourneyPhotoBackground(imageName: JourneyBackdrop.alpine.rawValue, blurRadius: 7, darkness: 0.64)

                VStack(spacing: 14) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.cyan)

                    Text("Account & access")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Your account settings and app access options will appear here when available.")
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
                .journeyCard()
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
        .journeyScreen(.alpine, darkness: 0.64)
    }
}

#if DEBUG
#Preview {
    SubscriptionView()
}
#endif
