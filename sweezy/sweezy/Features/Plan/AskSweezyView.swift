import SwiftUI

struct AskSweezyView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @State private var query = ""
    @State private var selectedGuide: Guide?
    private let service = AskSweezyService()

    private var results: [AskSweezyResult] {
        service.search(query, guides: appContainer.contentService.getGuidesForLocale(appContainer.currentLocale.identifier), profile: appContainer.userProfile)
    }

    /// Topics people ask about most; each is a word the guide search matches in the app language.
    private let topics: [(key: String, icon: String)] = [
        ("ask.topic.permit", "person.text.rectangle"),
        ("ask.topic.insurance", "cross.case"),
        ("ask.topic.housing", "house"),
        ("ask.topic.work", "briefcase"),
        ("ask.topic.bank", "creditcard"),
        ("ask.topic.taxes", "doc.text"),
        ("ask.topic.school", "graduationcap"),
        ("ask.topic.language", "character.bubble")
    ]

    var body: some View {
        ZStack {
            JourneyVisual.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ask.title".localized)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(JourneyVisual.primaryText)
                            .accessibilityAddTraits(.isHeader)
                        Text("companion.search.subtitle".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(JourneyVisual.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    JourneySearchField(text: $query, prompt: "Наприклад: як продовжити permit?".localized)
                        .accessibilityIdentifier("ask.search")

                    if query.count < 2 {
                        topicChips
                    } else if results.isEmpty {
                        emptyState
                    } else {
                        resultList
                    }
                }
                .padding(20)
                .padding(.bottom, 128)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .statusBarScrim()
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedGuide) { GuideDetailView(guide: $0) }
        .task {
            if appContainer.contentService.guides.isEmpty { await appContainer.contentService.refreshContent() }
        }
    }

    private var topicChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ask.topics".localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(JourneyVisual.secondaryText)
            FlowLayout(spacing: 8) {
                ForEach(topics, id: \.key) { topic in
                    Button { query = topic.key.localized } label: {
                        Label(topic.key.localized, systemImage: topic.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(JourneyVisual.primaryText)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Theme.Colors.card, in: Capsule())
                            .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96, hapticStyle: .light))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("companion.search.empty.title".localized)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(JourneyVisual.primaryText)
            Text("companion.search.empty.subtitle".localized)
                .font(.system(size: 14))
                .foregroundStyle(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("companion.search.reset".localized) { query = "" }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .background(JourneyVisual.lime, in: Capsule())
                .accessibilityIdentifier("ask.reset")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
    }

    private var resultList: some View {
        let shown = Array(results.prefix(8))
        return VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, result in
                Button { selectedGuide = result.guide } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.guide.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(JourneyVisual.primaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(result.excerpt)
                            .font(.system(size: 13))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Label(result.sourceTitle, systemImage: result.sourceURL == nil ? "clock" : "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(result.sourceURL == nil ? JourneyVisual.secondaryText : JourneyVisual.accentText)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < shown.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 16)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
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
                    Text("journey.tool.digest.title".localized)
                        .font(.system(size: 28, weight: .heavy, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text(digest.summary)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JourneyVisual.accentText)

                    digestSection("Наступні дії".localized, items: digest.nextActions.map { "%@ — %@ дн.".localized(with: "\($0.title)", "\($0.daysRemaining)") })
                    digestSection("Документи".localized, items: digest.missingDocuments.map { "Підготувати: %@".localized(with: "\($0.title)") })
                    digestSection("Зустрічі".localized, items: digest.upcomingAppointments.map { "\($0.title) — \($0.formattedDate)" })

                    JourneyPrimaryButton(title: "Нагадувати щопонеділка".localized) {
                        Task { @MainActor in
                            let ok = await appContainer.lifeAdmin.scheduleWeeklyDigest(digest, using: appContainer.notificationService)
                            scheduleMessage = ok ? "Наступний digest заплановано".localized : "Дозволь сповіщення у Settings".localized
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
                    Text("Нічого критичного".localized)
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
