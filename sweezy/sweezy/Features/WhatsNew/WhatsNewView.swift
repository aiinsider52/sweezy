//
//  WhatsNewView.swift
//  sweezy
//
//  Created by AI Assistant on 16.10.2025.
//

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""
    
    private let currentVersion = Bundle.main.appVersion
    private let features = WhatsNewFeature.currentVersionFeatures
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Header
                    headerSection
                    
                    // Features list
                    VStack(spacing: Theme.Spacing.lg) {
                        ForEach(features) { feature in
                            WhatsNewFeatureRow(feature: feature)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                    // Continue button
                    Button(action: {
                        lastSeenVersion = currentVersion
                        dismiss()
                    }) {
                        Text("common.continue".localized)
                            .font(Theme.Typography.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                                    .fill(Theme.Colors.gradientPrimaryAdaptive)
                            )
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
                .padding(.vertical, Theme.Spacing.xl)
            }
            .background(Color.clear)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        lastSeenVersion = currentVersion
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }
            }
        }
        .journeyScreen(.lake, darkness: 0.64)
    }
    
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // App icon
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(
                    Theme.Colors.gradientPrimaryAdaptive
                )
            
            // Title
            Text("whats_new.title".localized)
                .font(Theme.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.textPrimary)
            
            // Version
            Text("whats_new.version".localized(with: currentVersion))
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
            
            // Subtitle
            Text("whats_new.subtitle".localized)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Theme.Spacing.lg)
    }
}

// MARK: - Feature Row

struct WhatsNewFeatureRow: View {
    let feature: WhatsNewFeature
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(feature.iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 24))
                    .foregroundColor(feature.iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(feature.description)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .journeyCard(cornerRadius: Theme.CornerRadius.md)
    }
}

// MARK: - Feature Model

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    // Current release highlights
    static let currentVersionFeatures: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "storefront.fill",
            iconColor: Theme.Colors.primary,
            title: "whats_new.feature1.title".localized,
            description: "whats_new.feature1.description".localized
        ),
        WhatsNewFeature(
            icon: "photo.on.rectangle.angled",
            iconColor: Theme.Colors.accentTurquoise,
            title: "whats_new.feature2.title".localized,
            description: "whats_new.feature2.description".localized
        ),
        WhatsNewFeature(
            icon: "checkmark.shield.fill",
            iconColor: Theme.Colors.warning,
            title: "whats_new.feature3.title".localized,
            description: "whats_new.feature3.description".localized
        ),
        WhatsNewFeature(
            icon: "tray.full.fill",
            iconColor: Theme.Colors.info,
            title: "whats_new.feature4.title".localized,
            description: "whats_new.feature4.description".localized
        ),
        WhatsNewFeature(
            icon: "wrench.and.screwdriver.fill",
            iconColor: Theme.Colors.success,
            title: "whats_new.feature5.title".localized,
            description: "whats_new.feature5.description".localized
        )
    ]
}

// MARK: - Helper Extension
// Note: appVersion extension is defined globally (see AnalyticsService.swift)

// MARK: - View Modifier

struct WhatsNewModifier: ViewModifier {
    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""
    @State private var showWhatsNew = false
    
    private let currentVersion = Bundle.main.appVersion
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView()
            }
            .onAppear {
                checkIfShouldShow()
            }
    }
    
    private func checkIfShouldShow() {
        // Show if version changed or first launch
        if lastSeenVersion.isEmpty || lastSeenVersion != currentVersion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showWhatsNew = true
            }
        }
    }
}

extension View {
    func showWhatsNewIfNeeded() -> some View {
        self.modifier(WhatsNewModifier())
    }
}

#Preview {
    WhatsNewView()
}


