import SwiftUI

@MainActor
final class ProfessionalNetworkViewModel: ObservableObject {
    @Published var profiles: [ProfessionalProfile] = []
    @Published var connections: [ProfessionalConnection] = []
    @Published var myProfile: ProfessionalProfile?
    @Published var events: [EventListing] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedCanton: String?
    @Published var selectedRole: ProfessionalRole?
    @Published var selectedGoal: ProfessionalGoal?
    @Published var isShowingDemoProfiles = false

    var incoming: [ProfessionalConnection] { connections.filter { $0.direction == "incoming" && $0.status == "pending" } }
    var outgoing: [ProfessionalConnection] { connections.filter { $0.direction == "outgoing" && $0.status == "pending" } }
    var accepted: [ProfessionalConnection] { connections.filter { $0.status == "accepted" } }

    func loadAll() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        async let profilePage = NetworkAPI.profiles(
            query: searchText,
            canton: selectedCanton,
            role: selectedRole,
            goal: selectedGoal
        )
        async let connectionItems = NetworkAPI.connections()
        async let own = loadMyProfile()
        async let eventPage = APIClient.fetchEvents(page: 1)
        do {
            let (page, loadedConnections, loadedOwn, loadedEvents) = try await (profilePage, connectionItems, own, eventPage)
            profiles = page.items
            connections = loadedConnections
            myProfile = loadedOwn
            events = Array(loadedEvents.items.prefix(4))
            errorMessage = nil
            isShowingDemoProfiles = false
            #if DEBUG
            if profiles.isEmpty { applyDemoProfiles() }
            #endif
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            applyDemoProfiles()
            errorMessage = nil
            #endif
        }
    }

    func reloadProfiles() async {
        isLoading = true
        defer { isLoading = false }
        do {
            profiles = try await NetworkAPI.profiles(
                query: searchText,
                canton: selectedCanton,
                role: selectedRole,
                goal: selectedGoal
            ).items
            errorMessage = nil
            isShowingDemoProfiles = false
            #if DEBUG
            if profiles.isEmpty { applyDemoProfiles() }
            #endif
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            applyDemoProfiles()
            errorMessage = nil
            #endif
        }
    }

    func save(_ draft: ProfessionalProfileDraft) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            myProfile = try await NetworkAPI.saveProfile(draft)
            await reloadProfiles()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func connect(to profile: ProfessionalProfile, message: String) async -> Bool {
        do {
            let connection = try await NetworkAPI.connect(
                userID: profile.userID,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message
            )
            connections.insert(connection, at: 0)
            updateProfileConnection(connection)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func respond(_ connection: ProfessionalConnection, accept: Bool) async -> ProfessionalConnection? {
        do {
            let updated = try await NetworkAPI.respond(connectionID: connection.id, accept: accept)
            if let index = connections.firstIndex(where: { $0.id == updated.id }) { connections[index] = updated }
            updateProfileConnection(updated)
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func cancel(_ connection: ProfessionalConnection) async {
        do {
            try await NetworkAPI.cancel(connectionID: connection.id)
            connections.removeAll { $0.id == connection.id }
            if let index = profiles.firstIndex(where: { $0.userID == connection.otherProfile.userID }) {
                profiles[index] = connection.otherProfile.withConnection(state: "none", id: nil, conversationID: nil)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func block(_ profile: ProfessionalProfile) async -> Bool {
        do {
            try await NetworkAPI.block(userID: profile.userID)
            profiles.removeAll { $0.userID == profile.userID }
            connections.removeAll { $0.otherProfile.userID == profile.userID }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func loadMyProfile() async throws -> ProfessionalProfile? {
        do { return try await NetworkAPI.myProfile() }
        catch where (error as NSError).code == 404 { return nil }
    }

    private func updateProfileConnection(_ connection: ProfessionalConnection) {
        guard let index = profiles.firstIndex(where: { $0.userID == connection.otherProfile.userID }) else { return }
        profiles[index] = connection.otherProfile
    }

    #if DEBUG
    func applyDemoProfiles() {
        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        profiles = ProfessionalProfile.previewProfiles.filter { profile in
            let matchesQuery = normalizedQuery.isEmpty || [profile.displayName, profile.headline, profile.industry, profile.city]
                .joined(separator: " ").lowercased().contains(normalizedQuery)
            let matchesCanton = selectedCanton == nil || profile.canton == selectedCanton
            let matchesRole = selectedRole == nil || profile.role == selectedRole
            let matchesGoal = selectedGoal.map { profile.goals.contains($0) } ?? true
            return matchesQuery && matchesCanton && matchesRole && matchesGoal
        }
        isShowingDemoProfiles = true
    }
    #endif
}

struct ProfessionalNetworkView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var vm = ProfessionalNetworkViewModel()
    @State private var section: NetworkSection = .discover
    @State private var selectedProfile: ProfessionalProfile?
    @State private var selectedEvent: EventListing?
    @State private var selectedConversation: ChatConversation?
    @State private var showEditor = false
    @State private var showAuth = false
    @State private var showFilters = false
    @State private var showVerifiedExperts = false
    @State private var showFriends = false
    @State private var showMoreMatches = false

    private enum NetworkSection: String, CaseIterable, Identifiable {
        case discover = "Люди"
        case requests = "Зв’язки"
        case profile = "Профіль"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .discover: return "sparkle.magnifyingglass"
            case .requests: return "person.2.fill"
            case .profile: return "person.crop.circle"
            }
        }
    }

    var body: some View {
        Group {
            if sessionManager.isAuthenticated || isUITestPreview {
                networkContent
            } else {
                accessGate
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedProfile) { profile in
            NetworkProfileDetailView(
                profile: profile,
                vm: vm,
                selectedConversation: $selectedConversation,
                isDemo: vm.isShowingDemoProfiles || isUITestPreview
            )
                .environmentObject(appContainer)
        }
        .fullScreenCover(item: $selectedConversation) { conversation in
            ChatConversationView(conversation: conversation)
                .environmentObject(appContainer)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(eventId: event.id, initialEvent: event)
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showEditor) {
            NetworkProfileEditorView(profile: vm.myProfile, vm: vm)
        }
        .fullScreenCover(isPresented: $showVerifiedExperts) {
            NavigationStack { ExpertsDirectoryView() }
                .environmentObject(appContainer)
        }
        .fullScreenCover(isPresented: $showFriends) {
            FriendNetworkView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showAuth) {
            AuthEntryView(showsCloseButton: true) { showAuth = false }
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showFilters) {
            discoveryFiltersSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Swiss Network", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .task {
            if isUITestPreview { loadPreviewData() }
            else if sessionManager.isAuthenticated { await vm.loadAll() }
        }
        .onChange(of: sessionManager.isAuthenticated) { _, authenticated in
            if authenticated {
                showAuth = false
                Task { await vm.loadAll() }
            }
        }
    }

    private var networkContent: some View {
        ZStack {
            JourneyVisual.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if section == .discover {
                        editorialDiscovery
                    } else {
                        secondaryHeader
                        sectionSwitcher
                        Group {
                            switch section {
                            case .discover: EmptyView()
                            case .requests: connectionsSection
                            case .profile: myProfileSection
                            }
                        }
                        .padding(.top, 24)
                    }
                }
                .padding(.bottom, 48)
            }
            .refreshable {
                if !isUITestPreview { await vm.loadAll() }
            }
        }
        .accessibilityIdentifier("network.screen")
    }

    private var editorialDiscovery: some View {
        VStack(spacing: 0) {
            editorialHeader
            spotlightGoalTabs

            if vm.isLoading && vm.profiles.isEmpty {
                networkSkeleton
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
            } else if let profile = featuredProfile {
                spotlightProfile(profile)
            } else {
                emptyDiscover
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
            }
        }
    }

    private var editorialHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    NetworkSVGIcon(name: "network-icon-back", size: 22)
                        .foregroundColor(JourneyVisual.lime)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Text("SWEEZY NETWORK")
                    .font(.system(size: 11, weight: .black, design: .default))
                    .tracking(3.2)
                    .foregroundColor(JourneyVisual.lime)

                Spacer(minLength: 12)

                Button { showFilters = true } label: {
                    NetworkSVGIcon(name: "network-icon-filter", size: 24)
                        .foregroundColor(JourneyVisual.lime)
                        .frame(width: 50, height: 50)
                        .background(Color.black)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(JourneyVisual.lime, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Пошук і фільтри")
                .accessibilityIdentifier("network.filters")
            }

            editorialHeadline
                .padding(.top, 18)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var editorialHeadline: some View {
        Text("Знайди людину,\nяка \(Text("прискорить\nтвій бізнес").foregroundColor(JourneyVisual.lime))")
        .foregroundColor(.white)
        .font(.system(size: 37, weight: .black, design: .default))
        .tracking(-1.0)
        .lineSpacing(-3)
        .fixedSize(horizontal: false, vertical: true)
        .minimumScaleFactor(0.82)
        .accessibilityLabel("Знайди людину, яка прискорить твій бізнес")
        .accessibilityIdentifier("network.editorialHeadline")
    }

    private var spotlightGoalTabs: some View {
        HStack(spacing: 8) {
            ForEach(spotlightGoals) { goal in
                let active = activeSpotlightGoal == goal
                Button {
                    vm.selectedGoal = goal
                    showMoreMatches = false
                    Task { await vm.reloadProfiles() }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 4) {
                            NetworkSVGIcon(name: spotlightGoalIcon(goal), size: 15)
                            Text(goal.title)
                                .font(.system(size: 11, weight: active ? .bold : .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        .foregroundColor(active ? JourneyVisual.lime : .white.opacity(0.48))

                        Capsule()
                            .fill(active ? JourneyVisual.lime : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
    }

    private var spotlightGoals: [ProfessionalGoal] {
        [.partners, .clients, .cofounder, .investing]
    }

    private var activeSpotlightGoal: ProfessionalGoal {
        vm.selectedGoal ?? .partners
    }

    private var featuredProfile: ProfessionalProfile? {
        vm.profiles.first(where: \.isFeatured) ?? vm.profiles.first
    }

    private var remainingProfiles: [ProfessionalProfile] {
        guard let featuredProfile else { return [] }
        return vm.profiles.filter { $0.id != featuredProfile.id }
    }

    private func spotlightProfile(_ profile: ProfessionalProfile) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                NetworkSpotlightPhoto(profile: profile, isDemo: vm.isShowingDemoProfiles || isUITestPreview)
                    .frame(maxWidth: .infinity)
                    .frame(height: 640)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.05), .clear, Color.black.opacity(0.45), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(profile.displayName)
                            .font(.system(size: 36, weight: .bold, design: .default))
                            .tracking(-0.9)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                        if profile.isVerified {
                            Image("network-icon-verified")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                        }
                    }

                    Text(profile.headline)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.68))

                    HStack(spacing: 8) {
                        NetworkSVGIcon(name: "network-icon-location", size: 18)
                        Text("\(profile.city) · \(profile.canton)")
                    }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(JourneyVisual.lime)

                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(maxWidth: 210, maxHeight: 1)

                    Text(profile.bio)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(profile.skills.prefix(3), id: \.self) { skill in
                                spotlightSkill(skill)
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                VStack {
                    HStack {
                        matchBadge(for: profile)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 34)
            }

            Button { selectedProfile = profile } label: {
                HStack(spacing: 14) {
                    NetworkSVGIcon(name: "network-icon-send", size: 22)
                    Text(connectionCTATitle(profile))
                        .font(.system(size: 17, weight: .black, design: .default))
                    Spacer()
                    NetworkSVGIcon(name: "network-icon-back", size: 18)
                        .rotationEffect(.degrees(180))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.82, green: 1, blue: 0.27), JourneyVisual.lime],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .accessibilityIdentifier("network.profile.\(profile.userID)")

            if !remainingProfiles.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        showMoreMatches.toggle()
                    }
                } label: {
                    HStack(spacing: 13) {
                        NetworkSVGIcon(name: "network-icon-more", size: 21)
                            .foregroundColor(.white.opacity(0.78))
                            .frame(width: 46, height: 46)
                            .background(Color.white.opacity(0.055))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ще \(remainingProfiles.count) сильних збігів")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(showMoreMatches ? "Згорнути список" : "Потягни, щоб переглянути")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.42))
                        }
                        Spacer()
                        Image(systemName: showMoreMatches ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(JourneyVisual.lime)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            if showMoreMatches {
                LazyVStack(spacing: 12) {
                    ForEach(remainingProfiles) { item in
                        Button { selectedProfile = item } label: {
                            NetworkProfileCard(profile: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("network.profile.\(item.userID)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            networkUtilityDock
                .padding(.top, 22)
        }
    }

    private func matchBadge(for profile: ProfessionalProfile) -> some View {
        HStack(spacing: 9) {
            NetworkSVGIcon(name: "network-icon-match", size: 18)
            Text("\(matchScore(for: profile))% збіг")
        }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(JourneyVisual.lime)
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(Color.black.opacity(0.72))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(JourneyVisual.lime.opacity(0.62)))
    }

    private func matchScore(for profile: ProfessionalProfile) -> Int {
        var score = 78
        if profile.canton == vm.myProfile?.canton { score += 8 }
        let ownGoals = vm.myProfile?.goals ?? [activeSpotlightGoal]
        if profile.goals.contains(where: ownGoals.contains) { score += 6 }
        if profile.isVerified { score += 2 }
        return min(score, 98)
    }

    private func spotlightSkill(_ skill: String) -> some View {
        HStack(spacing: 7) {
            NetworkSVGIcon(name: skillIcon(skill), size: 15)
            Text(skillDisplayName(skill))
        }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.78))
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(Color.black.opacity(0.46))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.24)))
    }

    private func skillDisplayName(_ skill: String) -> String {
        skill == "AI" ? "AI / ML" : skill == "Go-to-market" ? "B2B SaaS" : skill
    }

    private func skillIcon(_ skill: String) -> String {
        let value = skill.lowercased()
        if value.contains("ai") { return "network-icon-ai" }
        if value.contains("fin") { return "network-icon-fintech" }
        if value.contains("market") || value.contains("saas") { return "network-icon-b2b" }
        return "network-icon-partners"
    }

    private func spotlightGoalIcon(_ goal: ProfessionalGoal) -> String {
        switch goal {
        case .partners: return "network-icon-partners"
        case .clients: return "network-icon-clients"
        case .cofounder: return "network-icon-cofounder"
        case .investing: return "network-icon-investors"
        default: return "network-icon-partners"
        }
    }

    private func connectionCTATitle(_ profile: ProfessionalProfile) -> String {
        switch profile.connectionState {
        case "accepted": return "Відкрити контакт"
        case "outgoing": return "Запит надіслано"
        case "incoming": return "Відповісти на запит"
        default: return "Познайомитися"
        }
    }

    private func connectionCTAIcon(_ profile: ProfessionalProfile) -> String {
        switch profile.connectionState {
        case "accepted": return "message.fill"
        case "outgoing": return "clock.fill"
        case "incoming": return "person.crop.circle.badge.checkmark"
        default: return "paperplane.fill"
        }
    }

    private var networkUtilityDock: some View {
        HStack(spacing: 10) {
            utilityButton(title: "Зв’язки", icon: "person.2.fill", badge: vm.incoming.count) { section = .requests }
            utilityButton(title: "Мій профіль", icon: "person.crop.circle") { section = .profile }
            utilityButton(title: "Friends", icon: "sparkles") { showFriends = true }
        }
        .padding(.horizontal, 20)
    }

    private func utilityButton(title: String, icon: String, badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.black)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(JourneyVisual.lime)
                            .clipShape(Circle())
                            .offset(x: 9, y: -8)
                    }
                }
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundColor(.white.opacity(0.72))
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.09)))
        }
        .buttonStyle(.plain)
    }

    private var secondaryHeader: some View {
        HStack(spacing: 12) {
            Button { section = .discover } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(JourneyVisual.lime)
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.055))
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("SWEEZY NETWORK")
                    .font(.system(size: 9, weight: .black, design: .default))
                    .tracking(2)
                    .foregroundColor(JourneyVisual.lime)
                Text(section.rawValue)
                    .font(.system(size: 28, weight: .black, design: .default))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private var sectionSwitcher: some View {
        HStack(spacing: 5) {
            ForEach(NetworkSection.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { section = item }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item.icon)
                        Text(item.rawValue)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(section == item ? .black : .white.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(section == item ? JourneyVisual.lime : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12)))
        .padding(.horizontal, 18)
    }

    private var discoveryFiltersSheet: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.black.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Знайди точний збіг")
                            .font(.system(size: 28, weight: .black, design: .default))
                            .foregroundColor(.white)

                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(JourneyVisual.lime)
                            TextField("Ім’я, сфера або навичка", text: $vm.searchText)
                                .foregroundColor(.white)
                                .textInputAutocapitalization(.never)
                                .submitLabel(.search)
                        }
                        .padding(.horizontal, 15)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.12)))

                        Text("ЦІЛЬ ЗНАЙОМСТВА")
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.5)
                            .foregroundColor(JourneyVisual.lime)
                        FlowLayout(spacing: 8) {
                            filterChip("Усі цілі", active: vm.selectedGoal == nil) { vm.selectedGoal = nil }
                            ForEach(ProfessionalGoal.allCases) { goal in
                                filterChip(goal.title, icon: goal.icon, active: vm.selectedGoal == goal) {
                                    vm.selectedGoal = goal
                                }
                            }
                        }

                        networkPicker(title: "Кантон", value: vm.selectedCanton ?? "Уся Швейцарія") {
                            Picker("Кантон", selection: Binding(get: { vm.selectedCanton ?? "" }, set: { vm.selectedCanton = $0.isEmpty ? nil : $0 })) {
                                Text("Уся Швейцарія").tag("")
                                ForEach(SwissCanton.all.dropFirst(), id: \.code) { Text("\($0.code) — \($0.name)").tag($0.code) }
                            }
                        }

                        networkPicker(title: "Роль", value: vm.selectedRole?.title ?? "Усі ролі") {
                            Picker("Роль", selection: Binding(get: { vm.selectedRole }, set: { vm.selectedRole = $0 })) {
                                Text("Усі ролі").tag(Optional<ProfessionalRole>.none)
                                ForEach(ProfessionalRole.allCases) { Text($0.title).tag(Optional($0)) }
                            }
                        }

                        Button {
                            showFilters = false
                            showMoreMatches = false
                            Task { await vm.reloadProfiles() }
                        } label: {
                            Text("Показати збіги")
                                .font(.system(size: 17, weight: .black, design: .default))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(JourneyVisual.lime)
                                .clipShape(RoundedRectangle(cornerRadius: 17))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") { showFilters = false }
                        .foregroundColor(JourneyVisual.lime)
                }
            }
        }
    }

    private var cantonConstellation: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.12, blue: 0.12), Color(red: 0.055, green: 0.065, blue: 0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Canvas { context, size in
                let points = [
                    CGPoint(x: size.width * 0.13, y: size.height * 0.7),
                    CGPoint(x: size.width * 0.36, y: size.height * 0.32),
                    CGPoint(x: size.width * 0.62, y: size.height * 0.58),
                    CGPoint(x: size.width * 0.86, y: size.height * 0.25)
                ]
                var path = Path()
                path.move(to: points[0])
                points.dropFirst().forEach { path.addLine(to: $0) }
                context.stroke(path, with: .linearGradient(
                    Gradient(colors: [JourneyVisual.lime.opacity(0.2), JourneyVisual.lime]),
                    startPoint: points[0], endPoint: points[3]
                ), lineWidth: 2)
                for point in points {
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(JourneyVisual.lime))
                }
            }
            .padding(.horizontal, 8)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ТВІЙ КРУГ У ШВЕЙЦАРІЇ")
                        .font(.system(size: 10, weight: .black, design: .default))
                        .tracking(1.5)
                        .foregroundColor(JourneyVisual.lime)
                    Text("\(vm.profiles.count) нових контактів")
                        .font(.system(size: 21, weight: .bold, design: .default))
                        .foregroundColor(.white)
                    Text(vm.selectedCanton.map { "Фокус: кантон \($0)" } ?? "Від Zürich до Genève")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.54))
                }
                Spacer()
                VStack(spacing: 4) {
                    Text("ZH  ·  BS  ·  GE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.56))
                    Text("CH")
                        .font(.system(size: 18, weight: .black, design: .default))
                        .foregroundColor(.black)
                        .frame(width: 46, height: 46)
                        .background(JourneyVisual.lime)
                        .clipShape(Circle())
                }
            }
            .padding(18)
        }
        .frame(height: 138)
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(JourneyVisual.lime.opacity(0.34)))
    }

    private var friendsBridge: some View {
        Button { showFriends = true } label: {
            HStack(spacing: 15) {
                ZStack {
                    Circle().fill(Color(red: 1, green: 0.42, blue: 0.34))
                    Image(systemName: "person.2.wave.2.fill").font(.system(size: 22, weight: .bold)).foregroundColor(.black)
                }.frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text("SWEEZY FRIENDS").font(.system(size: 10, weight: .black, design: .default)).tracking(1.5).foregroundColor(Color(red: 1, green: 0.42, blue: 0.34))
                    Text("Знайди друзів за інтересами").font(.system(size: 17, weight: .bold, design: .default)).foregroundColor(.white)
                    Text("Події, хобі та люди поруч").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
            }
            .padding(16).background(LinearGradient(colors:[Color(red:0.12,green:0.055,blue:0.08),Color.white.opacity(0.055)],startPoint:.leading,endPoint:.trailing))
            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius:23).stroke(Color(red:1,green:0.42,blue:0.34).opacity(0.34)))
        }.buttonStyle(.plain)
    }

    private var searchAndFilters: some View {
        VStack(spacing: 11) {
            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(JourneyVisual.lime)
                TextField("Ім’я, сфера або навичка", text: $vm.searchText)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { Task { await vm.reloadProfiles() } }
                Button {
                    showFilters.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(showFilters ? .black : .white)
                        .frame(width: 39, height: 39)
                        .background(showFilters ? JourneyVisual.lime : Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 58)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.white.opacity(0.12)))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("Усі цілі", active: vm.selectedGoal == nil) { vm.selectedGoal = nil }
                    ForEach(ProfessionalGoal.allCases) { goal in
                        filterChip(goal.title, icon: goal.icon, active: vm.selectedGoal == goal) {
                            vm.selectedGoal = vm.selectedGoal == goal ? nil : goal
                        }
                    }
                }
            }
            .scrollClipDisabled()

            if showFilters {
                VStack(spacing: 10) {
                    networkPicker(title: "Кантон", value: vm.selectedCanton ?? "Уся Швейцарія") {
                        Picker("Кантон", selection: Binding(get: { vm.selectedCanton ?? "" }, set: { vm.selectedCanton = $0.isEmpty ? nil : $0 })) {
                            Text("Уся Швейцарія").tag("")
                            ForEach(SwissCanton.all.dropFirst(), id: \.code) { Text("\($0.code) — \($0.name)").tag($0.code) }
                        }
                    }
                    networkPicker(title: "Роль", value: vm.selectedRole?.title ?? "Усі ролі") {
                        Picker("Роль", selection: Binding(get: { vm.selectedRole }, set: { vm.selectedRole = $0 })) {
                            Text("Усі ролі").tag(Optional<ProfessionalRole>.none)
                            ForEach(ProfessionalRole.allCases) { Text($0.title).tag(Optional($0)) }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: vm.selectedGoal) { _, _ in Task { await vm.reloadProfiles() } }
        .onChange(of: vm.selectedCanton) { _, _ in Task { await vm.reloadProfiles() } }
        .onChange(of: vm.selectedRole) { _, _ in Task { await vm.reloadProfiles() } }
    }

    private func filterChip(_ title: String, icon: String? = nil, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(active ? .black : .white.opacity(0.7))
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(active ? JourneyVisual.lime : Color.white.opacity(0.065))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(active ? Color.clear : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private func networkPicker<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(.system(size: 8, weight: .black)).tracking(1).foregroundColor(.white.opacity(0.4))
                Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            }
            Spacer()
            content().labelsHidden().tint(JourneyVisual.lime)
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var networkingEvents: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Знайомся наживо", systemImage: "calendar.badge.plus")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(.white)
                Spacer()
                Text("ПОДІЇ").font(.system(size: 9, weight: .black)).tracking(1.2).foregroundColor(JourneyVisual.lime)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.events) { event in
                        Button { selectedEvent = event } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(event.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                Spacer()
                                HStack {
                                    Text(event.canton)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(JourneyVisual.lime)
                            }
                            .padding(13)
                            .frame(width: 175, height: 105, alignment: .leading)
                            .background(Color(red: 0.07, green: 0.11, blue: 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            connectionGroup(title: "Нові запити", subtitle: "Лише ти вирішуєш, хто може написати", items: vm.incoming, kind: .incoming)
            connectionGroup(title: "Мої контакти", subtitle: "Прийняті знайомства та активні чати", items: vm.accepted, kind: .accepted)
            connectionGroup(title: "Надіслані", subtitle: "Очікують відповіді", items: vm.outgoing, kind: .outgoing)
        }
        .padding(.horizontal, 18)
    }

    fileprivate enum ConnectionGroupKind { case incoming, accepted, outgoing }

    private func connectionGroup(title: String, subtitle: String, items: [ProfessionalConnection], kind: ConnectionGroupKind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 22, weight: .bold, design: .default)).foregroundColor(.white)
            Text(subtitle).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.48))
            if items.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: kind == .incoming ? "person.crop.circle.badge.checkmark" : "circle.dotted")
                        .foregroundColor(JourneyVisual.lime)
                    Text(kind == .incoming ? "Нових запитів поки немає" : "Тут з’являться професійні контакти")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.58))
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                ForEach(items) { connection in
                    NetworkConnectionRow(connection: connection, kind: kind) {
                        selectedProfile = connection.otherProfile
                    } accept: {
                        Task {
                            if let updated = await vm.respond(connection, accept: true) { await openChat(updated) }
                        }
                    } decline: {
                        Task { _ = await vm.respond(connection, accept: false) }
                    } openChat: {
                        Task { await openChat(connection) }
                    } cancel: {
                        Task { await vm.cancel(connection) }
                    }
                }
            }
        }
    }

    private var myProfileSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let profile = vm.myProfile {
                moderationBanner(profile)
                NetworkProfileCard(profile: profile, expanded: true)
                Button { showEditor = true } label: {
                    Label("Редагувати професійний профіль", systemImage: "pencil.line")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(JourneyVisual.lime)
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                }
                profileQuality(profile)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 34, weight: .bold)).foregroundColor(JourneyVisual.lime)
                    Text("Відкрий себе для сильних знайомств")
                        .font(.system(size: 26, weight: .bold, design: .default)).foregroundColor(.white)
                    Text("Розкажи, чим займаєшся, кого шукаєш і в якому кантоні працюєш. Контакти залишаються приватними.")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.58))
                    Button { showEditor = true } label: {
                        Text("Створити профіль").font(.system(size: 16, weight: .bold)).foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 54).background(JourneyVisual.lime)
                            .clipShape(RoundedRectangle(cornerRadius: 17))
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(JourneyVisual.lime.opacity(0.35)))
            }
        }
        .padding(.horizontal, 18)
    }

    private func moderationBanner(_ profile: ProfessionalProfile) -> some View {
        let status = profile.moderationStatus ?? "approved"
        let pending = status == "pending"
        let rejected = status == "rejected"
        return HStack(alignment: .top, spacing: 11) {
            Image(systemName: pending ? "clock.badge.checkmark" : rejected ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
            VStack(alignment: .leading, spacing: 3) {
                Text(pending ? "Профіль на перевірці" : rejected ? "Профіль потребує змін" : "Профіль схвалено").font(.system(size: 14, weight: .bold))
                Text(rejected ? (profile.moderationReason ?? "Відредагуй профіль і надішли повторно.") : pending ? "Після схвалення профіль з’явиться у професійному каталозі." : "Профіль видимий іншим користувачам.").font(.system(size: 12, weight: .medium))
            }
            Spacer()
        }
        .foregroundColor(rejected ? .orange : JourneyVisual.lime)
        .padding(14).background((rejected ? Color.orange : JourneyVisual.lime).opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var verifiedExpertsBridge: some View {
        Button { showVerifiedExperts = true } label: {
            HStack(spacing: 13) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 46, height: 46)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Потрібна професійна консультація?")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text("Перевірені експерти Sweezy")
                        .font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.42))
            }
            .padding(13)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.09)))
        }
        .buttonStyle(.plain)
    }

    private func profileQuality(_ profile: ProfessionalProfile) -> some View {
        let score = min(100, 45 + min(profile.skills.count, 5) * 5 + min(profile.goals.count, 3) * 5 + (profile.bio.count > 120 ? 15 : 0))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Сила профілю").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("\(score)%").font(.system(size: 15, weight: .black)).foregroundColor(JourneyVisual.lime)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(JourneyVisual.lime).frame(width: proxy.size.width * CGFloat(score) / 100)
                }
            }.frame(height: 8)
            Text("Додай конкретні навички та цілі — так рекомендації стануть точнішими.")
                .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.5))
        }
        .padding(17).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var networkSkeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.06)).frame(height: 190)
            }
        }.redacted(reason: .placeholder)
    }

    private var emptyDiscover: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.sequence.fill").font(.system(size: 34)).foregroundColor(JourneyVisual.lime)
            Text("Зміни фільтри або стань першим контактом у цьому кантоні")
                .font(.system(size: 16, weight: .bold)).multilineTextAlignment(.center).foregroundColor(.white)
            Button("Скинути фільтри") {
                vm.selectedCanton = nil; vm.selectedRole = nil; vm.selectedGoal = nil; vm.searchText = ""
                Task { await vm.reloadProfiles() }
            }.foregroundColor(JourneyVisual.lime)
        }
        .frame(maxWidth: .infinity).padding(30)
        .background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var accessGate: some View {
        GeometryReader { proxy in
            ZStack {
                Image("journey-market-consultant")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                Color.black.opacity(0.66).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.black.opacity(0.34))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18)))
                    }
                    Spacer(minLength: 24)
                    Text("SWISS NETWORK")
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundColor(JourneyVisual.lime)
                    Text("Люди, які можуть змінити твій шлях")
                        .font(.system(size: min(38, max(31, proxy.size.width * 0.095)), weight: .black, design: .default))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.82)
                        .layoutPriority(1)
                    Text("Увійди, створи професійний профіль і знайомся без публікації особистих контактів.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                    Button { showAuth = true } label: {
                        Text("Увійти та продовжити")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(JourneyVisual.lime)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
                .frame(
                    width: max(0, proxy.size.width - 40),
                    height: max(0, proxy.size.height - 24),
                    alignment: .leading
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func openChat(_ connection: ProfessionalConnection) async {
        guard let id = connection.conversationID else { return }
        do { selectedConversation = try await ChatAPI.conversation(id: id) }
        catch { vm.errorMessage = error.localizedDescription }
    }

    private var isUITestPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["UITESTS"] == "1" && ProcessInfo.processInfo.arguments.contains("--ui-test-network")
        #else
        false
        #endif
    }

    private func loadPreviewData() {
        vm.profiles = ProfessionalProfile.previewProfiles
        vm.myProfile = ProfessionalProfile.previewOwn
        vm.events = []
        vm.isShowingDemoProfiles = true
    }
}

private struct NetworkSVGIcon: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct NetworkSpotlightPhoto: View {
    let profile: ProfessionalProfile
    let isDemo: Bool

    var body: some View {
        Group {
            if isDemo, let previewAsset {
                Image(previewAsset)
                    .resizable()
                    .scaledToFill()
            } else if let raw = profile.avatarURL,
                      let url = APIClient.resolveMediaURL(raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        ZStack {
                            fallback
                            ProgressView().tint(JourneyVisual.lime)
                        }
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .accessibilityHidden(true)
    }

    private var previewAsset: String? {
        switch profile.userID {
        case "1": return "friend-preview-dmytro"
        case "2": return "friend-preview-anna"
        case "3": return "friend-preview-dmytro"
        default: return nil
        }
    }

    private var fallback: some View {
        ZStack {
            Image("journey-market-consultant")
                .resizable()
                .scaledToFill()
                .blur(radius: 1.5)
            Color.black.opacity(0.36)
            Text(profile.initials)
                .font(.system(size: 76, weight: .black, design: .default))
                .foregroundColor(JourneyVisual.lime)
        }
    }
}

private struct NetworkProfileCard: View {
    let profile: ProfessionalProfile
    var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                NetworkAvatar(profile: profile, size: expanded ? 72 : 60)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(profile.displayName).font(.system(size: expanded ? 21 : 18, weight: .bold, design: .default)).foregroundColor(.white)
                        if profile.isVerified { Image(systemName: "checkmark.seal.fill").foregroundColor(JourneyVisual.lime) }
                    }
                    Text(profile.headline).font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.64)).lineLimit(2)
                    Label("\(profile.city) · \(profile.canton)", systemImage: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(JourneyVisual.lime)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .black)).foregroundColor(.white.opacity(0.42))
            }

            Text(profile.bio).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.66)).lineLimit(expanded ? 5 : 3)

            HStack(spacing: 7) {
                NetworkTag(text: profile.role.title, icon: profile.role.icon, accent: true)
                ForEach(profile.goals.prefix(2)) { NetworkTag(text: $0.title, icon: $0.icon) }
            }

            HStack {
                Text(profile.industry.uppercased()).font(.system(size: 9, weight: .black)).tracking(1.1).foregroundColor(.white.opacity(0.42))
                Spacer()
                connectionBadge
            }
        }
        .padding(17)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.085), Color.white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(profile.isFeatured ? JourneyVisual.lime.opacity(0.6) : Color.white.opacity(0.1)))
    }

    @ViewBuilder private var connectionBadge: some View {
        Group {
            switch profile.connectionState {
            case "accepted": Label("Контакт", systemImage: "checkmark").foregroundColor(JourneyVisual.lime)
            case "outgoing": Label("Надіслано", systemImage: "clock").foregroundColor(.white.opacity(0.5))
            case "incoming": Label("Новий запит", systemImage: "person.badge.plus").foregroundColor(JourneyVisual.lime)
            default: Label("Познайомитись", systemImage: "plus").foregroundColor(.white.opacity(0.66))
            }
        }
        .font(.system(size: 10, weight: .bold))
    }
}

private struct NetworkAvatar: View {
    let profile: ProfessionalProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let raw = profile.avatarURL, let url = URL(string: raw) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { fallback }
            } else { fallback }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.32).stroke(JourneyVisual.lime.opacity(0.45)))
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(colors: [JourneyVisual.lime, Color(red: 0.16, green: 0.72, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(profile.initials).font(.system(size: size * 0.3, weight: .black, design: .default)).foregroundColor(.black)
        }
    }
}

private struct NetworkTag: View {
    let text: String
    let icon: String
    var accent = false
    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(accent ? .black : .white.opacity(0.65))
            .padding(.horizontal, 9).frame(height: 28)
            .background(accent ? JourneyVisual.lime : Color.white.opacity(0.07))
            .clipShape(Capsule())
            .lineLimit(1)
    }
}

private struct NetworkConnectionRow: View {
    let connection: ProfessionalConnection
    let kind: ProfessionalNetworkView.ConnectionGroupKind
    let openProfile: () -> Void
    let accept: () -> Void
    let decline: () -> Void
    let openChat: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: openProfile) {
                HStack(spacing: 12) {
                    NetworkAvatar(profile: connection.otherProfile, size: 50)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(connection.otherProfile.displayName).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        Text(connection.otherProfile.headline).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.55)).lineLimit(1)
                    }
                    Spacer()
                    Text(connection.otherProfile.canton).font(.system(size: 10, weight: .black)).foregroundColor(JourneyVisual.lime)
                }
            }.buttonStyle(.plain)
            if let message = connection.message, !message.isEmpty {
                Text("“\(message)”").font(.system(size: 12, weight: .medium)).italic().foregroundColor(.white.opacity(0.58)).lineLimit(3)
            }
            HStack(spacing: 9) {
                switch kind {
                case .incoming:
                    actionButton("Прийняти", icon: "checkmark", primary: true, action: accept)
                    actionButton("Відхилити", icon: "xmark", action: decline)
                case .accepted:
                    actionButton("Відкрити чат", icon: "bubble.left.and.bubble.right.fill", primary: true, action: openChat)
                case .outgoing:
                    actionButton("Скасувати запит", icon: "xmark", action: cancel)
                }
            }
        }
        .padding(15).background(Color.white.opacity(0.055)).clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.09)))
    }

    private func actionButton(_ title: String, icon: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .bold))
                .foregroundColor(primary ? .black : .white.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(primary ? JourneyVisual.lime : Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain)
    }
}

private struct NetworkProfileDetailView: View {
    let profile: ProfessionalProfile
    @ObservedObject var vm: ProfessionalNetworkViewModel
    @Binding var selectedConversation: ChatConversation?
    let isDemo: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @State private var showConnect = false
    @State private var working = false
    @State private var showSafety = false

    var current: ProfessionalProfile { vm.profiles.first(where: { $0.id == profile.id }) ?? profile }

    var body: some View {
        ZStack(alignment: .top) {
            JourneyVisual.black.ignoresSafeArea()
            LinearGradient(colors: [Color(red: 0.04, green: 0.15, blue: 0.14), .black], startPoint: .top, endPoint: .center).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button { dismiss() } label: { Image(systemName: "xmark").font(.title3.bold()).foregroundColor(.white).frame(width: 46, height: 46).background(Color.white.opacity(0.08)).clipShape(Circle()) }
                        Spacer()
                        if !isDemo {
                            Button { showSafety = true } label: { Image(systemName: "ellipsis").foregroundColor(.white).frame(width: 46, height: 46).background(Color.white.opacity(0.08)).clipShape(Circle()) }
                        }
                    }
                    .padding(.top, 8)

                    HStack(alignment: .bottom, spacing: 17) {
                        NetworkAvatar(profile: current, size: 92)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(current.displayName).font(.system(size: 29, weight: .black, design: .default)).foregroundColor(.white); if current.isVerified { Image(systemName: "checkmark.seal.fill").foregroundColor(JourneyVisual.lime) } }
                            Text(current.headline).font(.system(size: 15, weight: .semibold)).foregroundColor(.white.opacity(0.64))
                            Label("\(current.city) · \(current.canton)", systemImage: "mappin.and.ellipse").font(.system(size: 12, weight: .bold)).foregroundColor(JourneyVisual.lime)
                        }
                    }

                    if let company = current.companyName, !company.isEmpty {
                        Label(company, systemImage: "building.2.fill").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }

                    actionArea

                    detailBlock(title: "Про мене", text: current.bio)
                    tagsBlock(title: "Шукаю", goals: current.goals)
                    skillsBlock

                    Text("Контакти залишаються приватними. Чат відкриється лише після взаємного підтвердження.")
                        .font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.4)).padding(.bottom, 20)
                }.padding(20)
            }
        }
        .sheet(isPresented: $showConnect) { NetworkConnectSheet(profile: current, vm: vm) }
        .confirmationDialog("Безпека", isPresented: $showSafety) {
            Button("Поскаржитися", role: .destructive) { Task { try? await NetworkAPI.report(userID: current.userID, reason: "other", details: nil) } }
            Button("Заблокувати", role: .destructive) { Task { if await vm.block(current) { dismiss() } } }
            Button("Скасувати", role: .cancel) {}
        }
    }

    @ViewBuilder private var actionArea: some View {
        if isDemo {
            Label("Демо-профіль · дії вимкнені", systemImage: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(JourneyVisual.lime)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(JourneyVisual.lime.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 17))
        } else {
            switch current.connectionState {
            case "accepted":
                primaryButton("Відкрити чат", icon: "bubble.left.and.bubble.right.fill") { Task { await openChat() } }
            case "incoming":
                HStack(spacing: 10) {
                    primaryButton("Прийняти", icon: "checkmark") { Task { await respond(true) } }
                    secondaryButton("Відхилити", icon: "xmark") { Task { await respond(false) } }
                }
            case "outgoing":
                secondaryButton("Запит надіслано", icon: "clock") {}
            default:
                primaryButton("Запропонувати знайомство", icon: "person.badge.plus") { showConnect = true }
            }
        }
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.system(size: 15, weight: .bold)).foregroundColor(.black).frame(maxWidth: .infinity, minHeight: 54).background(JourneyVisual.lime).clipShape(RoundedRectangle(cornerRadius: 17)) }.buttonStyle(.plain)
    }
    private func secondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.system(size: 15, weight: .bold)).foregroundColor(.white.opacity(0.7)).frame(maxWidth: .infinity, minHeight: 54).background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 17)) }.buttonStyle(.plain)
    }
    private func detailBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 9) { Text(title).font(.system(size: 20, weight: .bold, design: .default)).foregroundColor(.white); Text(text).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.64)).lineSpacing(3) }
        .padding(17).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.055)).clipShape(RoundedRectangle(cornerRadius: 20))
    }
    private func tagsBlock(title: String, goals: [ProfessionalGoal]) -> some View {
        VStack(alignment: .leading, spacing: 11) { Text(title).font(.system(size: 20, weight: .bold, design: .default)).foregroundColor(.white); FlowLayout(spacing: 8) { ForEach(goals) { NetworkTag(text: $0.title, icon: $0.icon, accent: true) } } }
    }
    private var skillsBlock: some View {
        VStack(alignment: .leading, spacing: 11) { Text("Експертиза").font(.system(size: 20, weight: .bold, design: .default)).foregroundColor(.white); FlowLayout(spacing: 8) { ForEach(current.skills, id: \.self) { NetworkTag(text: $0, icon: "checkmark") } } }
    }
    private func respond(_ accept: Bool) async {
        guard let id = current.connectionID, let connection = vm.connections.first(where: { $0.id == id }) else { return }
        if let updated = await vm.respond(connection, accept: accept), accept { await openChat(updated) }
    }
    private func openChat(_ connection: ProfessionalConnection? = nil) async {
        guard let id = connection?.conversationID ?? current.conversationID else { return }
        do { selectedConversation = try await ChatAPI.conversation(id: id); dismiss() }
        catch { vm.errorMessage = error.localizedDescription }
    }
}

private struct NetworkConnectSheet: View {
    let profile: ProfessionalProfile
    @ObservedObject var vm: ProfessionalNetworkViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var sending = false

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 13) { NetworkAvatar(profile: profile, size: 58); VStack(alignment: .leading) { Text(profile.displayName).font(.headline).foregroundColor(.white); Text(profile.headline).font(.caption).foregroundColor(.white.opacity(0.55)) } }
                    Text("Навіщо хочеш познайомитись?").font(.system(size: 25, weight: .bold, design: .default)).foregroundColor(.white)
                    Text("Короткий контекст збільшує шанс відповіді. Не надсилай контакти або чутливі дані.").font(.subheadline).foregroundColor(.white.opacity(0.55))
                    TextEditor(text: $message).scrollContentBackground(.hidden).foregroundColor(.white).padding(12).frame(height: 160).background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1)))
                    Button { Task { await send() } } label: { HStack { if sending { ProgressView().tint(.black) }; Text("Надіслати запит"); Spacer(); Image(systemName: "arrow.right") }.font(.headline).foregroundColor(.black).padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 56).background(JourneyVisual.lime).clipShape(RoundedRectangle(cornerRadius: 18)) }.disabled(sending)
                    Spacer()
                }.padding(20)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() }.foregroundColor(.white) } }
        }
    }
    private func send() async { sending = true; defer { sending = false }; if await vm.connect(to: profile, message: message) { dismiss() } }
}

private struct NetworkProfileEditorView: View {
    let profile: ProfessionalProfile?
    @ObservedObject var vm: ProfessionalNetworkViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProfessionalProfileDraft
    @State private var skillsText: String
    @State private var languagesText: String

    init(profile: ProfessionalProfile?, vm: ProfessionalNetworkViewModel) {
        self.profile = profile
        self.vm = vm
        let value = profile.map { ProfessionalProfileDraft(profile: $0) } ?? ProfessionalProfileDraft()
        _draft = State(initialValue: value)
        _skillsText = State(initialValue: value.skills.joined(separator: ", "))
        _languagesText = State(initialValue: value.languages.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(profile == nil ? "Створи свій професійний образ" : "Онови професійний профіль")
                            .font(.system(size: 31, weight: .black, design: .default)).foregroundColor(.white)
                        Text("Це бачать люди в Swiss Network. Email і телефон не публікуються.").font(.subheadline).foregroundColor(.white.opacity(0.5))
                        editorField("Ім’я", text: $draft.displayName)
                        editorField("Професійний заголовок", text: $draft.headline)
                        editorField("Компанія", text: $draft.companyName)
                        rolePicker
                        editorField("Сфера", text: $draft.industry)
                        HStack(spacing: 10) { cantonPicker; editorField("Місто", text: $draft.city) }
                        editorTextArea
                        goalsPicker
                        editorField("Навички через кому", text: $skillsText)
                        editorField("Мови через кому", text: $languagesText)
                        Toggle("Відкритий до знайомств", isOn: $draft.openToConnections).tint(JourneyVisual.lime).foregroundColor(.white)
                        Toggle("Показувати у каталозі", isOn: $draft.isVisible).tint(JourneyVisual.lime).foregroundColor(.white)
                        Button { Task { await save() } } label: { HStack { if vm.isSaving { ProgressView().tint(.black) }; Text(profile == nil ? "Опублікувати профіль" : "Зберегти зміни"); Spacer(); Image(systemName: "checkmark") }.font(.headline).foregroundColor(.black).padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 58).background(canSave ? JourneyVisual.lime : JourneyVisual.lime.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 18)) }.disabled(!canSave || vm.isSaving)
                    }.padding(20).padding(.bottom, 30)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() }.foregroundColor(.white) } }
        }
    }

    private func editorField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title.uppercased()).font(.system(size: 9, weight: .black)).tracking(1.2).foregroundColor(JourneyVisual.lime); TextField(title, text: text).foregroundColor(.white).padding(.horizontal, 14).frame(height: 52).background(Color.white.opacity(0.065)).clipShape(RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1))) }
        .frame(maxWidth: .infinity)
    }
    private var editorTextArea: some View { VStack(alignment: .leading, spacing: 7) { Text("ПРО МЕНЕ").font(.system(size: 9, weight: .black)).tracking(1.2).foregroundColor(JourneyVisual.lime); TextEditor(text: $draft.bio).scrollContentBackground(.hidden).foregroundColor(.white).padding(10).frame(height: 150).background(Color.white.opacity(0.065)).clipShape(RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1))); Text("\(draft.bio.count)/800").font(.caption2).foregroundColor(.white.opacity(0.35)).frame(maxWidth: .infinity, alignment: .trailing) } }
    private var rolePicker: some View { VStack(alignment: .leading, spacing: 8) { Text("ТВОЯ РОЛЬ").font(.system(size: 9, weight: .black)).tracking(1.2).foregroundColor(JourneyVisual.lime); ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(ProfessionalRole.allCases) { role in Button { draft.role = role } label: { NetworkTag(text: role.title, icon: role.icon, accent: draft.role == role) }.buttonStyle(.plain) } } } } }
    private var goalsPicker: some View { VStack(alignment: .leading, spacing: 8) { Text("КОГО АБО ЩО ШУКАЄШ").font(.system(size: 9, weight: .black)).tracking(1.2).foregroundColor(JourneyVisual.lime); FlowLayout(spacing: 8) { ForEach(ProfessionalGoal.allCases) { goal in Button { if draft.goals.contains(goal) { draft.goals.removeAll { $0 == goal } } else if draft.goals.count < 5 { draft.goals.append(goal) } } label: { NetworkTag(text: goal.title, icon: goal.icon, accent: draft.goals.contains(goal)) }.buttonStyle(.plain) } } } }
    private var cantonPicker: some View { VStack(alignment: .leading, spacing: 7) { Text("КАНТОН").font(.system(size: 9, weight: .black)).tracking(1.2).foregroundColor(JourneyVisual.lime); Picker("Кантон", selection: $draft.canton) { ForEach(SwissCanton.all.dropFirst(), id: \.code) { Text($0.code).tag($0.code) } }.tint(.white).padding(.horizontal, 10).frame(height: 52).background(Color.white.opacity(0.065)).clipShape(RoundedRectangle(cornerRadius: 15)) }.frame(width: 105) }
    private var canSave: Bool { draft.displayName.trimmingCharacters(in: .whitespaces).count >= 2 && draft.headline.count >= 3 && draft.industry.count >= 2 && draft.city.count >= 2 && draft.bio.count >= 30 && !draft.goals.isEmpty && !languagesText.trimmingCharacters(in: .whitespaces).isEmpty }
    private func save() async { draft.skills = split(skillsText); draft.languages = split(languagesText).map { $0.uppercased() }; if await vm.save(draft) { dismiss() } }
    private func split(_ value: String) -> [String] { value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
}

private extension ProfessionalProfile {
    func withConnection(state: String, id: String?, conversationID: String?) -> ProfessionalProfile {
        ProfessionalProfile(userID: userID, displayName: displayName, headline: headline, companyName: companyName, role: role, industry: industry, canton: canton, city: city, bio: bio, skills: skills, languages: languages, goals: goals, avatarURL: avatarURL, websiteURL: websiteURL, isVisible: isVisible, isVerified: isVerified, isFeatured: isFeatured, openToConnections: openToConnections, connectionState: state, connectionID: id, conversationID: conversationID, createdAt: createdAt, updatedAt: updatedAt)
    }

    static var previewOwn: ProfessionalProfile {
        ProfessionalProfile(userID: "me", displayName: "Anna Kovalenko", headline: "Product Designer · Zürich", companyName: "Sweezy", role: .specialist, industry: "Digital products", canton: "ZH", city: "Zürich", bio: "Створюю зрозумілі цифрові продукти для міжнародних команд у Швейцарії.", skills: ["Product Design", "Figma", "Research"], languages: ["UK", "DE", "EN"], goals: [.partners, .events], avatarURL: nil, websiteURL: nil, isVisible: true, isVerified: true, isFeatured: false, openToConnections: true, connectionState: "none", connectionID: nil, conversationID: nil, createdAt: Date(), updatedAt: Date())
    }

    static var previewProfiles: [ProfessionalProfile] {
        [
            ProfessionalProfile(userID: "1", displayName: "Oleksandr Melnyk", headline: "Founder · FinTech & AI", companyName: "Alpine Labs", role: .founder, industry: "FinTech", canton: "ZH", city: "Zürich", bio: "Будую фінансові продукти для малого бізнесу. Шукаю партнерів для виходу на DACH-ринок.", skills: ["FinTech", "AI", "Go-to-market"], languages: ["UK", "DE", "EN"], goals: [.partners, .investing], avatarURL: nil, websiteURL: nil, isVisible: true, isVerified: true, isFeatured: true, openToConnections: true, connectionState: "none", connectionID: nil, conversationID: nil, createdAt: Date(), updatedAt: Date()),
            ProfessionalProfile(userID: "2", displayName: "Marta Keller", headline: "Brand Strategist", companyName: "North Studio", role: .freelancer, industry: "Creative", canton: "BS", city: "Basel", bio: "Допомагаю новим брендам знайти голос і сильну позицію на швейцарському ринку.", skills: ["Brand", "Strategy", "Content"], languages: ["DE", "EN", "UK"], goals: [.clients, .cofounder], avatarURL: nil, websiteURL: nil, isVisible: true, isVerified: true, isFeatured: false, openToConnections: true, connectionState: "incoming", connectionID: "c2", conversationID: nil, createdAt: Date(), updatedAt: Date()),
            ProfessionalProfile(userID: "3", displayName: "Danylo Huber", headline: "Angel Investor · ClimateTech", companyName: nil, role: .investor, industry: "ClimateTech", canton: "GE", city: "Genève", bio: "Інвестую у ранні команди, що вирішують практичні проблеми сталого розвитку.", skills: ["Venture", "Climate", "Fundraising"], languages: ["FR", "EN"], goals: [.investing, .mentoring], avatarURL: nil, websiteURL: nil, isVisible: true, isVerified: false, isFeatured: false, openToConnections: true, connectionState: "none", connectionID: nil, conversationID: nil, createdAt: Date(), updatedAt: Date())
        ]
    }
}
