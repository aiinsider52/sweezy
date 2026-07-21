import SwiftUI

struct JourneyDirectoryView: View {
    @EnvironmentObject private var appContainer: AppContainer
    let requestedSection: DovidnykRouteSection?
    let routeID: UUID

    @StateObject private var germanGame = DailyGermanGameService()
    @State private var searchText = ""
    @State private var selectedCategory: GuideCategory?
    @State private var selectedGuide: Guide?
    @State private var selectedChecklist: Checklist?
    @State private var selectedWorkspace: JourneyDirectoryWorkspace = .guides
    @State private var selectedTool: JourneyToolRoute?
    @State private var isSchedulingReminders = false
    @State private var reminderMessage: String?
    @State private var contentRevision = 0

    private let featuredCategories: [(GuideCategory?, String, String)] = [
        (nil, "Усі", "sparkles"),
        (.documents, "Документи", "doc.text"),
        (.housing, "Житло", "house"),
        (.work, "Робота", "briefcase"),
        (.healthcare, "Здоров’я", "cross.case")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: "swiss-moment-grindelwald", darkness: 0.38)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top) {
                            Text(workspaceTitle)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineSpacing(-3)
                                .shadow(color: .black.opacity(0.36), radius: 8, y: 4)

                            Spacer()

                            Image(systemName: selectedWorkspace.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(JourneyVisual.lime)
                                .frame(width: 42, height: 42)
                                .background(Color.black.opacity(0.42))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .padding(.top, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(JourneyDirectoryWorkspace.allCases) { workspace in
                                    JourneyFilterChip(
                                        title: workspace.title,
                                        icon: workspace.icon,
                                        isSelected: selectedWorkspace == workspace
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedWorkspace = workspace
                                        }
                                    }
                                }
                            }
                        }
                        .contentMargins(.horizontal, 0, for: .scrollContent)

                        workspaceContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 128)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedGuide) { guide in
                GuideDetailView(guide: guide)
            }
            .navigationDestination(item: $selectedChecklist) { checklist in
                ChecklistDetailView(checklist: checklist)
            }
            .navigationDestination(item: $selectedTool) { route in
                toolDestination(route)
            }
            .task {
                if appContainer.contentService.guides.isEmpty || appContainer.contentService.checklists.isEmpty {
                    await appContainer.contentService.refreshContent()
                }
                contentRevision &+= 1
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "screenshotGuideDetail"),
                   let guide = appContainer.contentService.guides.sorted(by: { $0.priority > $1.priority }).first {
                    selectedGuide = guide
                }
                #endif
            }
            .onAppear {
                applyRequestedSection()
                #if DEBUG
                if let raw = UserDefaults.standard.string(forKey: "screenshotDirectoryWorkspace"),
                   let workspace = JourneyDirectoryWorkspace(rawValue: raw) {
                    selectedWorkspace = workspace
                }
                #endif
            }
            .onChange(of: routeID) { _, _ in
                applyRequestedSection()
            }
        }
    }

    @ViewBuilder
    private var workspaceContent: some View {
        switch selectedWorkspace {
        case .guides:
            guidesWorkspace
        case .tools:
            toolsWorkspace
        case .tasks:
            tasksWorkspace
        }
    }

    private var guidesWorkspace: some View {
        VStack(alignment: .leading, spacing: 18) {
            JourneySearchField(text: $searchText, prompt: "Пошук у довіднику")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(featuredCategories, id: \.1) { category, title, icon in
                        JourneyFilterChip(
                            title: title,
                            icon: icon,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = category
                            }
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)

            JourneyGuideDeck(
                guides: Array(filteredGuides.prefix(3)),
                imageNames: cardImages
            ) { guide in
                if let guide { selectedGuide = guide }
            }
            .frame(maxWidth: .infinity)

            if !filteredGuides.isEmpty {
                HStack {
                    Text("Перевірені матеріали")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Label("Офіційні джерела", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(JourneyVisual.lime)
                }

                VStack(spacing: 10) {
                    ForEach(filteredGuides.dropFirst(3).prefix(5)) { guide in
                        Button { selectedGuide = guide } label: {
                            JourneyGuideCompactRow(guide: guide, imageName: imageName(for: guide))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var toolsWorkspace: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Усе практичне — в одному місці")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(JourneyToolRoute.primary) { route in
                    JourneyToolCard(route: route) {
                        selectedTool = route
                    }
                }
            }

            Text("Після першого результату")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.72))
                .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(JourneyToolRoute.extended) { route in
                    JourneyWideToolCard(route: route) {
                        selectedTool = route
                    }
                }
            }
        }
    }

    private var tasksWorkspace: some View {
        JourneyChecklistWorkspace(checklists: localizedChecklists) { checklist in
            selectedChecklist = checklist
        }
    }

    private var workspaceTitle: String {
        switch selectedWorkspace {
        case .guides: return "Знайди\nпотрібну\nвідповідь"
        case .tools: return "Зроби\nнаступний\nкрок"
        case .tasks: return "Твій прогрес\nкрок за кроком"
        }
    }

    private var activationStages: [JourneyActivationStage] {
        let tasks = appContainer.firstWeekService.tasks
        let completedCount = tasks.filter(\.isDone).count
        let remindersScheduled = tasks.contains { !$0.notificationIds.isEmpty }
        return [
            JourneyActivationStage(id: "profile", title: "Профіль заповнено", icon: "person.crop.circle", isComplete: appContainer.userProfile != nil),
            JourneyActivationStage(id: "next", title: "Наступний крок визначено", icon: "arrow.right.circle", isComplete: !tasks.isEmpty),
            JourneyActivationStage(id: "action", title: "Першу дію виконано", icon: "checkmark.circle", isComplete: completedCount > 0),
            JourneyActivationStage(id: "reminder", title: "Нагадування підключено", icon: "bell", isComplete: remindersScheduled),
            JourneyActivationStage(id: "result", title: "Результат зафіксовано", icon: "chart.line.uptrend.xyaxis", isComplete: completedCount > 0 || !appContainer.roadmapProgress.completedStageIds.isEmpty)
        ]
    }

    private var activationPercent: Int {
        let completed = activationStages.filter(\.isComplete).count
        return Int((Double(completed) / Double(activationStages.count) * 100).rounded())
    }

    private func applyRequestedSection() {
        switch requestedSection {
        case .checklists:
            selectedWorkspace = .tasks
        case .tools:
            selectedWorkspace = .tools
        case .guides, .none:
            selectedWorkspace = .guides
        }
    }

    private func scheduleTaskReminders() {
        isSchedulingReminders = true
        Task { @MainActor in
            let scheduled = await appContainer.firstWeekService.scheduleReminders(
                using: appContainer.notificationService
            )
            reminderMessage = scheduled ? "Нагадування підключено" : "Перевір налаштування сповіщень"
            isSchedulingReminders = false
            appContainer.telemetry.retention(
                .firstWeekReminderScheduled,
                source: "journey_tasks",
                meta: ["scheduled": String(scheduled)]
            )
        }
    }

    @ViewBuilder
    private func toolDestination(_ route: JourneyToolRoute) -> some View {
        switch route {
        case .myPlan: MyPlanView()
        case .documents: DocumentReadinessView()
        case .ask: AskSweezyView()
        case .deadlines: DeadlineEngineView()
        case .appointments: AppointmentsView()
        case .digest: WeeklyDigestView()
        case .jobs: JobsView()
        case .cv: CVBuilderView()
        case .templates: TemplatesView()
        case .calculator: BenefitsCalculatorView()
        case .cityHub: CityHubView(hub: CityHubData.zurich)
        case .experts: ExpertsDirectoryView()
        case .moments: JourneyMomentsView(profile: appContainer.userProfile)
        case .language: DailyGermanGameView(service: germanGame)
        case .passport: SweezyPassportView()
        case .roadmap: MountainRoadmapView()
        }
    }

    private var filteredGuides: [Guide] {
        appContainer.contentService.guides
            .filter { guide in
                let matchesCategory = selectedCategory == nil || guide.category == selectedCategory
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchesSearch = query.isEmpty || guide.searchRelevance(for: query) > 0
                return matchesCategory && matchesSearch
            }
            .sorted { $0.priority > $1.priority }
    }

    private var localizedChecklists: [Checklist] {
        let _ = contentRevision
        let localized = appContainer.contentService.getChecklistsForLocale(appContainer.currentLocale.identifier)
        return (localized.isEmpty ? appContainer.contentService.checklists : localized)
            .sorted { $0.priority > $1.priority }
    }

    private func imageName(for guide: Guide) -> String {
        switch guide.category {
        case .housing: return "cityhub-zurich-oldtown"
        case .healthcare, .insurance: return "swiss-moment-luzern"
        case .work: return "cityhub-zurich-viadukt"
        default: return "swiss-moment-grindelwald"
        }
    }

    private var cardImages: [String] {
        ["swiss-moment-grindelwald", "cityhub-zurich-lake", "swiss-moment-luzern", "cityhub-zurich-oldtown"]
    }
}

private enum JourneyDirectoryWorkspace: String, CaseIterable, Identifiable {
    case guides
    case tools
    case tasks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guides: return "Гайди"
        case .tools: return "Інструменти"
        case .tasks: return "Чек-листи"
        }
    }

    var icon: String {
        switch self {
        case .guides: return "book.closed"
        case .tools: return "wrench.and.screwdriver"
        case .tasks: return "checklist.checked"
        }
    }
}

private enum JourneyToolRoute: String, Identifiable, CaseIterable {
    case myPlan
    case documents
    case ask
    case deadlines
    case appointments
    case digest
    case jobs
    case cv
    case templates
    case calculator
    case cityHub
    case passport
    case experts
    case moments
    case language
    case roadmap

    var id: String { rawValue }

    static let primary: [JourneyToolRoute] = [.myPlan, .documents, .ask, .deadlines, .jobs, .cv]
    static let extended: [JourneyToolRoute] = [.experts, .appointments, .moments, .digest, .templates, .calculator, .cityHub, .language, .passport]

    var title: String {
        switch self {
        case .myPlan: return "Мій план"
        case .documents: return "Готовність документів"
        case .ask: return "Ask Sweezy"
        case .deadlines: return "Deadline Engine"
        case .appointments: return "Мої зустрічі"
        case .digest: return "Weekly Digest"
        case .jobs: return "Робота"
        case .cv: return "CV Builder"
        case .templates: return "Шаблони"
        case .calculator: return "Калькулятор"
        case .cityHub: return "City Hub"
        case .passport: return "Sweezy Passport"
        case .experts: return "Перевірені експерти"
        case .moments: return "Актуально зараз"
        case .language: return "Німецька щодня"
        case .roadmap: return "Відкрити повний шлях"
        }
    }

    var subtitle: String {
        switch self {
        case .myPlan: return "Дії на сьогодні й тиждень"
        case .documents: return "Що готово, чого бракує"
        case .ask: return "Відповіді з офіційними джерелами"
        case .deadlines: return "Permit, insurance, tax"
        case .appointments: return "Офіси та консультації"
        case .digest: return "Усе важливе раз на тиждень"
        case .jobs: return "Пошук і AI match"
        case .cv: return "Швейцарський формат"
        case .templates: return "Документи без помилок"
        case .calculator: return "Виплати та субсидії"
        case .cityHub: return "Життя у твоєму місті"
        case .passport: return "Прогрес і досягнення"
        case .experts: return "Допомога від людей поруч"
        case .moments: return "Дедлайни й важливі події"
        case .language: return "Одна корисна гра на день"
        case .roadmap: return "Усі етапи та результати"
        }
    }

    var icon: String {
        switch self {
        case .myPlan: return "checklist.checked"
        case .documents: return "doc.text.fill"
        case .ask: return "sparkles"
        case .deadlines: return "calendar.badge.exclamationmark"
        case .appointments: return "calendar.badge.plus"
        case .digest: return "newspaper.fill"
        case .jobs: return "briefcase.fill"
        case .cv: return "person.text.rectangle.fill"
        case .templates: return "doc.on.doc.fill"
        case .calculator: return "function"
        case .cityHub: return "building.2.fill"
        case .passport: return "seal.fill"
        case .experts: return "person.2.fill"
        case .moments: return "calendar.badge.clock"
        case .language: return "character.book.closed.fill"
        case .roadmap: return "point.topleft.down.to.point.bottomright.curvepath"
        }
    }

    var imageName: String {
        switch self {
        case .myPlan, .deadlines: return "swiss-moment-grindelwald"
        case .documents: return "cityhub-zurich-landesmuseum"
        case .ask: return "cityhub-zurich-oldtown"
        case .appointments: return "cityhub-zurich-fraumuenster"
        case .digest: return "cityhub-zurich-lake"
        case .jobs, .cv: return "cityhub-zurich-oldtown"
        case .templates, .calculator: return "cityhub-zurich-landesmuseum"
        case .cityHub: return "cityhub-zurich-lake"
        case .passport: return "swiss-moment-zurich"
        case .experts: return "journey-market-consultant"
        case .moments: return "swiss-moment-luzern"
        case .language: return "swiss-moment-grindelwald"
        case .roadmap: return "swiss-moment-grindelwald"
        }
    }
}

private struct JourneyActivationStage: Identifiable {
    let id: String
    let title: String
    let icon: String
    let isComplete: Bool
}

private struct JourneyToolCard: View {
    let route: JourneyToolRoute
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image(route.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 168)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: route.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(JourneyVisual.lime)
                    Text(route.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(route.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                        .lineLimit(2)
                }
                .padding(13)
            }
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct JourneyWideToolCard: View {
    let route: JourneyToolRoute
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            JourneyGlassPanel(cornerRadius: 21) {
                HStack(spacing: 13) {
                    Image(route.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(route.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(route.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.64))
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(JourneyVisual.lime)
                }
                .padding(11)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct JourneyTaskRow: View {
    let task: FirstWeekChecklistService.TaskItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(task.isDone ? JourneyVisual.lime : .white.opacity(0.72))

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .strikethrough(task.isDone, color: .white.opacity(0.55))
                    Text(task.dueDate, style: .date)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(14)
            .background(.ultraThinMaterial.opacity(0.72))
            .background(Color.black.opacity(0.26))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct JourneyMomentsView: View {
    let profile: UserProfile?

    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: "swiss-moment-luzern", blurRadius: 3, darkness: 0.58)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Актуально\nдля тебе зараз")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    JourneyGlassPanel(cornerRadius: 28) {
                        MomentsHomeSection(profile: profile)
                            .padding(.vertical, 18)
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct JourneyGuideDeck: View {
    let guides: [Guide]
    let imageNames: [String]
    let action: (Guide?) -> Void

    var body: some View {
        ZStack {
            JourneyGuideDeckCard(item: leftItem, isFeatured: false) {
                action(leftItem.guide)
            }
            .offset(x: -118, y: 12)
            .rotationEffect(.degrees(-2.5))
            .zIndex(0)

            JourneyGuideDeckCard(item: rightItem, isFeatured: false) {
                action(rightItem.guide)
            }
            .offset(x: 118, y: 12)
            .rotationEffect(.degrees(2.5))
            .zIndex(0)

            JourneyGuideDeckCard(item: centerItem, isFeatured: true) {
                action(centerItem.guide)
            }
            .zIndex(2)
        }
        .frame(height: 334)
    }

    private var centerItem: JourneyGuideDeckItem {
        if let guide = guides.first {
            return item(for: guide, imageName: imageNames[0])
        }
        return JourneyGuideDeckItem(
            guide: nil,
            title: "Перші 30 днів\nу Швейцарії",
            readingTime: 12,
            imageName: "swiss-moment-grindelwald"
        )
    }

    private var leftItem: JourneyGuideDeckItem {
        if guides.count > 1 {
            return item(for: guides[1], imageName: imageNames[1])
        }
        return JourneyGuideDeckItem(
            guide: nil,
            title: "Робота\nу Швейцарії",
            readingTime: 8,
            imageName: "cityhub-zurich-oldtown"
        )
    }

    private var rightItem: JourneyGuideDeckItem {
        if guides.count > 2 {
            return item(for: guides[2], imageName: imageNames[2])
        }
        return JourneyGuideDeckItem(
            guide: nil,
            title: "Медичне\nстрахування",
            readingTime: 10,
            imageName: "swiss-moment-luzern"
        )
    }

    private func item(for guide: Guide, imageName: String) -> JourneyGuideDeckItem {
        JourneyGuideDeckItem(
            guide: guide,
            title: guide.title,
            readingTime: guide.estimatedReadingTime,
            imageName: imageName
        )
    }
}

private struct JourneyGuideDeckItem {
    let guide: Guide?
    let title: String
    let readingTime: Int
    let imageName: String
}

private struct JourneyGuideDeckCard: View {
    let item: JourneyGuideDeckItem
    let isFeatured: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.18), Color.black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 12) {
                    Spacer()

                    Text(item.title)
                        .font(.system(size: isFeatured ? 19 : 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Label("\(item.readingTime) хв", systemImage: "clock")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.74))
                        Spacer()
                        Image(systemName: "bookmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }

                    if isFeatured {
                        HStack {
                            Spacer()
                            Text("Читати")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(JourneyVisual.lime)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Color.black.opacity(0.94))
                        .clipShape(Capsule())
                    }
                }
                .padding(isFeatured ? 14 : 12)
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(isFeatured ? 0.86 : 0.44), lineWidth: isFeatured ? 1.4 : 1)
            )
            .shadow(color: isFeatured ? JourneyVisual.lime.opacity(0.42) : .black.opacity(0.3), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var cardWidth: CGFloat { isFeatured ? 194 : 166 }
    private var cardHeight: CGFloat { isFeatured ? 326 : 292 }
}
