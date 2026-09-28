import Combine
import SwiftUI

struct JourneyDirectoryView: View {
    @EnvironmentObject private var appContainer: AppContainer
    let requestedSection: DovidnykRouteSection?
    let routeID: UUID

    @StateObject private var germanGame = DailyGermanGameService()
    @State private var searchText = ""
    @State private var selectedCategory: GuideCategory?

    private var directoryHeroAsset: String {
        if selectedWorkspace == .tasks { return "story-documents" }
        guard selectedWorkspace == .guides else { return "city-scene-directory" }
        switch selectedCategory {
        case .housing: return "story-housing"
        case .documents, .legal: return "story-documents"
        case .work, .finance, .banking: return "story-jobs"
        case .education, .integration: return "story-language"
        default: return "city-scene-directory"
        }
    }
    @State private var selectedGuide: Guide?
    @State private var selectedChecklist: Checklist?
    @State private var selectedWorkspace: JourneyDirectoryWorkspace = .guides
    @State private var selectedTool: JourneyToolRoute?
    @State private var selectedToolCategory: JourneyToolkitCategory = .all
    @State private var isSchedulingReminders = false
    @State private var reminderMessage: String?
    @State private var contentRevision = 0
    #if DEBUG
    @State private var didApplyUITestRoute = false
    #endif

    private let featuredCategories: [(GuideCategory?, String, String)] = [
        (nil, "common.all".localized, "sparkles"),
        (.documents, "journey.directory.category.documents".localized, "doc.text"),
        (.housing, "journey.directory.category.housing".localized, "house"),
        (.work, "journey.directory.category.work".localized, "briefcase"),
        (.healthcare, "journey.directory.category.healthcare".localized, "cross.case")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.pageBackground.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(selectedWorkspace == .guides ? "journey.tab.directory".localized : workspaceTitle)
                                    .font(.system(size: 28, weight: .bold, design: .default))
                                    .foregroundColor(JourneyVisual.primaryText)
                                    .lineSpacing(1)
                                    .lineLimit(selectedWorkspace == .tools ? 2 : 3)
                                    .minimumScaleFactor(0.76)
                                    .fixedSize(horizontal: false, vertical: true)


                                if selectedWorkspace == .tools {
                                    Text("journey.directory.toolkit.hero.subtitle".localized)
                                        .font(.system(size: 14, weight: .medium, design: .default))
                                        .foregroundColor(JourneyVisual.secondaryText)
                                }
                            }

                            Spacer()

                            Image(systemName: selectedWorkspace.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(JourneyVisual.accentStrong)
                                .frame(width: 42, height: 42)
                                .background(Theme.Colors.card)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .padding(.top, 16)

                        // The picture follows the topic: moving in for housing, the desk for documents…
                        Color.clear
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .overlay {
                                FocusedSceneImage(name: directoryHeroAsset, focusY: 0.25)
                                    .id(directoryHeroAsset)
                                    .transition(.opacity)
                            }
                            .animation(.easeInOut(duration: 0.35), value: directoryHeroAsset)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)

                        HStack(spacing: 7) {
                            ForEach(JourneyDirectoryWorkspace.allCases) { workspace in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedWorkspace = workspace
                                    }
                                } label: {
                                    VStack(spacing: 5) {
                                        Image(systemName: workspace.icon)
                                            .font(.system(size: 13, weight: .bold))
                                        Text(workspace.title)
                                            .font(.system(size: 11, weight: .bold, design: .default))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .foregroundColor(selectedWorkspace == workspace ? .black : JourneyVisual.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 58)
                                    .background(selectedWorkspace == workspace ? JourneyVisual.lime : Theme.Colors.card)

                                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                                            .stroke(Color.white.opacity(selectedWorkspace == workspace ? 0 : 0.24), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

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
                    .interactiveSwipeBackEnabled()
            }
            .navigationDestination(item: $selectedChecklist) { checklist in
                ChecklistDetailView(checklist: checklist)
                    .interactiveSwipeBackEnabled()
            }
            .navigationDestination(item: $selectedTool) { route in
                toolDestination(route)
                    .interactiveSwipeBackEnabled {
                        selectedTool = nil
                    }
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
            // The catalog loads (or reloads after a country change) while this screen is visible.
            .onReceive(catalogChanges) { _ in
                contentRevision &+= 1
            }
            .onAppear {
                applyRequestedSection()
                #if DEBUG
                if let raw = UserDefaults.standard.string(forKey: "screenshotDirectoryWorkspace"),
                   let workspace = JourneyDirectoryWorkspace(rawValue: raw) {
                    selectedWorkspace = workspace
                }
                if !didApplyUITestRoute,
                   ProcessInfo.processInfo.arguments.contains("--ui-test-cv-builder") {
                    didApplyUITestRoute = true
                    selectedWorkspace = .tools
                    DispatchQueue.main.async {
                        selectedTool = .cv
                    }
                }
                #endif
            }
            .onChange(of: routeID) { _, _ in
                applyRequestedSection()
            }
        }
        .statusBarScrim()
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
            JourneySearchField(text: $searchText, prompt: "journey.directory.search_placeholder".localized)

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
                selectedGuide = guide
            }
            .frame(maxWidth: .infinity)

            if filteredGuides.isEmpty, appContainer.contentService.isLoading {
                SkeletonList(rows: 3)
            } else if filteredGuides.isEmpty {
                MascotEmptyState(
                    title: "journey.directory.no_guides.title".localized,
                    subtitle: "journey.directory.no_guides.subtitle".localized
                )
            } else {
                HStack {
                    Text("journey.directory.verified_materials".localized)
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Spacer()
                    Label("journey.directory.official_sources".localized, systemImage: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(JourneyVisual.accentText)
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 11) {
                Text("journey.directory.toolkit.choose_task".localized)
                    .font(.system(size: 21, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(JourneyToolkitCategory.availableCases(countryCode: APIClient.countryCode)) { category in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedToolCategory = category
                                }
                            } label: {
                                Label(category.title, systemImage: category.icon)
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .foregroundColor(selectedToolCategory == category ? .black : JourneyVisual.primaryText)
                                    .padding(.horizontal, 13)
                                    .frame(height: 42)
                                    .background(selectedToolCategory == category ? JourneyVisual.lime : Theme.Colors.card)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            selectedToolCategory == category ? JourneyVisual.lime : JourneyVisual.softBorder,
                                            lineWidth: selectedToolCategory == category ? 1.4 : 1
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 0, for: .scrollContent)
            }

            Group {
                if selectedToolCategory == .all {
                    JourneyEditorialBento(countryCode: APIClient.countryCode) { route in
                        selectedTool = route
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(selectedToolCategory.routes) { route in
                            JourneyEditorialToolCard(route: route, height: 154) {
                                selectedTool = route
                            }
                        }
                    }
                }
            }

            if selectedToolCategory == .all {
                VStack(alignment: .leading, spacing: 12) {
                    JourneyToolSectionHeader(
                        eyebrow: "journey.directory.toolkit.current.eyebrow".localized,
                        title: "journey.directory.toolkit.current.title".localized
                    )
                    .id("tools-next-actions")

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(JourneyToolRoute.secondaryUtilities.filter { $0.isAvailable(countryCode: APIClient.countryCode) }) { route in
                            JourneyCompactToolTile(route: route, compact: true) {
                                selectedTool = route
                            }
                        }
                    }
                }
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
            ?? "journey.directory.pick_next_step".localized
    }

    private var planProgressLabel: String {
        guard totalPlanTaskCount > 0 else { return "journey.directory.toolkit.plan.ready".localized }
        return "\(completedPlanTaskCount)/\(totalPlanTaskCount)"
    }

    private var tasksWorkspace: some View {
        JourneyChecklistWorkspace(checklists: localizedChecklists) { checklist in
            selectedChecklist = checklist
        }
    }

    private var workspaceTitle: String {
        switch selectedWorkspace {
        case .guides: return "journey.directory.workspace_title.guides".localized
        case .tools: return "journey.directory.workspace_title.tools".localized
        case .tasks: return "journey.directory.workspace_title.tasks".localized
        }
    }

    private var activationStages: [JourneyActivationStage] {
        let tasks = appContainer.firstWeekService.tasks
        let completedCount = tasks.filter(\.isDone).count
        let remindersScheduled = tasks.contains { !$0.notificationIds.isEmpty }
        return [
            JourneyActivationStage(id: "profile", title: "journey.directory.activation.profile".localized, icon: "person.crop.circle", isComplete: appContainer.userProfile != nil),
            JourneyActivationStage(id: "next", title: "journey.directory.activation.next_step".localized, icon: "arrow.right.circle", isComplete: !tasks.isEmpty),
            JourneyActivationStage(id: "action", title: "journey.directory.activation.first_action".localized, icon: "checkmark.circle", isComplete: completedCount > 0),
            JourneyActivationStage(id: "reminder", title: "journey.directory.activation.reminder".localized, icon: "bell", isComplete: remindersScheduled),
            JourneyActivationStage(id: "result", title: "journey.directory.activation.result".localized, icon: "chart.line.uptrend.xyaxis", isComplete: completedCount > 0 || !appContainer.roadmapProgress.completedStageIds.isEmpty)
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
            reminderMessage = scheduled ? "journey.directory.reminders_enabled".localized : "journey.directory.check_notification_settings".localized
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
        case .careerHub: JobsView()
        case .cv: CVBuilderView {
            selectedTool = nil
        }
        case .templates: TemplatesView()
        case .cityHub: CityHubView(hub: CityHubData.zurich)
        case .experts: ExpertsDirectoryView()
        case .moments: JourneyMomentsView(profile: appContainer.userProfile)
        case .language: DailyGermanGameView(service: germanGame)
        case .roadmap: MountainRoadmapView()
        case .discoverSwitzerland: SwissDiscoveryView()
        }
    }

    private var catalogChanges: AnyPublisher<Void, Never> {
        guard let service = appContainer.contentService as? ContentService else {
            return Empty().eraseToAnyPublisher()
        }
        // dropFirst: @Published replays its current value on subscribe, which would loop renders.
        return service.$guides.dropFirst().map { _ in () }
            .merge(with: service.$checklists.dropFirst().map { _ in () })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private var filteredGuides: [Guide] {
        let _ = contentRevision
        // The catalog holds every bundled language; show only the reader's language (Ukrainian fallback).
        return appContainer.contentService.getGuidesForLocale(appContainer.currentLocale.identifier)
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
        case .guides: return "journey.directory.workspace.guides".localized
        case .tools: return "journey.directory.workspace.tools".localized
        case .tasks: return "journey.directory.workspace.tasks".localized
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

private enum JourneyToolkitCategory: String, CaseIterable, Identifiable {
    case all
    case career
    case everyday
    case switzerland
    case community

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "journey.directory.toolkit.category.all".localized
        case .career: return "journey.directory.toolkit.category.career".localized
        case .everyday: return "journey.directory.toolkit.category.everyday".localized
        case .switzerland: return "journey.directory.toolkit.category.switzerland".localized
        case .community: return "journey.directory.toolkit.category.community".localized
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .career: return "briefcase.fill"
        case .everyday: return "checklist.checked"
        case .switzerland: return "mountain.2"
        case .community: return "person.2.fill"
        }
    }

    var routes: [JourneyToolRoute] {
        switch self {
        case .all: return JourneyToolRoute.editorialUtilities
        case .career: return [.careerHub]
        case .everyday: return [.myPlan, .documents, .ask, .deadlines, .appointments, .digest, .templates]
        case .switzerland: return [.discoverSwitzerland, .cityHub, .language, .roadmap]
        case .community: return [.experts, .moments]
        }
    }

    static func availableCases(countryCode: String) -> [JourneyToolkitCategory] {
        countryCode == "CH" ? allCases : allCases.filter { $0 != .switzerland }
    }
}

private enum JourneyToolRoute: String, Identifiable, CaseIterable {
    case myPlan
    case documents
    case ask
    case deadlines
    case appointments
    case digest
    case careerHub
    case cv
    case templates
    case cityHub
    case experts
    case moments
    case language
    case roadmap
    case discoverSwitzerland

    var id: String { rawValue }

    static let quickUtilities: [JourneyToolRoute] = [.careerHub, .discoverSwitzerland, .myPlan, .ask]
    static let editorialUtilities: [JourneyToolRoute] = [.careerHub, .discoverSwitzerland, .myPlan, .documents, .ask, .language, .experts, .moments]
    static let secondaryUtilities: [JourneyToolRoute] = [.deadlines, .appointments, .digest, .templates, .cityHub, .experts, .moments, .roadmap]
    static let planningUtilities: [JourneyToolRoute] = [.myPlan, .documents, .deadlines, .appointments, .digest]
    static let swissUtilities: [JourneyToolRoute] = [.cityHub, .language, .experts, .moments]
    static let nextActions: [JourneyToolRoute] = [.appointments, .experts, .moments]
    static let moreUtilities: [JourneyToolRoute] = [.roadmap]

    func isAvailable(countryCode: String) -> Bool {
        if countryCode == "CH" { return true }
        return ![.discoverSwitzerland, .cityHub, .moments, .roadmap].contains(self)
    }

    var title: String {
        switch self {
        case .myPlan: return "journey.tool.my_plan.title".localized
        case .documents: return "journey.tool.documents.title".localized
        case .ask: return "journey.tool.ask.title".localized
        case .deadlines: return "journey.tool.deadlines.title".localized
        case .appointments: return "journey.tool.appointments.title".localized
        case .digest: return "journey.tool.digest.title".localized
        case .careerHub: return "journey.tool.jobs.title".localized
        case .cv: return "journey.tool.cv.title".localized
        case .templates: return "journey.tool.templates.title".localized
        case .cityHub: return "journey.tool.city_hub.title".localized
        case .experts: return "journey.tool.experts.title".localized
        case .moments: return "journey.tool.moments.title".localized
        case .language: return "journey.tool.language.title".localized
        case .roadmap: return "journey.tool.roadmap.title".localized
        case .discoverSwitzerland: return "journey.tool.discover_switzerland.title".localized
        }
    }

    var subtitle: String {
        switch self {
        case .myPlan: return "journey.tool.my_plan.subtitle".localized
        case .documents: return "journey.tool.documents.subtitle".localized
        case .ask: return "journey.tool.ask.subtitle".localized
        case .deadlines: return "journey.tool.deadlines.subtitle".localized
        case .appointments: return "journey.tool.appointments.subtitle".localized
        case .digest: return "journey.tool.digest.subtitle".localized
        case .careerHub: return "journey.tool.jobs.subtitle".localized
        case .cv: return "journey.tool.cv.subtitle".localized
        case .templates: return "journey.tool.templates.subtitle".localized
        case .cityHub: return "journey.tool.city_hub.subtitle".localized
        case .experts: return "journey.tool.experts.subtitle".localized
        case .moments: return "journey.tool.moments.subtitle".localized
        case .language: return "journey.tool.language.subtitle".localized
        case .roadmap: return "journey.tool.roadmap.subtitle".localized
        case .discoverSwitzerland: return "journey.tool.discover_switzerland.subtitle".localized
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
        case .careerHub: return "briefcase.fill"
        case .cv: return "person.text.rectangle.fill"
        case .templates: return "doc.on.doc.fill"
        case .cityHub: return "building.2.fill"
        case .experts: return "person.2.fill"
        case .moments: return "calendar.badge.clock"
        case .language: return "character.book.closed.fill"
        case .roadmap: return "point.topleft.down.to.point.bottomright.curvepath"
        case .discoverSwitzerland: return "binoculars.fill"
        }
    }

    var imageName: String {
        switch self {
        case .myPlan: return "journey-tool-my-plan"
        case .documents: return "journey-tool-documents"
        case .ask: return "journey-tool-ask"
        case .deadlines: return "journey-tool-deadlines"
        case .appointments: return "cityhub-zurich-fraumuenster"
        case .digest: return "cityhub-zurich-lake"
        case .careerHub: return "journey-tool-jobs"
        case .cv: return "journey-tool-cv"
        case .templates: return "cityhub-zurich-landesmuseum"
        case .cityHub: return "cityhub-zurich-lake"
        case .experts: return "journey-market-consultant"
        case .moments: return "swiss-moment-luzern"
        case .language: return "swiss-moment-grindelwald"
        case .roadmap: return "swiss-moment-grindelwald"
        case .discoverSwitzerland: return "swiss-discovery-aletsch"
        }
    }
}

private struct JourneyActivationStage: Identifiable {
    let id: String
    let title: String
    let icon: String
    let isComplete: Bool
}

private struct JourneyToolkitStatusBoard: View {
    let completedCount: Int
    let totalCount: Int
    let nextAction: String
    let planAction: () -> Void
    let askAction: () -> Void

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("journey.directory.toolkit.board.eyebrow".localized)
                        .font(.system(size: 10, weight: .black, design: .default))
                        .tracking(2.1)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("journey.directory.toolkit.board.title".localized)
                        .font(.system(size: 28, weight: .black, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .stroke(JourneyVisual.softBorder, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: max(progress, 0.08))
                        .stroke(JourneyVisual.lime, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(totalCount > 0 ? "\(completedCount)/\(totalCount)" : "—")
                        .font(.system(size: 11, weight: .black, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                }
                .frame(width: 52, height: 52)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("journey.directory.toolkit.board.next".localized)
                    .font(.system(size: 10, weight: .bold, design: .default))
                    .tracking(1.3)
                    .foregroundColor(JourneyVisual.secondaryText)
                Text(nextAction)
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(2)
            }

            HStack(spacing: 9) {
                Button(action: planAction) {
                    Label("journey.directory.toolkit.board.open_plan".localized, systemImage: "checklist.checked")
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: askAction) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(width: 48, height: 46)
                        .background(Theme.Colors.card)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(JourneyVisual.softBorder))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("journey.tool.ask.title".localized)
            }
        }
        .padding(20)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.Colors.card)
                LinearGradient(
                    colors: [JourneyVisual.lime.opacity(0.12), Color.clear, Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(JourneyVisual.lime.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: JourneyVisual.lime.opacity(0.12), radius: 24, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journey.toolkit.status")
    }
}

private struct JourneyEditorialPlanCard: View {
    let completedCount: Int
    let totalCount: Int
    let nextAction: String
    let action: () -> Void

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    Theme.Colors.card

                    VStack(alignment: .leading, spacing: 10) {
                        Text("journey.directory.toolkit.recommended".localized)
                            .font(.system(size: 9, weight: .black, design: .default))
                            .tracking(1.8)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("journey.tool.my_plan.title".localized)
                            .font(.system(size: 27, weight: .black, design: .default))
                            .foregroundColor(JourneyVisual.primaryText)

                        Text(nextAction)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .lineLimit(2)
                            .frame(maxWidth: min(230, geometry.size.width * 0.7), alignment: .leading)

                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(totalCount > 0 ? "\(completedCount) / \(totalCount)" : "journey.directory.toolkit.plan.ready".localized)
                                    .font(.system(size: 13, weight: .black, design: .default))
                                    .foregroundColor(Theme.Colors.textPrimary)

                                ProgressView(value: progress)
                                    .tint(JourneyVisual.lime)
                                    .frame(maxWidth: 180)
                            }

                            Spacer(minLength: 10)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.black)
                                .frame(width: 48, height: 48)
                                .background(JourneyVisual.lime)
                                .clipShape(Circle())
                        }
                    }
                    .padding(20)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(JourneyVisual.softBorder, lineWidth: 1)
                )
            }
        }
        .frame(height: 200)
        .buttonStyle(.plain)
        .accessibilityLabel("journey.directory.plan_hero.accessibility".localized(with: completedCount, totalCount, nextAction))
        .accessibilityIdentifier("journey.tool.myPlan")
    }
}

private struct JourneyEditorialBento: View {
    let countryCode: String
    let action: (JourneyToolRoute) -> Void

    var body: some View {
        VStack(spacing: 10) {
            JourneyEditorialToolCard(route: .careerHub, height: 96, prominent: true, horizontal: true) {
                action(.careerHub)
            }

            HStack(alignment: .top, spacing: 10) {
                JourneyEditorialToolCard(
                    route: countryCode == "CH" ? .discoverSwitzerland : .cv,
                    height: 204,
                    prominent: true
                ) {
                    action(countryCode == "CH" ? .discoverSwitzerland : .cv)
                }

                VStack(spacing: 10) {
                    JourneyEditorialToolCard(route: .myPlan, height: 97) {
                        action(.myPlan)
                    }
                    JourneyEditorialToolCard(route: .ask, height: 97) {
                        action(.ask)
                    }
                }
            }

            HStack(spacing: 10) {
                JourneyEditorialToolCard(route: .documents, height: 126) {
                    action(.documents)
                }
                JourneyEditorialToolCard(route: .language, height: 126) {
                    action(.language)
                }
            }
        }
    }
}

private struct JourneyEditorialToolCard: View {
    let route: JourneyToolRoute
    let height: CGFloat
    var prominent = false
    var horizontal = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: route.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(route.title)
                            .font(.system(size: prominent ? 18 : 14, weight: .bold))
                            .foregroundColor(JourneyVisual.primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        if prominent {
                            Text(route.subtitle)
                                .font(.system(size: 11))
                                .foregroundColor(JourneyVisual.secondaryText)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                }
                .padding(14)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(JourneyVisual.softBorder))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(route.title). \(route.subtitle)")
        .accessibilityIdentifier("journey.tool.\(route.rawValue)")
    }
}

private struct JourneyToolSectionHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 9, weight: .black, design: .default))
                .tracking(1.8)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(title)
                .font(.system(size: 21, weight: .bold, design: .default))
                .foregroundColor(JourneyVisual.primaryText)
        }
    }
}

private struct JourneyCompactToolTile: View {
    let route: JourneyToolRoute
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                HStack {
                    Image(systemName: route.icon)
                        .font(.system(size: compact ? 15 : 18, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(width: compact ? 34 : 40, height: compact ? 34 : 40)
                        .background(JourneyVisual.lime.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(JourneyVisual.secondaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(route.title)
                        .font(.system(size: compact ? 14 : 16, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                        .lineLimit(2)
                    Text(route.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(compact ? 1 : 2)
                }
            }
            .padding(compact ? 13 : 15)
            .frame(maxWidth: .infinity, minHeight: compact ? 112 : 132, alignment: .topLeading)
            .background(Theme.Colors.card)
            .background(.ultraThinMaterial.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(JourneyVisual.softBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(route.title). \(route.subtitle)")
        .accessibilityIdentifier("journey.tool.\(route.rawValue)")
    }
}

private struct JourneyToolActionRow: View {
    let route: JourneyToolRoute
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: route.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(JourneyVisual.lime.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(route.title)
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text(route.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .black, design: .default))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .background(JourneyVisual.lime.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(JourneyVisual.secondaryText)
                }
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 68)
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(JourneyVisual.softBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(route.title). \(route.subtitle)")
        .accessibilityIdentifier("journey.tool.\(route.rawValue)")
    }
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
                Theme.Colors.card

                VStack(alignment: .leading, spacing: 9) {
                    Label("journey.tool.my_plan.title".localized, systemImage: "checklist.checked")
                        .font(.system(size: 25, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                        .symbolRenderingMode(.monochrome)

                    Text(totalCount > 0 ? "journey.directory.plan_hero.progress".localized(with: completedCount, totalCount) : "journey.directory.plan_hero.ready_to_setup".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)

                    ProgressView(value: Double(completedCount), total: Double(normalizedTotal))
                        .tint(JourneyVisual.lime)
                        .frame(maxWidth: 170)

                    HStack(spacing: 12) {
                        Text("journey.directory.plan_hero.next_step".localized(with: nextAction))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        HStack(spacing: 8) {
                            Text(totalCount > 0 ? "common.continue".localized : "journey.directory.plan_hero.setup".localized)
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 12, weight: .bold, design: .default))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())
                    }
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(JourneyVisual.softBorder, lineWidth: 1)
            )
            .shadow(color: JourneyVisual.lime.opacity(0.08), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("journey.directory.plan_hero.accessibility".localized(with: completedCount, totalCount, nextAction))
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
                Theme.Colors.card

                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: route.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(route.title)
                        .font(.system(size: titleSize, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    Text(route.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
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
                    .stroke(JourneyVisual.softBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(route.title). \(route.subtitle)")
        .accessibilityIdentifier("journey.tool.\(route.rawValue)")
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
            .frame(height: 168)

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
                Theme.Colors.card

                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: route.icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text(cardTitle)
                        .font(.system(size: 21, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)

                    Label(statusText, systemImage: statusIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(JourneyVisual.secondaryText)

                    HStack {
                        Text(buttonTitle)
                            .font(.system(size: 13, weight: .bold, design: .default))
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
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(JourneyVisual.softBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(cardTitle). \(statusText). \(buttonTitle)")
    }

    private var cardTitle: String {
        switch route {
        case .experts: return "journey.directory.next_action.experts.title".localized
        case .appointments: return "journey.tool.appointments.title".localized
        case .moments: return "journey.tool.moments.title".localized
        default: return route.title
        }
    }

    private var statusText: String {
        switch route {
        case .experts: return "journey.directory.next_action.experts.status".localized
        case .appointments: return "journey.directory.next_action.appointments.status".localized
        case .moments: return "journey.directory.next_action.moments.status".localized
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
        case .experts: return "journey.directory.next_action.experts.button".localized
        case .appointments: return "common.open".localized
        case .moments: return "journey.directory.next_action.moments.button".localized
        default: return "common.open".localized
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
                    .foregroundColor(Theme.Colors.textPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("journey.tool.digest.title".localized)
                        .font(.system(size: 14, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text("journey.directory.digest.new_issue".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(Theme.Colors.card)
            .background(.ultraThinMaterial.opacity(0.42))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("journey.directory.digest.accessibility".localized)
    }
}

private struct JourneyWideToolCard: View {
    let route: JourneyToolRoute
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            JourneyGlassPanel(cornerRadius: 21) {
                HStack(spacing: 13) {
                    Image(systemName: route.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(JourneyVisual.accentStrong)
                        .frame(width: 56, height: 56)
                        .background(JourneyVisual.softSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(route.title)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(JourneyVisual.primaryText)
                        Text(route.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
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
                        .foregroundColor(JourneyVisual.primaryText)
                        .strikethrough(task.isDone, color: .white.opacity(0.55))
                    Text(task.dueDate, style: .date)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            .padding(14)
            .background(.ultraThinMaterial.opacity(0.72))
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(JourneyVisual.softBorder, lineWidth: 1)
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
                    Text("journey.directory.moments.title".localized)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(JourneyVisual.primaryText)

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
    let action: (Guide) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(guides.enumerated()), id: \.element.id) { index, guide in
                Button { action(guide) } label: {
                    JourneyGuideCompactRow(
                        guide: guide,
                        imageName: imageNames.indices.contains(index) ? imageNames[index] : "city-scene-directory")
                }
                .buttonStyle(.plain)
            }
        }
    }
}
