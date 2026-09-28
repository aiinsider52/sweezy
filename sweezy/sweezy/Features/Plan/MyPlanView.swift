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

    private var statusStrip: some View {
        HStack(spacing: 10) {
            metric(value: "\(urgentCount)", title: "термінові", icon: "exclamationmark.circle.fill")
            metric(value: "\(missingDocuments)", title: "документи", icon: "doc.badge.ellipsis")
            metric(value: "\(upcomingAppointments)", title: "зустрічі", icon: "calendar")
        }
    }

    private func metric(value: String, title: String, icon: String) -> some View {
        CityPaper(inset: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(JourneyVisual.accentStrong)
                Text(value)
                    .font(.system(size: 23, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Сьогодні та найближчі строки")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
                Spacer()
                Button("Нагадати") { scheduleReminders() }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(JourneyVisual.accentText)
            }

            if deadlines.isEmpty {
                // Everything done: Sweezy on the hill above the city with a ticked list.
                MascotEmptyState(
                    title: "Критичних строків немає",
                    subtitle: "companion.plan.all_done".localized,
                    story: "plan-complete"
                )
            } else {
                ForEach(deadlines.prefix(7)) { deadline in
                    DeadlineRow(deadline: deadline) {
                        complete(deadline)
                    }
                }
            }
        }
    }

    private var toolsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
            planTool(title: "Документи", subtitle: "Готовність і строки", icon: "doc.text.fill") { showDocuments = true }
                .accessibilityIdentifier("plan.documents")
            planTool(title: "Ask Sweezy", subtitle: "Відповіді з джерелами", icon: "sparkles") { showAsk = true }
                .accessibilityIdentifier("plan.ask")
            planTool(title: "Зустрічі", subtitle: "Експерти й офіси", icon: "calendar.badge.plus") { showAppointments = true }
            planTool(title: "Weekly Digest", subtitle: "План на тиждень", icon: "newspaper.fill") { showDigest = true }
        }
    }

    private func planTool(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CityPaper(inset: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(JourneyVisual.accentStrong)
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
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
            reminderMessage = count > 0 ? "Підключено нагадувань: \(count)" : "Дозволь сповіщення або перевір строки"
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

private struct DeadlineRow: View {
    let deadline: LifeDeadline
    let complete: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        CityPaper(inset: 0) {
            HStack(spacing: 12) {
                JourneyCategoryIcon(
                    symbol: deadline.category.icon,
                    swatch: deadline.urgency == .overdue ? JourneyCategoryPalette.coral : JourneyCategoryPalette.swatch(for: deadline.category.rawValue),
                    size: 38
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(deadline.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text(deadline.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(2)
                    Button {
                        if let url = deadline.sourceURL { openURL(url) }
                    } label: {
                        Label(deadline.sourceTitle, systemImage: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(deadline.sourceURL == nil ? JourneyVisual.secondaryText : Theme.Colors.primaryDark)
                    }
                    .buttonStyle(.plain)
                    .disabled(deadline.sourceURL == nil)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 10) {
                    Text(daysText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(deadline.urgency == .overdue ? .red : JourneyVisual.primaryText)
                    Button(action: complete) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundColor(JourneyVisual.secondaryText)
                    }
                }
            }
            .padding(14)
        }
    }

    private var daysText: String {
        if deadline.daysRemaining < 0 { return "прострочено" }
        if deadline.daysRemaining == 0 { return "сьогодні" }
        return "\(deadline.daysRemaining) дн."
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
                    Text("Permit, insurance, tax, registration та твої зустрічі.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                    ForEach(deadlines) { deadline in
                        DeadlineRow(deadline: deadline) {
                            if let taskID = LifeAdminService.firstWeekTaskID(from: deadline.id) {
                                appContainer.firstWeekService.toggle(taskID)
                            } else {
                                appContainer.lifeAdmin.setDeadlineCompleted(deadline.id, completed: true)
                            }
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
