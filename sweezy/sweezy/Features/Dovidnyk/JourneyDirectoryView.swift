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
    @State private var selectedNextActionID: String? = JourneyToolRoute.experts.id
    @State private var showsAllTools = false
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

                ScrollViewReader { proxy in
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
                    #if DEBUG
                    .onAppear {
                        guard UserDefaults.standard.bool(forKey: "screenshotToolsNext") else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            withAnimation(.none) {
                                proxy.scrollTo("tools-next-actions", anchor: .top)
                            }
                        }
                    }
                    #endif
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
        .accessibilityIdentifier("directory.screen")
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

            JourneyPlanHeroCard(
                completedCount: completedPlanTaskCount,
                totalCount: totalPlanTaskCount,
                nextAction: nextPlanAction
            ) {
                selectedTool = .myPlan
            }

            GeometryReader { geometry in
                let cardWidth = max(0, (geometry.size.width - 16) / 3)

                HStack(spacing: 8) {
                    ForEach(JourneyToolRoute.quickUtilities) { route in
                        JourneyToolCard(route: route, width: cardWidth, height: 154, titleSize: 14) {
                            selectedTool = route
                        }
                    }
                }
            }
            .frame(height: 154)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(JourneyToolRoute.careerUtilities) { route in
                    JourneyToolCard(route: route, height: 116, titleSize: 15) {
                        selectedTool = route
                    }
                }
            }

            Text("Що далі?")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 4)
                .id("tools-next-actions")

            JourneyNextActionCarousel(
                selectedID: $selectedNextActionID,
                routes: JourneyToolRoute.nextActions
            ) { route in
                selectedTool = route
            }

            JourneyDigestStrip {
                selectedTool = .digest
            }

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    showsAllTools.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text(showsAllTools ? "Сховати інструменти" : "Відкрити всі інструменти")
                    Image(systemName: showsAllTools ? "chevron.up" : "chevron.right")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(JourneyVisual.lime)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if showsAllTools {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(JourneyToolRoute.moreUtilities) { route in
                        JourneyToolCard(route: route, height: 120, titleSize: 14) {
                            selectedTool = route
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var totalPlanTaskCount: Int {
        appContainer.firstWeekService.tasks.count
    }

    private var completedPlanTaskCount: Int {
        appContainer.firstWeekService.tasks.filter(\.isDone).count
    }

    private var nextPlanAction: String {
        appContainer.firstWeekService.tasks.first(where: { !$0.isDone })?.title
            ?? "Обери наступний крок"
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

    static let quickUtilities: [JourneyToolRoute] = [.documents, .ask, .deadlines]
    static let careerUtilities: [JourneyToolRoute] = [.jobs, .cv]
    static let nextActions: [JourneyToolRoute] = [.appointments, .experts, .moments]
    static let moreUtilities: [JourneyToolRoute] = [.templates, .calculator, .cityHub, .language, .passport, .roadmap]

    var title: String {
        switch self {
        case .myPlan: return "Мій план"
        case .documents: return "Готовність документів"
        case .ask: return "Запитати Sweezy"
        case .deadlines: return "Дедлайни"
        case .appointments: return "Мої зустрічі"
        case .digest: return "Тижневий дайджест"
        case .jobs: return "Робота"
        case .cv: return "Створити CV"
        case .templates: return "Шаблони"
        case .calculator: return "Калькулятор"
        case .cityHub: return "Моє місто"
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

private struct JourneyPlanHeroCard: View {
    let completedCount: Int
    let totalCount: Int
    let nextAction: String
    let action: () -> Void

    private var normalizedTotal: Int { max(totalCount, 1) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image("swiss-moment-grindelwald")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 208)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.04), .black.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 9) {
                    Label("Мій план", systemImage: "checklist.checked")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.monochrome)

                    Text(totalCount > 0 ? "\(completedCount) з \(totalCount) кроків виконано" : "План готовий до налаштування")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))

                    ProgressView(value: Double(completedCount), total: Double(normalizedTotal))
                        .tint(JourneyVisual.lime)
                        .frame(maxWidth: 170)

                    HStack(spacing: 12) {
                        Text("Наступний крок: \(nextAction)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        HStack(spacing: 8) {
                            Text(totalCount > 0 ? "Продовжити" : "Налаштувати")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())
                    }
                }
                .padding(16)
            }
            .frame(height: 208)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
            )
            .shadow(color: JourneyVisual.lime.opacity(0.08), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Мій план. \(completedCount) з \(totalCount) кроків виконано. Наступний крок: \(nextAction)")
    }
}

private struct JourneyToolCard: View {
    let route: JourneyToolRoute
    let width: CGFloat?
    let height: CGFloat
    let titleSize: CGFloat
    let action: () -> Void

    init(
        route: JourneyToolRoute,
        width: CGFloat? = nil,
        height: CGFloat = 168,
        titleSize: CGFloat = 16,
        action: @escaping () -> Void
    ) {
        self.route = route
        self.width = width
        self.height = height
        self.titleSize = titleSize
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image(route.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width)
                    .frame(maxWidth: width == nil ? .infinity : nil)
                    .frame(height: height)
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
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    Text(route.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                        .lineLimit(2)
                }
                .padding(13)
            }
            .frame(width: width)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(route.title). \(route.subtitle)")
    }
}

private struct JourneyNextActionCarousel: View {
    @Binding var selectedID: String?
    let routes: [JourneyToolRoute]
    let action: (JourneyToolRoute) -> Void

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(routes) { route in
                                JourneyNextActionCard(route: route) {
                                    action(route)
                                }
                                .frame(width: max(236, geometry.size.width - 86))
                                .id(route.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 43, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: $selectedID, anchor: .center)
                    .onAppear {
                        DispatchQueue.main.async {
                            selectedID = JourneyToolRoute.experts.id
                            proxy.scrollTo(JourneyToolRoute.experts.id, anchor: .center)
                        }
                    }
                }
            }
            .frame(height: 226)

            HStack(spacing: 6) {
                ForEach(routes) { route in
                    Capsule()
                        .fill(selectedID == route.id ? JourneyVisual.lime : Color.white.opacity(0.34))
                        .frame(width: selectedID == route.id ? 22 : 8, height: 5)
                        .animation(.easeInOut(duration: 0.2), value: selectedID)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

private struct JourneyNextActionCard: View {
    let route: JourneyToolRoute
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image(route.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 226)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: route.icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(JourneyVisual.lime)

                    Text(cardTitle)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Label(statusText, systemImage: statusIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))

                    HStack {
                        Text(buttonTitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
                    .padding(.top, 2)
                }
                .padding(15)
            }
            .frame(height: 226)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.32), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(cardTitle). \(statusText). \(buttonTitle)")
    }

    private var cardTitle: String {
        switch route {
        case .experts: return "Знайти експерта"
        case .appointments: return "Мої зустрічі"
        case .moments: return "Актуально зараз"
        default: return route.title
        }
    }

    private var statusText: String {
        switch route {
        case .experts: return "124 перевірених"
        case .appointments: return "2 заплановано"
        case .moments: return "5 нових"
        default: return route.subtitle
        }
    }

    private var statusIcon: String {
        switch route {
        case .experts: return "checkmark.seal.fill"
        case .appointments: return "calendar"
        case .moments: return "bolt.fill"
        default: return route.icon
        }
    }

    private var buttonTitle: String {
        switch route {
        case .experts: return "Обрати"
        case .appointments: return "Відкрити"
        case .moments: return "Переглянути"
        default: return "Відкрити"
        }
    }
}

private struct JourneyDigestStrip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(JourneyVisual.lime)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Тижневий дайджест")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Новий випуск")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(JourneyVisual.lime)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(Color.black.opacity(0.48))
            .background(.ultraThinMaterial.opacity(0.42))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Тижневий дайджест. Новий випуск")
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
