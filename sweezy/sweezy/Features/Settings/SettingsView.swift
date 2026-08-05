//
//  SettingsView.swift
//  sweezy
//

import SwiftUI
import StoreKit
import UniformTypeIdentifiers
import Combine
import CryptoKit

struct SettingsView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showingLanguageSelection = false
    @State private var showingProfileEdit = false
    @State private var showingNotificationSettings = false
    @State private var showingChatInbox = false
    
    @State private var regName: String = ""
    @State private var regEmail: String = ""
    @State private var regPassword: String = ""
    @State private var showingRegistration = false
    @State private var showingLogin = false
    @State private var showingAuthEntry = false
    @State private var showingPrivacy = false
    @State private var showingAbout = false
    @State private var showingDataManagement = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var deleteAccountError: String? = nil
    @State private var biometricsMessage: String? = nil
    @State private var exportDocument = SweezyBackupDocument(data: Data())
    @State private var analyticsEnabled = AnalyticsConsentStore.isGranted
    
    // Lightweight live gamification mirrors
    @State private var liveXP: Int = 0
    @State private var liveLastAward: Int = 0
    @State private var liveTodayXP: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.025, green: 0.03, blue: 0.028)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        editorialSettingsHero
                        editorialProfileCard
                        editorialCompletionCard
                        editorialActivityStrip
                        editorialSettingsSections
                    }
                    .padding(.bottom, 126)
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
            .featureOnboarding(.settings)
        }
        .accessibilityIdentifier("settings.screen")
        .onAppear {
            AppLogger.ui("SettingsView onAppear")
            lockManager.loadBiometryType()
            // Seed live gamification state
            liveXP = appContainer.gamification.totalXP
            liveLastAward = appContainer.gamification.lastAwardedXP
            liveTodayXP = appContainer.gamification.xpGainedToday()
        }
        // Lightweight listeners (two small subjects, update only this card)
        .onReceive(appContainer.gamification.$totalXP) { value in
            liveXP = value
            liveTodayXP = appContainer.gamification.xpGainedToday()
        }
        .onReceive(appContainer.gamification.$lastAwardedXP) { value in
            liveLastAward = value
            liveTodayXP = appContainer.gamification.xpGainedToday()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
        }
        // Removed heavy .id(refreshKey) and .onReceive that caused constant redraws
        .sheet(isPresented: $showingPrivacy) {
            PrivacyPolicyView()
        }
        // Export JSON file
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .json, defaultFilename: defaultBackupFilename) { _ in }
        // Import JSON file
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importBackup(from: url)
            case .failure:
                break
            }
        }
        // Delete confirmation
        .alert("settings.delete_all_data".localized, isPresented: $showingDeleteAlert) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("common.delete".localized, role: .destructive) {
                Task { await deleteAllData() }
            }
        } message: {
            Text("Are you sure you want to remove cached content and local profile? This cannot be undone.")
        }
        .alert("settings.delete_account".localized, isPresented: $showingDeleteAccountAlert) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("common.delete".localized, role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("settings.delete_account.confirm_message".localized)
        }
        .alert("errors.title".localized, isPresented: Binding(
            get: { deleteAccountError != nil },
            set: { newValue in if !newValue { deleteAccountError = nil } }
        )) {
            Button("common.ok".localized) { deleteAccountError = nil }
        } message: {
            Text(deleteAccountError ?? "")
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionSheet()
                .environmentObject(appContainer)
        }
        .sheet(isPresented: $showingProfileEdit) {
            ProfileEditView()
                .environmentObject(appContainer)
        }
        .sheet(isPresented: $showingRegistration) {
            RegistrationView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
        }
        .sheet(isPresented: $showingAuthEntry) {
            AuthEntryView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NavigationStack {
                NotificationSettingsView()
            }
        }
        .sheet(isPresented: $showingChatInbox) {
            ChatInboxView()
                .environmentObject(appContainer)
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
        }
        .sheet(isPresented: $showingDataManagement) {
            NavigationStack {
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: Theme.Spacing.lg) {
                            // Single top-level title stays in navigation bar,
                            // starts directly with the account block
                            SectionHeader("settings.account".localized)
                            accountBlock
                            
                            settingsRow(
                                icon: "square.and.arrow.up",
                                title: "settings.export_data".localized
                            ) {
                                prepareExport()
                            }
                            
                            settingsRow(
                                icon: "square.and.arrow.down",
                                title: "settings.import_data".localized
                            ) {
                                showingImporter = true
                            }
                            
                            settingsRow(
                                icon: "trash",
                                title: "settings.delete_all_data".localized,
                                tinted: .red
                            ) {
                                showingDeleteAlert = true
                            }
                            
                            if lockManager.isRegistered {
                                settingsRow(
                                    icon: "person.fill.xmark",
                                    title: "settings.delete_account".localized,
                                    tinted: .red
                                ) {
                                    showingDeleteAccountAlert = true
                                }
                            }
                        }
                        .padding(Theme.Spacing.lg)
                    }
                }
                .navigationTitle("settings.data_management".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("common.close".localized) { showingDataManagement = false }
                    }
                }
            }
        }
    }
}

// MARK: - Sections

private extension SettingsView {
    var editorialSettingsHero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("cityhub-zurich-oldtown")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 252)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.3),
                    Color(red: 0.025, green: 0.03, blue: 0.028)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("settings.editorial.header".localized)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.68))

                Text("settings.editorial.greeting_format".localized(with: editorialGreetingName))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 5) {
                    Text("settings.editorial.profile_ready_label".localized)
                        .foregroundColor(.white.opacity(0.72))
                    Text("\(profileCompletion)%")
                        .fontWeight(.bold)
                        .foregroundColor(JourneyVisual.lime)
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .frame(height: 252)
        .accessibilityElement(children: .combine)
    }

    var editorialProfileCard: some View {
        Button {
            openProfile()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                    Circle()
                        .stroke(JourneyVisual.lime.opacity(0.7), lineWidth: 1)
                    Text(profileInitials)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profileName)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Label(editorialProfileLocation, systemImage: "mappin")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                }

                Spacer(minLength: 10)

                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(JourneyVisual.lime)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.32))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(JourneyVisual.lime.opacity(0.48), lineWidth: 1))
            }
            .padding(15)
            .editorialSettingsPanel(cornerRadius: 22)
        }
        .buttonStyle(CardPressStyle())
        .padding(.horizontal, 16)
        .accessibilityHint("settings.editorial.edit_profile_hint".localized)
    }

    var editorialCompletionCard: some View {
        Button {
            openProfile()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("settings.editorial.complete_profile_title".localized)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("settings.editorial.complete_profile_subtitle".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: CGFloat(profileCompletion) / 100)
                            .stroke(JourneyVisual.lime, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(profileCompletion)%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 58, height: 58)
                }

                HStack {
                    Text("settings.editorial.continue_filling".localized)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(16)
            .editorialSettingsPanel(cornerRadius: 22)
        }
        .buttonStyle(CardPressStyle())
        .padding(.horizontal, 16)
    }

    var editorialActivityStrip: some View {
        HStack(spacing: 0) {
            editorialActivityItem(icon: "book.closed", value: "\(appContainer.userStats.guidesReadCount)", label: "settings.editorial.stat.guides".localized)
            editorialActivityDivider
            editorialActivityItem(icon: "checklist", value: "\(appContainer.userStats.activeChecklistsCount)", label: "settings.editorial.stat.checklists".localized)
            editorialActivityDivider
            editorialActivityItem(icon: "target", value: "\(appContainer.userProfile?.goals.count ?? 0)", label: "settings.editorial.stat.goals".localized)
        }
        .padding(.vertical, 12)
        .editorialSettingsPanel(cornerRadius: 18)
        .padding(.horizontal, 16)
    }

    var editorialSettingsSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            editorialSectionTitle("settings.account".localized)
            VStack(spacing: 0) {
                editorialSettingsRow(icon: "globe", title: "settings.language".localized, value: currentLanguageName) {
                    showingLanguageSelection = true
                }
                editorialSettingsDivider
                Menu {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            withAnimation(Theme.Animation.smooth) {
                                themeManager.selectedTheme = theme
                            }
                        } label: {
                            Label(theme.localizedName, systemImage: themeManager.selectedTheme == theme ? "checkmark" : "circle")
                        }
                    }
                } label: {
                    editorialSettingsRowLabel(
                        icon: "moon.stars",
                        title: "settings.theme.title".localized,
                        value: themeManager.selectedTheme.localizedName
                    )
                }
                editorialSettingsDivider
                editorialSettingsRow(
                    icon: "bell",
                    title: "settings.notifications".localized,
                    accessibilityIdentifier: "settings.notifications.open"
                ) {
                    showingNotificationSettings = true
                }
                editorialSettingsDivider
                editorialSettingsRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "chat.inbox.title".localized,
                    value: appContainer.chatStore.unreadCount > 0
                        ? "\(min(appContainer.chatStore.unreadCount, 99))"
                        : nil
                ) {
                    if sessionManager.isAuthenticated {
                        showingChatInbox = true
                    } else {
                        showingAuthEntry = true
                    }
                }
                editorialSettingsDivider
                editorialSettingsRow(icon: "hand.raised", title: "privacy.title".localized) {
                    showingPrivacy = true
                }
            }
            .editorialSettingsPanel(cornerRadius: 20)

            editorialSectionTitle("settings.section.security_data".localized)
            VStack(spacing: 0) {
                editorialToggleRow(
                    icon: lockManager.biometryDisplayName == "Face ID" ? "faceid" : "touchid",
                    title: lockManager.biometryDisplayName,
                    subtitle: lockManager.isBiometryAvailable ? "settings.security.biometry_subtitle".localized : (lockManager.biometryUnavailableReason ?? "common.unavailable".localized),
                    isOn: Binding(
                        get: { lockManager.biometricsEnabled },
                        set: { newValue in
                            Task { @MainActor in
                                let ok = await lockManager.setBiometricsEnabled(newValue)
                                biometricsMessage = ok ? nil : (lockManager.biometryUnavailableReason ?? lockManager.lastAuthErrorDescription)
                            }
                        }
                    ),
                    isEnabled: lockManager.isBiometryAvailable
                )
                editorialSettingsDivider
                editorialToggleRow(
                    icon: "chart.bar.xaxis",
                    title: "settings.analytics.title".localized,
                    subtitle: "settings.analytics.subtitle".localized,
                    isOn: $analyticsEnabled
                )
                .onChange(of: analyticsEnabled) { _, enabled in
                    appContainer.analytics.setEnabled(enabled)
                }
                editorialSettingsDivider
                editorialSettingsRow(icon: "internaldrive", title: "settings.data_management".localized) {
                    showingDataManagement = true
                }
            }
            .editorialSettingsPanel(cornerRadius: 20)

            editorialSectionTitle("settings.section.support".localized)
            VStack(spacing: 0) {
                if let supportURL = supportEmailURL {
                    Link(destination: supportURL) {
                        editorialSettingsRowLabel(icon: "envelope", title: "settings.email_support".localized)
                    }
                    editorialSettingsDivider
                }
                editorialSettingsRow(icon: "star", title: "settings.rate_app".localized) {
                    requestAppReview()
                }
                editorialSettingsDivider
                editorialSettingsRow(icon: "info.circle", title: "settings.about".localized) {
                    showingAbout = true
                }
                editorialSettingsDivider
                editorialSettingsRow(
                    icon: "number",
                    title: "settings.version_label".localized,
                    value: Bundle.main.appVersion,
                    showsChevron: false
                ) {}
            }
            .editorialSettingsPanel(cornerRadius: 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    func openProfile() {
        if sessionManager.isAuthenticated {
            showingProfileEdit = true
        } else {
            showingAuthEntry = true
        }
    }

    var editorialGreetingName: String {
        profileName.split(separator: " ").first.map(String.init) ?? profileName
    }

    var editorialProfileLocation: String {
        guard let profile = appContainer.userProfile else { return "Zürich, ZH" }
        let city = profile.address?.city.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\((city?.isEmpty == false ? city : profile.canton.localizedName) ?? profile.canton.localizedName), \(profile.canton.rawValue)"
    }

    func editorialActivityItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(JourneyVisual.lime)
                Text(value)
                    .foregroundColor(.white)
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    var editorialActivityDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 34)
    }

    func editorialSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 2)
    }

    @ViewBuilder
    func editorialSettingsRow(
        icon: String,
        title: String,
        value: String? = nil,
        showsChevron: Bool = true,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let row = Button(action: action) {
            editorialSettingsRowLabel(icon: icon, title: title, value: value, showsChevron: showsChevron)
        }
        .buttonStyle(.plain)

        if let accessibilityIdentifier {
            row.accessibilityIdentifier(accessibilityIdentifier)
        } else {
            row
        }
    }

    func editorialSettingsRowLabel(
        icon: String,
        title: String,
        value: String? = nil,
        showsChevron: Bool = true
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.86))
                .frame(width: 22)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.54))
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.36))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    func editorialToggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isEnabled: Bool = true
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isEnabled ? .white.opacity(0.86) : .white.opacity(0.32))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isEnabled ? .white : .white.opacity(0.44))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(JourneyVisual.lime)
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
    }

    var editorialSettingsDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.09))
            .frame(height: 1)
            .padding(.leading, 51)
    }

    var settingsHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("settings.editorial.header".localized)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.62))

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: -2) {
                    Text("settings.editorial.greeting_format".localized(with: profileName))
                    Text("settings.hero.your_situation".localized)
                }
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundColor(.white)

                Spacer()

                Text("\(profileCompletion)%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(JourneyVisual.lime)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(JourneyVisual.lime)
                        .frame(width: geometry.size.width * CGFloat(profileCompletion) / 100)
                }
            }
            .frame(height: 7)
        }
        .padding(.top, 12)
        .shadow(color: .black.opacity(0.28), radius: 9, y: 4)
    }

    var profileCompletion: Int {
        guard let profile = appContainer.userProfile else { return 20 }
        var completed = 4
        if !profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { completed += 1 }
        if profile.arrivalDate != nil { completed += 1 }
        if !profile.goals.isEmpty { completed += 1 }
        if profile.address != nil { completed += 1 }
        if !(profile.phoneNumber?.isEmpty ?? true) { completed += 1 }
        if !(profile.email?.isEmpty ?? true) { completed += 1 }
        return min(100, completed * 10)
    }

    var gamificationPanel: some View {
        let baseXP = appContainer.gamification.totalXP
        let currentXPValue = (liveXP == 0 ? baseXP : liveXP)
        let level = computeLevel(for: currentXPValue)
        let nextTarget = xpTarget(for: level)
        let title = levelName(for: level)
        let hours = max(1, appContainer.userStats.guidesReadCount * 2 + appContainer.userStats.activeChecklistsCount)
        let today = (liveTodayXP == 0 ? appContainer.gamification.xpGainedToday() : liveTodayXP)
        let badges = computeBadges(guidesRead: appContainer.userStats.guidesReadCount, hoursSaved: hours)
        return GamificationLevelCard(
            currentXP: currentXPValue,
            xpForNextLevel: nextTarget,
            level: level,
            levelTitle: title,
            hoursSaved: hours,
            guidesRead: appContainer.userStats.guidesReadCount,
            lastAward: liveLastAward,
            todayXP: today,
            badges: badges
        )
    }
    func winterBenefitRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.primary)
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
    
    func benefitRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.gradientPrimaryAdaptive)
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
    
    var profileCard: some View {
        Button {
            if sessionManager.isAuthenticated {
                showingProfileEdit = true
            } else {
                showingAuthEntry = true
            }
        } label: {
            HStack(spacing: 16) {
                // Avatar with summer-green gradient ring
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.Colors.primaryLight.opacity(0.45), Color.clear],
                                center: .center,
                                startRadius: 25,
                                endRadius: 45
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Theme.Colors.primaryLight, Color.white.opacity(0.85), Theme.Colors.primary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 68, height: 68)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.primaryLight, Theme.Colors.primary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Text(profileInitials)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(profileName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    // Subtitle with icon
                    HStack(spacing: 6) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textTertiary)
                        Text(profileSubtitle)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                    // Quick stats row
                    if let profile = appContainer.userProfile, !profile.goals.isEmpty {
                        HStack(spacing: 12) {
                            WinterQuickStat(icon: "target", value: "\(profile.goals.count)", label: "settings.editorial.stat.goals".localized)
                            WinterQuickStat(icon: "calendar", value: daysInSwitzerlandText, label: "settings.stat.days".localized)
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                // Arrow with circle - winter styled
                ZStack {
                    Circle()
                        .fill(Theme.Colors.adaptiveSurface)
                        .frame(width: 36, height: 36)
                    Circle()
                        .stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 1)
                        .frame(width: 36, height: 36)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(16)
            .background(Theme.Colors.adaptiveCard)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.Colors.primary.opacity(0.35), Theme.Colors.adaptiveSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                Text("✨")
                    .font(.system(size: 14))
                    .opacity(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: -12, y: 8)
            )
        }
        .buttonStyle(CardPressStyle())
    }
    
    private var daysInSwitzerlandText: String {
        guard let arrival = appContainer.userProfile?.arrivalDate else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: arrival, to: Date()).day ?? 0
        return "\(max(0, days))"
    }
    
    private var winterThemePickerCard: some View {
        WinterSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings.theme.title".localized)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(themeManager.selectedTheme.localizedName)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Spacer()
                }
                
                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeSelectionButton(
                            theme: theme,
                            isSelected: themeManager.selectedTheme == theme
                        ) {
                            withAnimation(Theme.Animation.smooth) {
                                themeManager.selectedTheme = theme
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
            }
        }
    }
    
    func settingsRow(icon: String, title: String, value: String? = nil, tinted: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlassCard(innerGlow: false) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tinted ?? Theme.Colors.accentTurquoise)
                        .frame(width: 24)
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(tinted == .red ? .red : Theme.Colors.textPrimary)
                    Spacer()
                    if let value = value {
                        Text(value)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
        .buttonStyle(CardPressStyle())
    }
    
    // MARK: - Winter Settings Row
    func winterSettingsRow(icon: String, title: String, value: String? = nil, tinted: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WinterSettingsCard {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tinted ?? Theme.Colors.primary)
                        .frame(width: 24)
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(tinted == .red ? .red : Theme.Colors.textPrimary)
                    Spacer()
                    if let value = value {
                        Text(value)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
        }
        .buttonStyle(CardPressStyle())
    }

    func winterSettingsLinkRow(icon: String, title: String, value: String? = nil, tinted: Color? = nil, destination: URL) -> some View {
        Link(destination: destination) {
            WinterSettingsCard {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tinted ?? Theme.Colors.primary)
                        .frame(width: 24)
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(tinted == .red ? .red : Theme.Colors.textPrimary)
                    Spacer()
                    if let value = value {
                        Text(value)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.Colors.textTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CardPressStyle())
    }
    
    var accountBlock: some View {
        Group {
            if lockManager.isRegistered {
                GlassCard(innerGlow: false) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(Theme.Colors.accentTurquoise)
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.welcome".localized(with: lockManager.userName.isEmpty ? "User" : lockManager.userName))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(lockManager.userEmail)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        PrimaryButton("settings.logout".localized, style: .outline) {
                            withAnimation(Theme.Animation.smooth) {
                                sessionManager.signOut()
                            }
                        }
                        .frame(maxWidth: 120)
                    }
                }
            } else {
                GlassCard(innerGlow: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("settings.register_prompt".localized)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                        PrimaryButton("settings.register".localized) {
                            showingRegistration = true
                        }
                        PrimaryButton("auth.login.button".localized, style: .outline) { showingLogin = true }
                        .frame(maxWidth: 220)
                    }
                }
            }
        }
    }
    
    var dataManagementSection: some View { EmptyView() }
    
    var aboutSection: some View { EmptyView() }
}

// MARK: - Computed

private extension SettingsView {
    var profileName: String {
        if let name = appContainer.userProfile?.fullName, !name.isEmpty { return name }
        return "settings.default_user_name".localized
    }
    
    var profileInitials: String {
        if let profile = appContainer.userProfile, !profile.fullName.isEmpty {
            let components = profile.fullName.components(separatedBy: " ")
            let initials = components.compactMap { $0.first }.prefix(2)
            return String(initials).uppercased()
        }
        return "U"
    }
    
    var profileSubtitle: String {
        "settings.profile".localized
    }

    var currentLanguageName: String {
        let languages = appContainer.localizationService.availableLanguages
        let currentCode = appContainer.currentLocale.identifier
        return languages.first { $0.code == currentCode }?.nativeName ?? "English"
    }
}

private extension SettingsView {
    func computeLevel(for xp: Int) -> Int {
        switch xp {
        case 0..<100: return 1
        case 100..<300: return 2
        case 300..<600: return 3
        case 600..<1000: return 4
        case 1000..<1500: return 5
        case 1500..<2200: return 6
        case 2200..<3000: return 7
        default: return 8
        }
    }
    func xpTarget(for level: Int) -> Int {
        switch level {
        case 1: return 100
        case 2: return 300
        case 3: return 600
        case 4: return 1000
        case 5: return 1500
        case 6: return 2200
        case 7: return 3000
        default: return 4000
        }
    }
    func levelName(for level: Int) -> String {
        switch level {
        case 1: return "gamification.level.1".localized
        case 2: return "gamification.level.2".localized
        case 3: return "gamification.level.3".localized
        case 4: return "gamification.level.4".localized
        case 5: return "gamification.level.5".localized
        case 6: return "gamification.level.6".localized
        case 7: return "gamification.level.7".localized
        default: return "gamification.level.default".localized
        }
    }
    func computeBadges(guidesRead: Int, hoursSaved: Int) -> [GamificationBadge] {
        var badges: [GamificationBadge] = []
        if guidesRead >= 1 {
            badges.append(GamificationBadge(icon: "book.fill", title: "gamification.badge.reader".localized, color: Theme.Colors.info))
        }
        if hoursSaved >= 5 {
            badges.append(GamificationBadge(icon: "clock.fill", title: "gamification.badge.time_saver".localized, color: Theme.Colors.accent))
        }
        return badges
    }
}

// MARK: - Support & Feedback helpers

private extension SettingsView {
    var supportEmailURL: URL? {
        let subject = "Sweezy Support v\(Bundle.main.appVersion)"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:support@sweezy.world?subject=\(encodedSubject)")
    }

    var appStoreWriteReviewURL: URL? {
        URL(string: "itms-apps://itunes.apple.com/app/id1633413795?action=write-review")
    }
    
    func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }
}

// MARK: - Backup/Import helpers

private extension SettingsView {
    var defaultBackupFilename: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm"
        return "SweezyBackup_\(fmt.string(from: Date())).json"
    }
    
    struct SweezyBackup: Codable {
        let version: String
        let createdAt: Date
        let locale: String
        let userProfile: UserProfile?
        let guides: [Guide]
        let templates: [DocumentTemplate]
        let checklists: [Checklist]
        let places: [Place]
        let benefitRules: [BenefitRule]
        let news: [NewsItem]
        var integrity: String?
    }
    
    func prepareExport() {
        let locale = appContainer.currentLocale.identifier
        let backup = SweezyBackup(
            version: "2",
            createdAt: Date(),
            locale: locale,
            userProfile: appContainer.userProfile,
            guides: (appContainer.contentService as? ContentService)?.guides ?? [],
            templates: (appContainer.contentService as? ContentService)?.templates ?? [],
            checklists: (appContainer.contentService as? ContentService)?.checklists ?? [],
            places: (appContainer.contentService as? ContentService)?.places ?? [],
            benefitRules: (appContainer.contentService as? ContentService)?.benefitRules ?? [],
            news: (appContainer.contentService as? ContentService)?.news ?? [],
            integrity: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var signedBackup = backup
        signedBackup.integrity = backupDigest(backup)
        if let data = try? encoder.encode(signedBackup) {
            exportDocument = SweezyBackupDocument(data: data)
            showingExporter = true
        }
    }
    
    func importBackup(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard resourceValues.isRegularFile == true,
                  let size = resourceValues.fileSize, size > 0, size <= 10_000_000 else {
                throw CocoaError(.fileReadTooLarge)
            }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let decoder = JSONDecoder()
            let backup = try decoder.decode(SweezyBackup.self, from: data)
            guard ["1", "2"].contains(backup.version),
                  Locale.availableIdentifiers.contains(backup.locale),
                  backup.guides.count <= 10_000,
                  backup.templates.count <= 10_000,
                  backup.checklists.count <= 10_000,
                  backup.places.count <= 10_000,
                  backup.benefitRules.count <= 10_000,
                  backup.news.count <= 10_000 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            if backup.version == "2" {
                guard let integrity = backup.integrity,
                      let expected = backupDigest(backup),
                      integrity == expected else {
                    throw CocoaError(.fileReadCorruptFile)
                }
            }
            if let service = appContainer.contentService as? ContentService {
                service.guides = backup.guides
                service.templates = backup.templates
                service.checklists = backup.checklists
                service.places = backup.places
                service.benefitRules = backup.benefitRules
                service.news = backup.news
                service.lastUpdated = Date()
                // Persist minimal caches so data survives relaunch
                persistToCache(service: service)
            }
            if let profile = backup.userProfile {
                appContainer.userProfile = profile
            }
            appContainer.updateLocale(Locale(identifier: backup.locale))
        } catch {
            AppLogger.error("Import failed: \(error)")
        }
    }

    func backupDigest(_ backup: SweezyBackup) -> String? {
        var unsigned = backup
        unsigned.integrity = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(unsigned) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    
    func persistToCache(service: ContentService) {
        let fm = FileManager.default
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SweezyContent")
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        func write<T: Codable>(_ value: T, name: String) {
            if let data = try? encoder.encode(value) {
                try? data.write(to: cacheDir.appendingPathComponent(name), options: .atomic)
            }
        }
        write(service.guides, name: "guides.json")
        write(service.templates, name: "templates.json")
        write(service.checklists, name: "checklists.json")
        write(service.places, name: "places.json")
        write(service.benefitRules, name: "benefit_rules.json")
        write(service.news, name: "news.json")
    }
    
    func deleteAllData() async {
        // Clear cached content and reload from bundle
        if let service = appContainer.contentService as? ContentService {
            await service.resetContent()
        }
        // Reset local stats and gamification
        appContainer.userStats.reset()
        appContainer.gamification.resetForNewUser()
        // Clear profile and auth
        appContainer.userProfile = nil
        withAnimation(Theme.Animation.smooth) {
            sessionManager.signOut()
        }
    }

    func deleteAccount() async {
        do {
            try await APIClient.deleteAccount()
            await deleteAllData()
        } catch {
            await MainActor.run {
                deleteAccountError = error.localizedDescription
            }
        }
    }
}

// MARK: - FileDocument for exporter

struct SweezyBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    
    init(data: Data) { self.data = data }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
// MARK: - Language Sheet

struct LanguageSelectionSheet: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    
    private var languages: [Language] { appContainer.localizationService.availableLanguages }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(languages) { language in
                    Button(action: {
                        appContainer.updateLocale(language.locale)
                        dismiss()
                    }) {
                        HStack(spacing: Theme.Spacing.md) {
                            Text(language.flag)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.nativeName)
                                    .font(Theme.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text(language.name)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            Spacer()
                            if appContainer.currentLocale.identifier == language.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.Colors.ukrainianBlue)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .journeyForm()
            .navigationTitle("settings.language".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) { dismiss() }
                }
            }
        }
        .journeyScreen(.city, darkness: 0.7)
    }
}

// MARK: - Profile Edit (Redesigned)

struct ProfileEditView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Form state
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var selectedCanton: Canton = .zurich
    @State private var selectedPermitType: PermitType = .s
    @State private var arrivalDate: Date = Date()
    @State private var permitExpiry: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedGoals = Set<UserGoal>()
    @State private var familySize: Int = 1
    @State private var hasChildren: Bool = false
    
    // UI state
    @State private var hasChanges = false
    @State private var showCantonPicker = false
    @State private var showPermitPicker = false
    @State private var showAuthEntry: Bool = false
    
    // Validation
    private var isEmailValid: Bool {
        email.isEmpty || (email.contains("@") && email.contains("."))
    }
    
    // Profile completion
    private var completionPercentage: Double {
        var filled = 0
        let total = 8
        if !fullName.isEmpty { filled += 1 }
        if !email.isEmpty { filled += 1 }
        if !phoneNumber.isEmpty { filled += 1 }
        if familySize > 0 { filled += 1 }
        if !selectedGoals.isEmpty { filled += 2 }
        filled += 2 // dates always set
        return Double(filled) / Double(total)
    }
    
    // Permit time remaining
    private var permitMonthsRemaining: Int {
        let months = Calendar.current.dateComponents([.month], from: Date(), to: permitExpiry).month ?? 0
        return max(0, months)
    }
    private var permitStatusColor: Color {
        if permitMonthsRemaining > 6 { return .green }
        if permitMonthsRemaining > 3 { return .yellow }
        return .red
    }

    // Legacy helpers remain only for source-compatible, non-rendered winter components.
    private var isDarkTheme: Bool { colorScheme == .dark }
    private var winterPrimaryText: Color { isDarkTheme ? .white : Theme.Colors.textPrimary }
    private var winterSecondaryText: Color { isDarkTheme ? .white.opacity(0.68) : Theme.Colors.textSecondary }
    private var winterTertiaryText: Color { isDarkTheme ? .white.opacity(0.5) : Theme.Colors.textTertiary }

    var body: some View {
        Group {
            if sessionManager.isAuthenticated {
                NavigationStack {
                    ZStack {
                        JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 5, darkness: 0.82)
                        
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                heroSection
                                profilePersonalCard
                                profileLocationCard
                                profileTimelineCard
                                profileFamilyCard
                                profileGoalsCard
                                Spacer(minLength: 116)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                        }
                    }
                    .navigationTitle("settings.edit_profile.nav_title".localized)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 38, height: 38)
                                    .background(Color.black.opacity(0.48))
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                            .accessibilityLabel("common.cancel".localized)
                        }
                    }
                    .safeAreaInset(edge: .bottom) { saveButton }
                }
                .journeyScreen(.city, darkness: 0.82)
                .onAppear { loadCurrentProfile() }
                .onChange(of: fullName) { _, _ in hasChanges = true }
                .onChange(of: email) { _, _ in hasChanges = true }
                .onChange(of: phoneNumber) { _, _ in hasChanges = true }
                .onChange(of: selectedCanton) { _, _ in hasChanges = true }
                .onChange(of: selectedPermitType) { _, _ in hasChanges = true }
                .onChange(of: arrivalDate) { _, _ in hasChanges = true }
                .onChange(of: permitExpiry) { _, _ in hasChanges = true }
                .onChange(of: selectedGoals) { _, _ in hasChanges = true }
                .onChange(of: familySize) { _, _ in hasChanges = true }
                .onChange(of: hasChildren) { _, _ in hasChanges = true }
                .sheet(isPresented: $showCantonPicker) { cantonPickerSheet }
                .sheet(isPresented: $showPermitPicker) { permitPickerSheet }
            } else {
                // Profile personalization is account-based; guests must sign in first.
                guestGateContent
            }
        }
        .sheet(isPresented: $showAuthEntry) {
            AuthEntryView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
    }

    private var guestGateContent: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 7, darkness: 0.84)
                
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(JourneyVisual.lime)
                    
                    Text("auth.login.title")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("auth.login.subtitle")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showAuthEntry = true
                    } label: {
                        Text("auth.entry.open_auth")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(JourneyVisual.lime)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    
                    Button { dismiss() } label: {
                        Text("common.close")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.62))
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.58))
                        .background(.ultraThinMaterial.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
            }
            .journeyScreen(.city, darkness: 0.84)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
    }
    
    // MARK: - Hero
    private var heroSection: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.72))
                    .frame(width: 72, height: 72)
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: completionPercentage)
                    .stroke(JourneyVisual.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                Text(initials)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(fullName.isEmpty ? "settings.profile.your_name".localized : fullName)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !email.isEmpty {
                    Text(email)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(1)
                }
                Text("settings.profile.completion_format".localized(with: Int(completionPercentage * 100)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(JourneyVisual.lime)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .journeyCard(cornerRadius: 24)
    }
    
    // MARK: - Winter Hero
    private var winterHeroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 130, height: 130)
                    .blur(radius: 20)
                
                // Avatar circle with gradient
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.cyan, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.cyan.opacity(0.4), radius: 15, x: 0, y: 8)
                
                Text(initials)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Progress ring border
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    .frame(width: 112, height: 112)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: completionPercentage)
                    .stroke(
                        LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 112, height: 112)
                    .rotationEffect(.degrees(-90))
                
                // Snowflake decorations
                Text("❄️")
                    .font(.system(size: 14))
                    .offset(x: 45, y: -45)
                Text("✨")
                    .font(.system(size: 12))
                    .offset(x: -50, y: 40)
            }
            
            VStack(spacing: 6) {
                Text(fullName.isEmpty ? "settings.profile.your_name".localized : fullName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(winterPrimaryText)
                
                if !email.isEmpty {
                    Text(email)
                        .font(.system(size: 14))
                        .foregroundColor(winterSecondaryText)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: completionPercentage >= 1 ? "checkmark.seal.fill" : "chart.pie.fill")
                        .font(.system(size: 12))
                    Text("settings.profile.completion_format".localized(with: Int(completionPercentage * 100)))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(completionPercentage >= 1 ? .green : winterTertiaryText)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
    }
    private var initials: String {
        let comps = fullName.split(separator: " ")
        let letters = comps.compactMap { $0.first }.prefix(2)
        return letters.isEmpty ? "U" : String(letters).uppercased()
    }
    
    // MARK: - Cards (Original)
    private var profilePersonalCard: some View {
        ProfileSectionCard(icon: "person.fill", title: "settings.profile.section.personal".localized, color: .blue) {
            VStack(spacing: 16) {
                ProfileTextField(icon: "person", placeholder: "settings.full_name".localized, text: $fullName, isValid: !fullName.isEmpty)
                ProfileTextField(icon: "envelope", placeholder: "Email", text: $email, keyboardType: .emailAddress, isValid: isEmailValid, validationMessage: isEmailValid ? nil : "validation.email_invalid".localized)
                ProfileTextField(icon: "phone", placeholder: "settings.phone".localized, text: $phoneNumber, keyboardType: .phonePad, isValid: true)
            }
        }
    }
    
    // MARK: - Winter Cards
    private var winterProfilePersonalCard: some View {
        WinterSectionCard(icon: "person.fill", title: "settings.profile.section.personal".localized, color: .blue) {
            VStack(spacing: 16) {
                WinterTextField(icon: "person", placeholder: "settings.full_name".localized, text: $fullName, isValid: !fullName.isEmpty)
                WinterTextField(icon: "envelope", placeholder: "Email", text: $email, keyboardType: .emailAddress, isValid: isEmailValid, validationMessage: isEmailValid ? nil : "validation.email_invalid".localized)
                WinterTextField(icon: "phone", placeholder: "settings.phone".localized, text: $phoneNumber, keyboardType: .phonePad, isValid: true)
            }
        }
    }
    
    private var winterProfileLocationCard: some View {
        WinterSectionCard(icon: "mappin.and.ellipse", title: "settings.profile.section.location".localized, color: .orange) {
            VStack(spacing: 16) {
                Button { showCantonPicker = true } label: {
                    HStack {
                        Image(systemName: "building.2").foregroundColor(.orange).frame(width: 24)
                        Text("calculator.canton".localized).foregroundColor(winterSecondaryText)
                        Spacer()
                        HStack(spacing: 6) {
                            Text(selectedCanton.flag).font(.system(size: 18))
                            Text(selectedCanton.localizedName).foregroundColor(winterPrimaryText)
                        }
                        Image(systemName: "chevron.right").foregroundColor(winterTertiaryText)
                    }
                    .padding(14)
                    .background(Theme.Colors.adaptiveCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.2), lineWidth: 1))
                }.buttonStyle(.plain)
                
                Button { showPermitPicker = true } label: {
                    HStack {
                        Image(systemName: "doc.badge.gearshape").foregroundColor(selectedPermitType.color).frame(width: 24)
                        Text("calculator.permit_type".localized).foregroundColor(winterSecondaryText)
                        Spacer()
                        HStack(spacing: 6) {
                            Text(selectedPermitType.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(selectedPermitType.color).cornerRadius(6)
                            Text(selectedPermitType.shortName).foregroundColor(winterPrimaryText)
                        }
                        Image(systemName: "chevron.right").foregroundColor(winterTertiaryText)
                    }
                    .padding(14)
                    .background(Theme.Colors.adaptiveCard)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.2), lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
    }
    
    private var winterProfileTimelineCard: some View {
        WinterSectionCard(icon: "calendar.badge.clock", title: "settings.profile.section.dates".localized, color: .purple) {
            VStack(spacing: 20) {
                HStack(alignment: .top) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.green).frame(width: 16, height: 16)
                            Circle().fill(.white).frame(width: 6, height: 6)
                        }
                        Text("settings.profile.arrival".localized).font(.system(size: 11, weight: .medium)).foregroundColor(winterSecondaryText)
                        Text(arrivalDate.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(winterPrimaryText)
                    }.frame(maxWidth: .infinity)
                    
                    VStack {
                        Rectangle()
                            .fill(LinearGradient(colors: [.green, permitStatusColor], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 3)
                            .cornerRadius(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(permitStatusColor).frame(width: 16, height: 16)
                            Circle().fill(.white).frame(width: 6, height: 6)
                        }
                        Text("settings.profile.expiry".localized).font(.system(size: 11, weight: .medium)).foregroundColor(winterSecondaryText)
                        Text(permitExpiry.formatted(.dateTime.day().month(.abbreviated).year()))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(winterPrimaryText)
                    }.frame(maxWidth: .infinity)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: permitMonthsRemaining > 3 ? "clock" : "exclamationmark.triangle")
                        .font(.system(size: 14))
                    Text("settings.profile.months_remaining_format".localized(with: permitMonthsRemaining))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(permitStatusColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(permitStatusColor.opacity(0.2))
                .cornerRadius(10)
                
                HStack(spacing: 12) {
                    DatePicker("", selection: $arrivalDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .scaleEffect(0.9)
                    Text("→").foregroundColor(winterTertiaryText)
                    DatePicker("", selection: $permitExpiry, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .scaleEffect(0.9)
                }
            }
        }
    }
    
    private var winterProfileFamilyCard: some View {
        WinterSectionCard(icon: "figure.2.and.child.holdinghands", title: "checklist.category.family".localized, color: .pink) {
            VStack(spacing: 16) {
                HStack {
                    Text("settings.profile.family_size".localized).foregroundColor(winterSecondaryText)
                    Spacer()
                    HStack(spacing: 0) {
                        Button { if familySize > 1 { familySize -= 1 } } label: {
                            Image(systemName: "minus").frame(width: 36, height: 36)
                        }
                        .disabled(familySize <= 1)
                        Divider().frame(height: 20)
                        Text("\(familySize)")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36)
                        Divider().frame(height: 20)
                        Button { if familySize < 20 { familySize += 1 } } label: {
                            Image(systemName: "plus").frame(width: 36, height: 36)
                        }
                    }
                    .foregroundColor(winterPrimaryText)
                    .background(Theme.Colors.adaptiveSurface)
                    .cornerRadius(10)
                }
                
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: hasChildren ? "figure.and.child.holdinghands" : "figure.2")
                            .foregroundColor(hasChildren ? .pink : winterTertiaryText)
                            .frame(width: 24)
                        Text("settings.profile.has_children".localized).foregroundColor(winterPrimaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $hasChildren).labelsHidden().tint(.pink)
                }
                .padding(14)
                .background(Theme.Colors.adaptiveCard)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.2), lineWidth: 1))
            }
        }
    }
    
    private var winterProfileGoalsCard: some View {
        WinterSectionCard(icon: "target", title: "settings.profile.section.goals".localized, color: .cyan) {
            winterGoalsGrid
        }
    }
    
    private var winterGoalsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(UserGoal.allCases) { goal in
                WinterGoalChip(
                    goal: goal,
                    isSelected: selectedGoals.contains(goal),
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedGoals.contains(goal) {
                                selectedGoals.remove(goal)
                            } else {
                                selectedGoals.insert(goal)
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                )
            }
        }
    }
    
    private var winterSaveButton: some View {
        Button {
            saveProfile()
        } label: {
            Text("marketplace.save_changes".localized)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundColor(hasChanges ? .white : Theme.Colors.textPrimary)
                .background(
                    hasChanges
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color.cyan, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                          ))
                        : AnyShapeStyle(Theme.Colors.adaptiveSurface)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(hasChanges ? Color.cyan.opacity(0.5) : Theme.Colors.adaptiveSurface, lineWidth: 1)
                )
                .shadow(color: hasChanges ? Color.cyan.opacity(0.3) : Color.clear, radius: 10, y: 4)
        }
        .disabled(!hasChanges)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            (isDarkTheme ? Theme.Colors.darkBackground : Theme.Colors.primaryBackground).opacity(0.95)
        )
    }
    private var profileLocationCard: some View {
        ProfileSectionCard(icon: "mappin.and.ellipse", title: "settings.profile.section.location".localized, color: .orange) {
            VStack(spacing: 16) {
                Button { showCantonPicker = true } label: {
                    HStack {
                        Image(systemName: "building.2").foregroundColor(JourneyVisual.lime).frame(width: 24)
                        Text("calculator.canton".localized).foregroundColor(.white.opacity(0.62))
                        Spacer()
                        HStack(spacing: 6) { Text(selectedCanton.flag).font(.system(size: 18)); Text(selectedCanton.localizedName).foregroundColor(.white) }
                        Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.34))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }.buttonStyle(.plain)
                
                Button { showPermitPicker = true } label: {
                    HStack {
                        Image(systemName: "doc.badge.gearshape").foregroundColor(selectedPermitType.color).frame(width: 24)
                        Text("calculator.permit_type".localized).foregroundColor(.white.opacity(0.62))
                        Spacer()
                        HStack(spacing: 6) {
                            Text(selectedPermitType.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(selectedPermitType.color).cornerRadius(6)
                            Text(selectedPermitType.shortName).foregroundColor(.white)
                        }
                        Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.34))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
    }
    private var profileTimelineCard: some View {
        ProfileSectionCard(icon: "calendar.badge.clock", title: "settings.profile.section.dates".localized, color: .purple) {
            VStack(spacing: 20) {
                HStack(alignment: .top) {
                    VStack(spacing: 8) {
                        ZStack { Circle().fill(Color.green).frame(width: 16, height: 16); Circle().fill(.white).frame(width: 6, height: 6) }
                        Text("settings.profile.arrival".localized).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.58))
                        Text(arrivalDate.formatted(.dateTime.day().month(.abbreviated))).font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }.frame(maxWidth: .infinity)
                    VStack { Rectangle().fill(LinearGradient(colors: [.green, permitStatusColor], startPoint: .leading, endPoint: .trailing)).frame(height: 3).cornerRadius(2) }
                        .frame(maxWidth: .infinity).padding(.top, 6)
                    VStack(spacing: 8) {
                        ZStack { Circle().fill(permitStatusColor).frame(width: 16, height: 16); Circle().fill(.white).frame(width: 6, height: 6) }
                        Text("settings.profile.expiry".localized).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.58))
                        Text(permitExpiry.formatted(.dateTime.day().month(.abbreviated).year())).font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }.frame(maxWidth: .infinity)
                }
                HStack(spacing: 8) {
                    Image(systemName: permitMonthsRemaining > 3 ? "clock" : "exclamationmark.triangle").font(.system(size: 14))
                    Text("settings.profile.months_remaining_format".localized(with: permitMonthsRemaining)).font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(permitStatusColor)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(permitStatusColor.opacity(0.15)).cornerRadius(10)
                HStack(spacing: 12) {
                    DatePicker("", selection: $arrivalDate, displayedComponents: .date).labelsHidden().datePickerStyle(.compact).scaleEffect(0.9)
                    Text("→").foregroundColor(.white.opacity(0.42))
                    DatePicker("", selection: $permitExpiry, displayedComponents: .date).labelsHidden().datePickerStyle(.compact).scaleEffect(0.9)
                }
            }
        }
    }
    private var profileFamilyCard: some View {
        ProfileSectionCard(icon: "figure.2.and.child.holdinghands", title: "checklist.category.family".localized, color: .pink) {
            VStack(spacing: 16) {
                HStack {
                    Text("settings.profile.family_size".localized).foregroundColor(.white.opacity(0.62))
                    Spacer()
                    HStack(spacing: 0) {
                        Button { if familySize > 1 { familySize -= 1 } } label: { Image(systemName: "minus").frame(width: 36, height: 36) }
                            .disabled(familySize <= 1)
                        Divider().frame(height: 20)
                        Text("\(familySize)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(width: 38)
                        Divider().frame(height: 20)
                        Button { if familySize < 20 { familySize += 1 } } label: { Image(systemName: "plus").frame(width: 36, height: 36) }
                    }
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.08)).cornerRadius(10)
                }
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: hasChildren ? "figure.and.child.holdinghands" : "figure.2")
                            .foregroundColor(hasChildren ? JourneyVisual.lime : .white.opacity(0.42)).frame(width: 24)
                        Text("settings.profile.has_children".localized).foregroundColor(.white)
                    }
                    Spacer()
                    Toggle("", isOn: $hasChildren).labelsHidden().tint(JourneyVisual.lime)
                }
                .padding(14).background(Color.white.opacity(0.07)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }
    private var profileGoalsCard: some View {
        ProfileSectionCard(icon: "target", title: "settings.profile.section.goals".localized, color: .cyan) {
            goalsGrid
        }
    }
    
    // Sticky save
    private var saveButton: some View {
        Button {
            saveProfile()
        } label: {
            Text("marketplace.save_changes".localized)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundColor(hasChanges ? .black : .white.opacity(0.42))
                .background(hasChanges ? JourneyVisual.lime : Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(hasChanges ? 0 : 0.12), lineWidth: 1)
                )
                .shadow(color: hasChanges ? JourneyVisual.lime.opacity(0.22) : .clear, radius: 18, y: 7)
        }
        .disabled(!hasChanges)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.92))
        .background(Color.black.opacity(0.72))
    }
    
    // MARK: - Sheets
    private var cantonPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(Canton.allCases, id: \.self) { canton in
                    Button {
                        selectedCanton = canton
                        showCantonPicker = false
                    } label: {
                        HStack(spacing: 12) {
                            Text(canton.flag).font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(canton.localizedName).foregroundColor(Theme.Colors.textPrimary)
                                Text(canton.rawValue).font(.caption).foregroundColor(Theme.Colors.textTertiary)
                            }
                            Spacer()
                            if selectedCanton == canton { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                        }
                    }.buttonStyle(.plain)
                }
            }
            .navigationTitle("marketplace.select_canton".localized)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("common.done".localized) { showCantonPicker = false } } }
        }
        .presentationDetents([.medium, .large])
    }
    private var permitPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(PermitType.allCases, id: \.self) { permit in
                    Button {
                        selectedPermitType = permit
                        showPermitPicker = false
                    } label: {
                        HStack(spacing: 14) {
                            Text(permit.rawValue)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(permit.color)
                                .cornerRadius(8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(permit.localizedName).foregroundColor(Theme.Colors.textPrimary)
                                Text(permit.description).font(.caption).foregroundColor(Theme.Colors.textSecondary).lineLimit(2)
                            }
                            Spacer()
                            if selectedPermitType == permit { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                        }
                    }.buttonStyle(.plain)
                }
            }
            .navigationTitle("calculator.permit_type".localized)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("common.done".localized) { showPermitPicker = false } } }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Data
    private func loadCurrentProfile() {
        if let profile = appContainer.userProfile {
            fullName = profile.fullName
            email = profile.email ?? ""
            phoneNumber = profile.phoneNumber ?? ""
            selectedCanton = profile.canton
            selectedPermitType = profile.permitType
            arrivalDate = profile.arrivalDate ?? Date()
            permitExpiry = profile.permitExpiryDate ?? (Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
            selectedGoals = Set(profile.goals)
            familySize = profile.familySize
            hasChildren = profile.hasChildren
        }
        hasChanges = false
    }
    private func saveProfile() {
        var profile = appContainer.userProfile ?? UserProfile()
        profile.fullName = fullName
        profile.email = email
        profile.phoneNumber = phoneNumber
        profile.canton = selectedCanton
        profile.permitType = selectedPermitType
        profile.arrivalDate = arrivalDate
        profile.permitExpiryDate = permitExpiry
        profile.goals = Array(selectedGoals)
        profile.familySize = familySize
        profile.hasChildren = hasChildren
        profile.preferredLanguage = appContainer.currentLocale.identifier
        appContainer.userProfile = profile
        LiveActivitiesManager.shared.updatePermitDeadline(profile.permitExpiryDate)
        if let next = appContainer.firstWeekService.nextDueTask {
            LiveActivitiesManager.shared.updateNextTask(.init(title: next.title, dueDate: next.dueDate))
        }
        dismiss()
    }
}

private extension ProfileEditView {
    var goalsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(UserGoal.allCases) { goal in
                GoalChipButton(
                    goal: goal,
                    isSelected: selectedGoals.contains(goal),
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedGoals.contains(goal) {
                                selectedGoals.remove(goal)
                            } else {
                                selectedGoals.insert(goal)
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                )
            }
        }
    }
}

// MARK: - Profile Quick Stat
private struct ProfileQuickStat: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.Colors.accentTurquoise)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.chipBackground.opacity(0.6))
        .cornerRadius(8)
    }
}

// MARK: - Winter Quick Stat
private struct WinterQuickStat: View {
    let icon: String
    let value: String
    let label: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.Colors.primary)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Theme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : Theme.Colors.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.adaptiveSurface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Goal Chip Button
private struct GoalChipButton: View {
    let goal: UserGoal
    let isSelected: Bool
    let onTap: () -> Void
    
    private var goalIcon: String {
        switch goal {
        case .housing: return "house.fill"
        case .work: return "briefcase.fill"
        case .language: return "character.book.closed.fill"
        case .education: return "graduationcap.fill"
        case .documents: return "doc.text.fill"
        case .finance: return "creditcard.fill"
        case .health: return "heart.fill"
        }
    }
    
    private var goalColor: Color {
        switch goal {
        case .housing: return .green
        case .work: return .blue
        case .language: return .purple
        case .education: return .indigo
        case .documents: return .orange
        case .finance: return .yellow
        case .health: return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.black.opacity(0.16) : Color.white.opacity(0.08))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: goalIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .black : JourneyVisual.lime)
                }
                
                Text(goal.localizedName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 4)
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? JourneyVisual.lime : Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: isSelected ? JourneyVisual.lime.opacity(0.22) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views for Profile Edit
private struct ProfileSectionCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let content: Content
    init(icon: String, title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon; self.title = title; self.color = color; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 32, height: 32)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            content
        }
        .padding(17)
        .journeyCard(cornerRadius: 22)
    }
}
private struct ProfileTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isValid: Bool = true
    var validationMessage: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isValid ? JourneyVisual.lime : .red)
                    .frame(width: 24)
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                if !text.isEmpty {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isValid ? .green : .red)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isValid ? Color.white.opacity(0.1) : Color.red.opacity(0.55), lineWidth: 1)
            )
            if let message = validationMessage {
                Text(message).font(.system(size: 11)).foregroundColor(.red).padding(.leading, 36)
            }
        }
    }
}

// MARK: - Winter Section Card
private struct WinterSectionCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(icon: String, title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(8)
                    .shadow(color: color.opacity(0.3), radius: 4, y: 2)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Theme.Colors.textPrimary)
            }
            content
        }
        .padding(16)
        .background(Theme.Colors.adaptiveCard)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.3), Theme.Colors.adaptiveSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.cyan.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Winter Text Field
private struct WinterTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isValid: Bool = true
    var validationMessage: String? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isValid ? (colorScheme == .dark ? .white.opacity(0.4) : Theme.Colors.textTertiary) : .red)
                    .frame(width: 24)
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .keyboardType(keyboardType)
                    .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                    .foregroundColor(colorScheme == .dark ? .white : Theme.Colors.textPrimary)
                
                if !text.isEmpty {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isValid ? .green : .red)
                }
            }
            .padding(14)
            .background(Theme.Colors.adaptiveCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
            )
            
            if let message = validationMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .padding(.leading, 36)
            }
        }
    }
}

// MARK: - Winter Goal Chip
private struct WinterGoalChip: View {
    let goal: UserGoal
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var goalIcon: String {
        switch goal {
        case .housing: return "house.fill"
        case .work: return "briefcase.fill"
        case .language: return "character.book.closed.fill"
        case .education: return "graduationcap.fill"
        case .documents: return "doc.text.fill"
        case .finance: return "creditcard.fill"
        case .health: return "heart.fill"
        }
    }
    
    private var goalColor: Color {
        switch goal {
        case .housing: return .green
        case .work: return .blue
        case .language: return .purple
        case .education: return .indigo
        case .documents: return .orange
        case .finance: return .yellow
        case .health: return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? goalColor : goalColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: goalIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : goalColor)
                }
                
                Text(goal.localizedName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 4)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? goalColor.opacity(0.25) : Theme.Colors.adaptiveCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? goalColor.opacity(0.5) : Color.cyan.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? goalColor.opacity(0.2) : .clear, radius: 6, x: 0, y: 3)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Convenience
private extension PermitType {
    var color: Color {
        switch self {
        case .s: return .yellow
        case .b: return .blue
        case .c: return .green
        case .f: return .orange
        case .n: return .purple
        case .l: return .cyan
        case .other: return .gray
        }
    }
    var shortName: String {
        switch self {
        case .s: return "settings.permit.short.s".localized
        case .b: return "settings.permit.short.b".localized
        case .c: return "settings.permit.short.c".localized
        case .f: return "settings.permit.short.f".localized
        case .n: return "settings.permit.short.n".localized
        case .l: return "settings.permit.short.l".localized
        case .other: return "common.other".localized
        }
    }
}
private extension Canton {
    var flag: String {
        switch self {
        case .zurich: return "🏔️"
        case .bern: return "🐻"
        case .geneva: return "🦅"
        case .basel: return "🏛️"
        case .vaud: return "🍇"
        default: return "🇨🇭"
        }
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 7, darkness: 0.72)
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Hero
                    VStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.cyan.opacity(0.35),
                                            Color.blue.opacity(0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 84, height: 84)
                                .shadow(color: Color.cyan.opacity(0.35), radius: 12, y: 4)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.cyan, Color.blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Text("Sweezy")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Text("Your guide to life in Switzerland")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // About block
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("About Sweezy")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("Sweezy is designed to help Ukrainian refugees and other newcomers navigate life in Switzerland. We provide essential information, step-by-step guides, and useful tools to make your integration journey smoother.")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.Colors.adaptiveCard.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.cyan.opacity(0.4), Theme.Colors.adaptiveBorder.opacity(0.65)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    
                    // Features
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Features")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            FeatureRow(icon: "book", title: "Comprehensive Guides", description: "Step-by-step information on housing, healthcare, work, and more")
                            FeatureRow(icon: "checklist", title: "Interactive Checklists", description: "Track your progress through important tasks")
                            FeatureRow(icon: "calculator", title: "Benefits Calculator", description: "Estimate your eligibility for subsidies and support")
                            FeatureRow(icon: "map", title: "Service Locator", description: "Find nearby offices, healthcare, and services")
                            FeatureRow(icon: "doc.text", title: "Document Templates", description: "Generate letters and forms with ease")
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Theme.Colors.adaptiveCard.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.65), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("settings.about".localized)
        .navigationBarTitleDisplayMode(.inline)
        .journeyScreen(.city, darkness: 0.72)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.ukrainianBlue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Local UI helpers
private struct SmallPillButton: View {
    enum Style { case filled, outline }
    let title: String
    let style: Style
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                // base background
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.Colors.glassMaterial)
                // filled overlay if needed
                if style == .filled {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [Theme.Colors.accentTurquoise, Theme.Colors.primary], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                Text(title)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(style == .filled ? .white : Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .frame(minWidth: 120, minHeight: 38)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.Colors.chipBorder.opacity(style == .filled ? 0.0 : 1.0), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(style == .filled ? 0.22 : 0.08), radius: style == .filled ? 7 : 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Winter Pill Button
private struct WinterPillButton: View {
    enum Style { case filled, outline }
    let title: String
    let style: Style
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.subheadline)
                .foregroundColor(style == .filled ? .white : .cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minWidth: 120, minHeight: 38)
                .background(
                    style == .filled
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color.cyan, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ))
                        : AnyShapeStyle(Theme.Colors.adaptiveCard)
                )
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            style == .filled ? Color.cyan.opacity(0.5) : Color.cyan.opacity(0.3),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: style == .filled ? Color.cyan.opacity(0.3) : Color.clear,
                    radius: 6,
                    y: 2
                )
        }
        .buttonStyle(.plain)
    }
}

private struct BadgePill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.Typography.caption2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.yellow)
            .foregroundColor(.black)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
    }
}

private struct StatusChip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(Theme.Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color.opacity(0.25))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct PlanChip: View {
    let icon: String
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .opacity(color == .yellow ? 0.9 : 0.8)
            Text(text)
                .font(Theme.Typography.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.25)))
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

private struct TrialCountdownChip: View {
    let expireAt: Date
    var locale: Locale? = nil
    @State private var now = Date()
    private var remaining: TimeInterval { max(0, expireAt.timeIntervalSince(now)) }
    private var units: (d: String, h: String, m: String, label: String) {
        (
            "settings.trial.day_unit".localized,
            "settings.trial.hour_unit".localized,
            "settings.trial.minute_unit".localized,
            "settings.trial.label".localized
        )
    }
    private var text: String {
        let total = Int(remaining)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let mins = (total % 3600) / 60
        if days > 0 { return "\(units.label) · \(days)\(units.d) \(hours)\(units.h)" }
        if hours > 0 { return "\(units.label) · \(hours)\(units.h) \(mins)\(units.m)" }
        return "\(units.label) · \(mins)\(units.m)"
    }
    var body: some View {
        PlanChip(icon: "clock.fill", text: text, color: .yellow)
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in now = Date() }
    }
}

private struct ThemeSelectionButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: theme.iconName)
                    .font(.system(size: 18, weight: .semibold))
                Text(theme.localizedName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Theme.Colors.primaryLight, Theme.Colors.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Theme.Colors.adaptiveSurface)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Theme.Colors.primary.opacity(0.45) : Theme.Colors.adaptiveBorder.opacity(0.55),
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? Theme.Colors.primary.opacity(0.18) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct EditorialSettingsPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.075, green: 0.082, blue: 0.078).opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.19), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
    }
}

private extension View {
    func editorialSettingsPanel(cornerRadius: CGFloat) -> some View {
        modifier(EditorialSettingsPanelModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Winter Settings Card
private struct WinterSettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(Theme.Colors.adaptiveCard)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.Colors.primary.opacity(0.3), Theme.Colors.adaptiveSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Winter Section Header
private struct WinterSectionHeader: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.primary, Theme.Colors.primary.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 40, height: 3)
                .cornerRadius(2)
        }
        .padding(.top, 8)
    }
}
