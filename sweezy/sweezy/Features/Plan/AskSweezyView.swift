import SwiftUI

struct AskSweezyView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @State private var query = ""
    @State private var selectedGuide: Guide?
    private let service = AskSweezyService()

    private var results: [AskSweezyResult] {
        service.search(query, guides: appContainer.contentService.getGuidesForLocale(appContainer.currentLocale.identifier), profile: appContainer.userProfile)
    }

    var body: some View {
        ZStack {
            JourneyVisual.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if query.count < 2 || !results.isEmpty {
                        SweezyCompanionHeader(
                            title: "Ask Sweezy",
                            subtitle: "companion.search.subtitle".localized,
                            size: 72, onPhoto: false
                        )
                    } else {
                        Text("Ask Sweezy")
                            .font(.title2.bold())
                            .foregroundStyle(JourneyVisual.primaryText)
                    }

                    JourneySearchField(text: $query, prompt: "Наприклад: як продовжити permit?")
                        .accessibilityIdentifier("ask.search")

                    if query.count >= 2 && results.isEmpty {
                        CityPaper {
                            VStack(alignment: .leading, spacing: 16) {
                                SweezyCompanionHeader(
                                    title: "companion.search.empty.title".localized,
                                    subtitle: "companion.search.empty.subtitle".localized,
                                    size: 100, onPhoto: false
                                )
                                Button("companion.search.reset".localized) { query = "" }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 14))
                                    .accessibilityIdentifier("ask.reset")
                            }
                        }
                    }

                    ForEach(results.prefix(8)) { result in
                        Button { selectedGuide = result.guide } label: {
                            CityPaper(inset: 0) {
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Label(result.sourceTitle, systemImage: "checkmark.seal.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(JourneyVisual.accentText)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .foregroundColor(JourneyVisual.secondaryText)
                                    }
                                    Text(result.guide.title)
                                        .font(.system(size: 17, weight: .bold, design: .default))
                                        .foregroundColor(JourneyVisual.primaryText)
                                        .multilineTextAlignment(.leading)
                                    Text(result.excerpt)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(JourneyVisual.secondaryText)
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
                .padding(.bottom, 128)
            }
        }
        .statusBarScrim()
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
            JourneyVisual.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Weekly Digest")
                        .font(.system(size: 29, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text(digest.summary)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JourneyVisual.accentText)

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
                            .foregroundColor(JourneyVisual.secondaryText)
                    }
                }
                .padding(20)
                .padding(.bottom, 128)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func digestSection(_ title: String, items: [String]) -> some View {
        JourneyGlassPanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
                if items.isEmpty {
                    Text("Нічого критичного")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                } else {
                    ForEach(items, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}
