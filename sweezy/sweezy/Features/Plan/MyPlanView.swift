import SwiftUI

struct MyPlanView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var moments = SwissMomentsService()
    @State private var showDocuments = false
    @State private var showAsk = false
    @State private var showAppointments = false
    @State private var showDigest = false
    @State private var reminderMessage: String?

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
            JourneyPhotoBackground(imageName: "journey-tool-my-plan", blurRadius: 2, darkness: 0.58)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusStrip
                    todaySection
                    toolsGrid

                    if let reminderMessage {
                        Text(reminderMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(JourneyVisual.lime)
                    }
                }
                .padding(20)
                .padding(.bottom, 48)
            }
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Мій план")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Конкретні дії, строки та документи — без зайвого каталогу.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            metric(value: "\(urgentCount)", title: "термінові", icon: "exclamationmark.circle.fill")
            metric(value: "\(missingDocuments)", title: "документи", icon: "doc.badge.ellipsis")
            metric(value: "\(upcomingAppointments)", title: "зустрічі", icon: "calendar")
        }
    }

    private func metric(value: String, title: String, icon: String) -> some View {
        JourneyGlassPanel(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(JourneyVisual.lime)
                Text(value)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.56))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Сьогодні та найближчі строки")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button("Нагадати") { scheduleReminders() }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(JourneyVisual.lime)
            }

            if deadlines.isEmpty {
                JourneyGlassPanel(cornerRadius: 22) {
                    Label("Критичних строків немає", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(16)
                }
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
            planTool(title: "Ask Sweezy", subtitle: "Відповіді з джерелами", icon: "sparkles") { showAsk = true }
            planTool(title: "Зустрічі", subtitle: "Експерти й офіси", icon: "calendar.badge.plus") { showAppointments = true }
            planTool(title: "Weekly Digest", subtitle: "План на тиждень", icon: "newspaper.fill") { showDigest = true }
        }
    }

    private func planTool(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            JourneyGlassPanel(cornerRadius: 21) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(JourneyVisual.lime)
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
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
        JourneyGlassPanel(cornerRadius: 21) {
            HStack(spacing: 12) {
                Image(systemName: deadline.category.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(deadline.urgency == .overdue ? .red : JourneyVisual.lime)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(deadline.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(deadline.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(2)
                    Button {
                        if let url = deadline.sourceURL { openURL(url) }
                    } label: {
                        Label(deadline.sourceTitle, systemImage: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(deadline.sourceURL == nil ? .white.opacity(0.45) : JourneyVisual.lime)
                    }
                    .buttonStyle(.plain)
                    .disabled(deadline.sourceURL == nil)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 10) {
                    Text(daysText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(deadline.urgency == .overdue ? .red : .white)
                    Button(action: complete) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
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
            JourneyPhotoBackground(imageName: "swiss-moment-luzern", darkness: 0.66)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Deadline Engine")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Permit, insurance, tax, registration та твої зустрічі.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
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
                .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
