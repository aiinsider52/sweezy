import SwiftUI

struct AskSweezyView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @State private var query = ""
    @State private var selectedGuide: Guide?
    private let service = AskSweezyService()

    private var results: [AskSweezyResult] {
        service.search(query, guides: appContainer.contentService.guides, profile: appContainer.userProfile)
    }

    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: "cityhub-zurich-oldtown", blurRadius: 4, darkness: 0.68)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ask Sweezy")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Пошук тільки по матеріалах з офіційним джерелом.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))

                    JourneySearchField(text: $query, prompt: "Наприклад: як продовжити permit?")

                    if query.count >= 2 && results.isEmpty {
                        JourneyGlassPanel(cornerRadius: 22) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Перевіреної відповіді не знайдено", systemImage: "shield.slash")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Sweezy не вигадує відповідь без джерела. Спробуй коротший запит або відкрий довідник.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(16)
                        }
                    }

                    ForEach(results.prefix(8)) { result in
                        Button { selectedGuide = result.guide } label: {
                            JourneyGlassPanel(cornerRadius: 22) {
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Label(result.sourceTitle, systemImage: "checkmark.seal.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(JourneyVisual.lime)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .foregroundColor(.white.opacity(0.45))
                                    }
                                    Text(result.guide.title)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                    Text(result.excerpt)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.62))
                                        .lineLimit(4)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(15)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedGuide) { GuideDetailView(guide: $0) }
        .task {
            if appContainer.contentService.guides.isEmpty { await appContainer.contentService.refreshContent() }
        }
    }
}

struct WeeklyDigestView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @State private var scheduleMessage: String?

    private var deadlines: [LifeDeadline] {
        appContainer.lifeAdmin.deadlines(
            profile: appContainer.userProfile,
            firstWeekTasks: appContainer.firstWeekService.tasks,
            appointments: appContainer.appointmentRepository.appointments
        )
    }

    private var digest: WeeklyDigestSnapshot {
        appContainer.lifeAdmin.makeDigest(deadlines: deadlines, appointments: appContainer.appointmentRepository.appointments)
    }

    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: "cityhub-zurich-lake", darkness: 0.62)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Weekly Digest")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(digest.summary)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JourneyVisual.lime)

                    digestSection("Наступні дії", items: digest.nextActions.map { "\($0.title) — \($0.daysRemaining) дн." })
                    digestSection("Документи", items: digest.missingDocuments.map { "Підготувати: \($0.title)" })
                    digestSection("Зустрічі", items: digest.upcomingAppointments.map { "\($0.title) — \($0.formattedDate)" })

                    JourneyPrimaryButton(title: "Нагадувати щопонеділка") {
                        Task { @MainActor in
                            let ok = await appContainer.lifeAdmin.scheduleWeeklyDigest(digest, using: appContainer.notificationService)
                            scheduleMessage = ok ? "Наступний digest заплановано" : "Дозволь сповіщення у Settings"
                        }
                    }
                    if let scheduleMessage {
                        Text(scheduleMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.72))
                    }
                }
                .padding(20)
                .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func digestSection(_ title: String, items: [String]) -> some View {
        JourneyGlassPanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if items.isEmpty {
                    Text("Нічого критичного")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    ForEach(items, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}
