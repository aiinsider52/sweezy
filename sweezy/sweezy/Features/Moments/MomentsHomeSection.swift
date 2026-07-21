//
//  MomentsHomeSection.swift
//  sweezy
//
//  "Aktualno" — surfaces the current Swiss "moments" relevant for the user.
//

import SwiftUI

struct MomentsHomeSection: View {
    @StateObject private var service = SwissMomentsService()
    @EnvironmentObject private var appContainer: AppContainer
    let profile: UserProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("moments.section.title".localized)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("moments.section.subtitle".localized)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)

            if service.isLoading && service.moments.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
            } else if service.moments.isEmpty {
                Text("moments.empty".localized)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                            .fill(Theme.Colors.adaptiveCard)
                    )
                    .padding(.horizontal, Theme.Spacing.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.md) {
                        ForEach(service.moments) { moment in
                            NavigationLink(destination: MomentDetailView(moment: moment)
                                .environmentObject(appContainer)
                            ) {
                                MomentCard(moment: moment)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                appContainer.telemetry.retention(.momentSeen, source: "home", message: nil, meta: ["key": moment.key])
                            })
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
            }
        }
        .task {
            await service.refresh(profile: profile, telemetry: appContainer.telemetry)
            await service.scheduleReminders(using: appContainer.notificationService, telemetry: appContainer.telemetry)
        }
    }
}

private struct MomentCard: View {
    let moment: SwissMoment

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
                Text(deadlineLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
            }
            Text(moment.title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
            Text(moment.descriptionMd)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(3)
            HStack {
                Text(NSLocalizedString(moment.ctaKind.localizedCtaKey, comment: ""))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.primary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
            }
        }
        .frame(width: 280, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.adaptiveCard)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }

    private var deadlineLabel: String {
        let days = moment.daysUntilDeadline
        if days <= 0 { return "—" }
        return String(format: NSLocalizedString("moments.deadline.in_days", comment: ""), days)
    }
}
