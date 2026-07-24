//
//  SettledToolsViews.swift
//  sweezy
//
//  Lightweight Tax season hub, KK switching helper, and Deadline tracker for
//  long-term Swiss residents. They link to authoritative external resources and
//  reuse Appointments + Moments data.
//

import SwiftUI

// MARK: - Tax season hub

struct TaxSeasonHubView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @State private var profile: UserProfile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("tools.tax.title".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("tools.tax.subtitle".localized)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textSecondary)

                step(number: 1, title: "Collect Lohnausweis, 3a certificates, healthcare receipts.")
                step(number: 2, title: "If on B/L permit (Quellensteuer) — request Neuveranlagung before 31 March.")
                step(number: 3, title: "Submit standard declaration between 1 March and 30 April.")
                step(number: 4, title: "Need an extension? Most cantons grant Fristerstreckung online for free.")

                if let canton = profile?.canton {
                    cantonalLinkButton(canton: canton)
                }

                Link(destination: URL(string: "https://www.estv.admin.ch/estv/en/home.html")!) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Federal Tax Administration (ESTV)")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.adaptiveCard)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .journeyScreen(.city, darkness: 0.68)
        .onAppear {
            self.profile = appContainer.userProfile
        }
    }

    private func step(number: Int, title: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 28, height: 28)
                .background(Theme.Colors.primary.opacity(0.15))
                .foregroundColor(Theme.Colors.primary)
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.adaptiveCard)
        )
    }

    @ViewBuilder
    private func cantonalLinkButton(canton: Canton) -> some View {
        if let url = URL(string: cantonalTaxURL(for: canton)) {
            Link(destination: url) {
                HStack {
                    Image(systemName: "building.columns")
                    Text("Cantonal tax office (\(canton.localizedName))")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.Colors.primary.opacity(0.15))
                .foregroundColor(Theme.Colors.primary)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
    }

    private func cantonalTaxURL(for canton: Canton) -> String {
        switch canton {
        case .zurich: return "https://www.zh.ch/de/steuern-finanzen.html"
        case .vaud: return "https://www.vd.ch/themes/etat-droit-finances/impots"
        case .geneva: return "https://www.ge.ch/dossier/payer-impots"
        case .bern: return "https://www.sv.fin.be.ch/"
        case .basel: return "https://www.steuerverwaltung.bs.ch/"
        default: return "https://www.ch.ch/en/taxes-and-finances/"
        }
    }
}

// MARK: - KK switching helper

struct KKSwitchingHelperView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @State private var currentInsurer: String = ""
    @State private var monthlyPremium: String = ""
    @State private var deductible: String = "300"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("tools.kk.title".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("tools.kk.subtitle".localized)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textSecondary)

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    field(label: "Current insurer", text: $currentInsurer, placeholder: "e.g. Helsana")
                    field(label: "Monthly premium (CHF)", text: $monthlyPremium, placeholder: "e.g. 420", keyboard: .decimalPad)
                    Picker("Deductible (CHF)", selection: $deductible) {
                        ForEach(["300", "500", "1000", "1500", "2000", "2500"], id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(Theme.Colors.adaptiveCard)
                )

                Link(destination: URL(string: "https://www.priminfo.admin.ch/")!) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Compare premiums on Priminfo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.primary)
                    .foregroundColor(Theme.Colors.textOnPrimary)
                    .cornerRadius(Theme.CornerRadius.md)
                }

                Link(destination: URL(string: "https://www.comparis.ch/krankenkassen/grundversicherung")!) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Compare on Comparis")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.adaptiveCard)
                    .cornerRadius(Theme.CornerRadius.md)
                }

                Text("Reminder: cancellation letter must arrive by 30 November (registered mail).")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .journeyScreen(.lake, darkness: 0.68)
    }

    private func field(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.Colors.textSecondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .padding(10)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(Theme.CornerRadius.sm)
        }
    }
}

// MARK: - Deadline tracker

struct DeadlineTrackerView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var moments = SwissMomentsService()
    @State private var profile: UserProfile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("tools.deadlines.title".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("tools.deadlines.subtitle".localized)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textSecondary)

                ForEach(deadlines, id: \.id) { item in
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        Image(systemName: item.icon)
                            .frame(width: 32, height: 32)
                            .background(item.tint.opacity(0.18))
                            .foregroundColor(item.tint)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.system(size: 16, weight: .semibold))
                            Text(item.subtitle).font(.system(size: 13)).foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Text(item.daysCopy)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .padding(Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                            .fill(Theme.Colors.adaptiveCard)
                    )
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .journeyScreen(.alpine, darkness: 0.68)
        .task {
            self.profile = appContainer.userProfile
            await moments.refresh(profile: self.profile, telemetry: appContainer.telemetry)
        }
    }

    private struct Deadline: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        let date: Date
        var daysCopy: String {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            if days < 0 { return "—" }
            return String(format: NSLocalizedString("moments.deadline.in_days", comment: ""), days)
        }
    }

    private var deadlines: [Deadline] {
        var items: [Deadline] = []
        // From moments
        for moment in moments.moments {
            items.append(Deadline(
                id: "moment.\(moment.id)",
                title: moment.title,
                subtitle: moment.descriptionMd.split(separator: "\n").first.map(String.init) ?? "",
                icon: "calendar.badge.clock",
                tint: Theme.Colors.accent,
                date: moment.endsAt
            ))
        }
        // Permit expiry
        if let expiry = profile?.permitExpiryDate, expiry > Date() {
            items.append(Deadline(
                id: "permit.expiry",
                title: "Permit \(profile?.permitType.rawValue ?? "") expiry",
                subtitle: "Renewal usually requested 90 days before.",
                icon: "person.text.rectangle",
                tint: Theme.Colors.primary,
                date: expiry
            ))
        }
        return items.sorted { $0.date < $1.date }
    }
}
