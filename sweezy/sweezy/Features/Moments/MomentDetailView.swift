//
//  MomentDetailView.swift
//  sweezy
//

import SwiftUI

struct MomentDetailView: View {
    let moment: SwissMoment
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.openURL) private var openURL
    @State private var navigateToTaxHub = false
    @State private var navigateToKKHelper = false
    @State private var navigateToDeadlines = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                description
                ctaButton
            }
            .padding(Theme.Spacing.md)
        }
        .background(Color.clear)
        .navigationTitle(moment.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToTaxHub) {
            TaxSeasonHubView()
        }
        .navigationDestination(isPresented: $navigateToKKHelper) {
            KKSwitchingHelperView()
        }
        .navigationDestination(isPresented: $navigateToDeadlines) {
            DeadlineTrackerView()
        }
        .journeyScreen(.zurich, darkness: 0.68)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Theme.Colors.accent)
                Text(deadlineCopy)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
            }
            Text(moment.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
        }
    }

    private var description: some View {
        Text(moment.descriptionMd)
            .font(.system(size: 16))
            .foregroundColor(Theme.Colors.textPrimary)
            .lineSpacing(4)
    }

    @ViewBuilder
    private var ctaButton: some View {
        Button(action: handleCta) {
            HStack {
                Image(systemName: ctaIcon)
                Text(NSLocalizedString(moment.ctaKind.localizedCtaKey, comment: ""))
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.Colors.primary)
            .foregroundColor(Theme.Colors.textOnPrimary)
            .cornerRadius(Theme.CornerRadius.lg)
        }
    }

    private var ctaIcon: String {
        switch moment.ctaKind {
        case .calculator: return "function"
        case .checklist: return "checklist"
        case .link: return "arrow.up.right.square"
        case .deeplink: return "arrow.right.circle.fill"
        }
    }

    private var deadlineCopy: String {
        let days = moment.daysUntilDeadline
        if days <= 0 { return "—" }
        return String(format: NSLocalizedString("moments.deadline.in_days", comment: ""), days)
    }

    private func handleCta() {
        appContainer.telemetry.retention(.momentActionTaken, source: "moment_detail", message: nil, meta: [
            "key": moment.key,
            "kind": moment.ctaKind.rawValue
        ])

        // Tool deeplinks defined in seed (`cta_payload.tool`).
        if let tool = moment.ctaToolKey {
            switch tool {
            case "tax_hub": navigateToTaxHub = true; return
            case "kk_switcher": navigateToKKHelper = true; return
            case "school_registration", "end_of_year": navigateToDeadlines = true; return
            default: break
            }
        }

        if let link = moment.ctaLinkURL {
            openURL(link)
        }
    }
}
