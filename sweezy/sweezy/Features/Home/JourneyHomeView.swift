import SwiftUI

struct JourneyHomeView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showRoadmap = false
    @State private var showMyPlan = false
    @State private var showSubscription = false
    @State private var showCareerHub = false
    @State private var showSettings = false

    private let actions: [(String, String, DovidnykRouteSection?)] = [
        ("doc.text", "journey.home.action.documents".localized, .checklists),
        ("briefcase.fill", "Career Hub", .tools),
        ("house", "journey.home.action.housing".localized, .guides),
        ("cross.case", "journey.home.action.health".localized, .guides)
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    JourneyPhotoBackground(imageName: "cityhub-zurich-lake", darkness: 0.24)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            profileHeader
                                .padding(.top, 12)

                            heroTitle
                                .padding(.top, 24)

                            progressLabel
                                .padding(.top, 18)

                            planPulse
                                .padding(.top, 24)

                            Spacer(minLength: 28)

                            quickActions
                            nextStepCard
                                .padding(.top, 20)

                            if !subscriptionManager.isPremium {
                                SweezyPlusHomeCard {
                                    showSubscription = true
                                    APIClient.logPaywall(eventType: "cta_click", context: SubscriptionSource.home.rawValue)
                                }
                                .padding(.top, 20)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 126)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height - 24, alignment: .top)
                    }
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showRoadmap) {
                MountainRoadmapView()
                    .environmentObject(appContainer)
            }
            .navigationDestination(isPresented: $showMyPlan) {
                MyPlanView()
                    .environmentObject(appContainer)
            }
            .navigationDestination(isPresented: $showCareerHub) {
                JobsView()
                    .environmentObject(appContainer)
            }
            .fullScreenCover(isPresented: $showSubscription) {
                SubscriptionView(source: .home)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appContainer)
            }
            .onAppear {
                appContainer.telemetry.retention(
                    .nextActionViewed,
                    source: "journey_home",
                    meta: ["title": nextStepTitle]
                )
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "screenshotRoadmap") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showRoadmap = true
                    }
                }
                #endif
            }
            .task {
                await subscriptionManager.load()
            }
        }
        .accessibilityIdentifier("home.screen")
    }

    private var profileHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 30, height: 30)
                Image(systemName: "person.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("journey.home.greeting".localized(with: firstName))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("settings.title".localized)
            .accessibilityIdentifier("home.openSettingsButton")
        }
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: -3) {
            Text("journey.home.hero.line1".localized)
            HStack(spacing: 7) {
                Text("journey.home.hero.line2".localized)
                Text("journey.home.hero.line3".localized)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(JourneyVisual.lime)
                            .rotationEffect(.degrees(-1.5))
                    )
            }
        }
        .font(.system(size: 38, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .lineSpacing(-2)
        .shadow(color: .black.opacity(0.32), radius: 8, y: 3)
    }

    private var progressLabel: some View {
        HStack(spacing: 8) {
            Text("\(completedTasks)/\(max(7, appContainer.firstWeekService.tasks.count))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text("journey.home.steps_completed".localized)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.7))
    }

    private var planPulse: some View {
        Button { showMyPlan = true } label: {
            JourneyGlassPanel(cornerRadius: 22) {
                HStack(spacing: 12) {
                    Image(systemName: urgentDeadlineCount > 0 ? "exclamationmark.circle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(urgentDeadlineCount > 0 ? .orange : JourneyVisual.lime)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("journey.home.plan_today".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(planPulseSubtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(JourneyVisual.lime)
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.myPlan")
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                Button {
                    if index == 1 {
                        showCareerHub = true
                    } else {
                        NotificationCenter.default.post(
                            name: .switchTab,
                            object: SwitchTabPayload(tab: 1, section: action.2)
                        )
                    }
                } label: {
                    VStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.30))
                                .background(.ultraThinMaterial.opacity(0.68))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .frame(height: 54)
                            Image(systemName: action.0)
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Text(action.1)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.1)
                .accessibilityIdentifier("home.quickAction.\(["documents", "jobs", "housing", "health"][index])")
            }
        }
    }

    private var nextStepCard: some View {
        JourneyGlassPanel(cornerRadius: 24) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("journey.home.next_step_arrow".localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.62))

                    Text(nextStepTitle)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    JourneyPrimaryButton(title: "common.continue".localized, compact: true) {
                        if appContainer.firstWeekService.nextDueTask == nil {
                            showRoadmap = true
                        } else {
                            NotificationCenter.default.post(
                                name: .switchTab,
                                object: SwitchTabPayload(tab: 1, section: .checklists)
                            )
                        }
                        appContainer.telemetry.retention(
                            .nextActionTapped,
                            source: "journey_home",
                            meta: ["destination": appContainer.firstWeekService.nextDueTask == nil ? "roadmap" : "tasks"]
                        )
                    }
                }

                Spacer(minLength: 4)

                Image("cityhub-zurich-landesmuseum")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .opacity(0.82)
            }
            .padding(16)
        }
    }

    private var firstName: String {
        let name = lockManager.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.split(separator: " ").first.map(String.init) ?? "journey.home.default_name".localized
    }

    private var completedTasks: Int {
        appContainer.firstWeekService.tasks.filter(\.isDone).count
    }

    private var nextStepTitle: String {
        appContainer.firstWeekService.nextDueTask?.title ?? "journey.home.default_next_step".localized
    }

    private var homeDeadlines: [LifeDeadline] {
        appContainer.lifeAdmin.deadlines(
            profile: appContainer.userProfile,
            firstWeekTasks: appContainer.firstWeekService.tasks,
            appointments: appContainer.appointmentRepository.appointments
        )
    }

    private var urgentDeadlineCount: Int {
        homeDeadlines.filter { $0.urgency == .overdue || $0.urgency == .urgent }.count
    }

    private var planPulseSubtitle: String {
        if urgentDeadlineCount > 0 { return "journey.home.urgent_actions".localized(with: urgentDeadlineCount) }
        if let next = homeDeadlines.first { return "journey.home.next_deadline".localized(with: next.title) }
        return "journey.home.all_under_control".localized
    }
}
