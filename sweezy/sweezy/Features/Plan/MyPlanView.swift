import SwiftUI

struct MyPlanView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var moments = SwissMomentsService()
    @State private var showDocuments = false
    @State private var showAsk = false
    @State private var showAppointments = false
    @State private var showDigest = false
    @State private var reminderMessage: String?
    @State private var companionReaction = 0

    private var deadlines: [LifeDeadline] {
        appContainer.lifeAdmin.deadlines(
            profile: appContainer.userProfile,
            firstWeekTasks: appContainer.firstWeekService.tasks,
            moments: moments.moments,
            appointments: appContainer.appointmentRepository.appointments
        )
    }

    var body: some View {
        ZStack {
            JourneyVisual.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusStrip
                    todaySection
                    toolsGrid

                    if let reminderMessage {
                        Text(reminderMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(JourneyVisual.accentText)
                    }
                }
                .padding(20)
                .padding(.bottom, 128)
            }
        }
        .statusBarScrim()
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDocuments) { DocumentReadinessView() }
        .navigationDestination(isPresented: $showAsk) { AskSweezyView() }
        .navigationDestination(isPresented: $showAppointments) { AppointmentsView() }
        .navigationDestination(isPresented: $showDigest) { WeeklyDigestView() }
        .task {
            appContainer.lifeAdmin.prepareDocuments(for: appContainer.userProfile)
            await moments.refresh(profile: appContainer.userProfile, telemetry: appContainer.telemetry)
        }
    }

    private var header: some View {
        SweezyCompanionHeader(
            title: "companion.plan.title".localized,
            subtitle: "companion.plan.subtitle".localized,
            pose: .documents,
            reaction: companionReaction,
            onPhoto: false
        )
    }

    /// Three counts as quiet chips; documents and meetings open their screens.
    private var statusStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                metric(value: urgentCount, title: "термінові".localized, icon: "exclamationmark.circle.fill", alert: urgentCount > 0) {}
                metric(value: missingDocuments, title: "документи".localized, icon: "doc.badge.ellipsis", alert: false) { showDocuments = true }
                metric(value: upcomingAppointments, title: "зустрічі".localized, icon: "calendar", alert: false) { showAppointments = true }
            }
        }
        .scrollClipDisabled()
    }

    private func metric(value: Int, title: String, icon: String, alert: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(alert ? JourneyVisual.coral : JourneyVisual.secondaryText)
                Text("\(value)")
                    .font(.system(size: 14, weight: .heavy).monospacedDigit())
                    .foregroundColor(JourneyVisual.primaryText)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(Theme.Colors.card, in: Capsule())
            .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Сьогодні та найближчі строки".localized)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
                Spacer()
                Button("Нагадати".localized) { scheduleReminders() }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(JourneyVisual.accentText)
            }

            if deadlines.isEmpty {
                // Everything done: Sweezy on the hill above the city with a ticked list.
                MascotEmptyState(
                    title: "Критичних строків немає".localized,
                    subtitle: "companion.plan.all_done".localized,
                    story: "plan-complete"
                )
            } else {
                DeadlineList(deadlines: Array(deadlines.prefix(7))) { deadline in
                    complete(deadline)
                }
            }
        }
    }

    private var toolsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            planTool(title: "Документи".localized, subtitle: "Готовність і строки".localized, icon: "doc.text.fill") { showDocuments = true }
                .accessibilityIdentifier("plan.documents")
            planTool(title: "journey.tool.ask.title".localized, subtitle: "Відповіді з джерелами".localized, icon: "sparkles") { showAsk = true }
                .accessibilityIdentifier("plan.ask")
            planTool(title: "Зустрічі".localized, subtitle: "Експерти й офіси".localized, icon: "calendar.badge.plus") { showAppointments = true }
            planTool(title: "journey.tool.digest.title".localized, subtitle: "План на тиждень".localized, icon: "newspaper.fill") { showDigest = true }
        }
    }

    private func planToolSwatch(_ icon: String) -> JourneyCategorySwatch {
        switch icon {
        case "doc.text.fill": return JourneyCategoryPalette.sky
        case "sparkles": return JourneyCategoryPalette.lime
        case "calendar.badge.plus": return JourneyCategoryPalette.teal
        default: return JourneyCategoryPalette.sand
        }
    }

    private func planTool(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CityPaper(inset: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    JourneyCategoryIcon(symbol: icon, swatch: planToolSwatch(icon), size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundColor(JourneyVisual.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
        .buttonStyle(.plain)
    }

    private var urgentCount: Int { deadlines.filter { $0.urgency == .overdue || $0.urgency == .urgent }.count }
    private var missingDocuments: Int { appContainer.lifeAdmin.documents.filter { $0.status == .missing || $0.status == .expired }.count }
    private var upcomingAppointments: Int { appContainer.appointmentRepository.appointments.filter { !$0.isPast }.count }

    private func scheduleReminders() {
        Task { @MainActor in
            let count = await appContainer.lifeAdmin.scheduleReminders(for: deadlines, using: appContainer.notificationService)
            reminderMessage = count > 0 ? "Підключено нагадувань: %@".localized(with: "\(count)") : "Дозволь сповіщення або перевір строки".localized
        }
    }

    private func complete(_ deadline: LifeDeadline) {
        companionReaction += 1
        if let taskID = LifeAdminService.firstWeekTaskID(from: deadline.id) {
            appContainer.firstWeekService.toggle(taskID)
        } else {
            appContainer.lifeAdmin.setDeadlineCompleted(deadline.id, completed: true)
        }
    }
}

/// Deadlines as one list with hairlines.
private struct DeadlineList: View {
    let deadlines: [LifeDeadline]
    let complete: (LifeDeadline) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(deadlines.enumerated()), id: \.element.id) { index, deadline in
                DeadlineRow(deadline: deadline) { complete(deadline) }
                if index < deadlines.count - 1 {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
    }
}

/// Tick on the left completes it; the row itself opens the official source when there is one.
private struct DeadlineRow: View {
    let deadline: LifeDeadline
    let complete: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: complete) {
                Circle()
                    .stroke(deadline.urgency == .overdue ? JourneyVisual.coral : JourneyVisual.softBorder, lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("common.done".localized)
            .padding(.top, -6)

            Button {
                if let url = deadline.sourceURL { openURL(url) }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(deadline.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text(daysText)
                            .fontWeight(.bold)
                            .foregroundColor(deadline.urgency == .overdue ? JourneyVisual.coral : JourneyVisual.primaryText)
                        Text("·")
                        Text(deadline.detail)
                            .lineLimit(1)
                        if deadline.sourceURL != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(JourneyVisual.accentStrong)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Not .disabled: that would grey out rows that simply have no link.
            .allowsHitTesting(deadline.sourceURL != nil)
        }
        .padding(.vertical, 12)
    }

    private var daysText: String {
        if deadline.daysRemaining < 0 { return "прострочено".localized }
        if deadline.daysRemaining == 0 { return "сьогодні".localized }
        return "%@ дн.".localized(with: "\(deadline.daysRemaining)")
    }
}

struct DeadlineEngineView: View {
    @EnvironmentObject private var appContainer: AppContainer

    private var deadlines: [LifeDeadline] {
        appContainer.lifeAdmin.deadlines(
            profile: appContainer.userProfile,
            firstWeekTasks: appContainer.firstWeekService.tasks,
            appointments: appContainer.appointmentRepository.appointments
        )
    }

    var body: some View {
        ZStack {
            JourneyVisual.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Deadline Engine")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text("Permit, insurance, tax, registration та твої зустрічі.".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                    DeadlineList(deadlines: deadlines) { deadline in
                        if let taskID = LifeAdminService.firstWeekTaskID(from: deadline.id) {
                            appContainer.firstWeekService.toggle(taskID)
                        } else {
                            appContainer.lifeAdmin.setDeadlineCompleted(deadline.id, completed: true)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 128)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
