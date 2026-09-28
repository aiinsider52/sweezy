//
//  CVBuilderView.swift
//  sweezy
//
//  Professional CV Builder following local DACH standards.
//  Features: step-by-step wizard, DE translation, AI enhancement.
//

import SwiftUI
import UIKit
import PhotosUI

struct CVBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    private let onClose: (() -> Void)?

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }
    
    // Step-by-step navigation
    @State private var currentStep: CVStep = .personal
    
    // CV Data
    @State private var cv = CVResume.empty
    
    // Translation
    @State private var previewLanguage: PreviewLanguage = .ukrainian
    @State private var germanCV: CVResume?
    @State private var germanCVSource: CVResume?
    @State private var isTranslating = false
    @State private var translationError: String?
    
    // AI Enhancement
    @State private var isAIProcessing = false
    @State private var processingSection: String?
    @State private var aiError: String?
    @State private var aiSuccess: String?
    
    // UI State
    @State private var showTips = false
    @State private var copiedFeedback = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var exportError: String?
    @State private var showAuthPrompt = false
    @State private var showPrivacyDisclosure = false
    @State private var showCVPlusGate = false
    @State private var showSubscription = false
    @State private var cvFreeActionsUsed = 0
    @State private var pendingPrivateAction: (() -> Void)?
    @FocusState private var isInputFocused: Bool

    private var activeCountry: ResidenceCountry {
        ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland
    }

    private var locationPlaceholder: String {
        switch activeCountry {
        case .switzerland: return "Zürich, ZH"
        case .germany: return "Berlin, DE-BE"
        case .austria: return "Wien, AT-9"
        }
    }

    private var phonePlaceholder: String {
        switch activeCountry {
        case .switzerland: return "+41 79 123 45 67"
        case .germany: return "+49 151 12345678"
        case .austria: return "+43 660 1234567"
        }
    }
    
    enum PreviewLanguage: String, CaseIterable {
        case ukrainian = "uk"
        case german = "de"
        
        var flag: String {
            switch self {
            case .ukrainian: return "🇺🇦"
            case .german: return "🇩🇪"
            }
        }
        
        var name: String {
            switch self {
            case .ukrainian: return "Українська".localized
            case .german: return "Deutsch"
            }
        }
    }
    
    enum CVStep: Int, CaseIterable {
        case personal = 0
        case summary = 1
        case experience = 2
        case education = 3
        case skills = 4
        case preview = 5
        
        var title: String {
            switch self {
            case .personal: return "Особисті дані".localized
            case .summary: return "Профіль".localized
            case .experience: return "Досвід".localized
            case .education: return "Освіта".localized
            case .skills: return "Навички".localized
            case .preview: return "Перегляд".localized
            }
        }
        
        var icon: String {
            switch self {
            case .personal: return "person.fill"
            case .summary: return "text.alignleft"
            case .experience: return "briefcase.fill"
            case .education: return "graduationcap.fill"
            case .skills: return "star.fill"
            case .preview: return "doc.text.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
                JourneyVisual.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        cvHero
                        cvTopBar
                    }

                    TabView(selection: $currentStep) {
                        personalStepView.tag(CVStep.personal)
                        summaryStepView.tag(CVStep.summary)
                        experienceStepView.tag(CVStep.experience)
                        educationStepView.tag(CVStep.education)
                        skillsStepView.tag(CVStep.skills)
                        previewStepView.tag(CVStep.preview)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .scrollDismissesKeyboard(.interactively)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)

                }
                .ignoresSafeArea(edges: .top)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            navigationButtons
        }
        .navigationBarHidden(true)
        .interactiveSwipeBackEnabled()
        .simultaneousGesture(
            DragGesture(minimumDistance: 18, coordinateSpace: .global)
                .onEnded { value in
                    guard value.startLocation.x <= 28,
                          value.translation.width >= 88,
                          abs(value.translation.height) <= 90 else { return }
                    closeScreen()
                }
        )
        .sheet(isPresented: $showTips) {
            swissCVTipsSheet
        }
        .sheet(isPresented: $showAuthPrompt) {
            AuthEntryView(showsCloseButton: true) { showAuthPrompt = false }
        }
        .sheet(isPresented: $showCVPlusGate) {
            CVPlusGateSheet(
                freeActionsUsed: cvFreeActionsUsed,
                openPlus: {
                    showCVPlusGate = false
                    APIClient.logPaywall(eventType: "cta_click", context: SubscriptionSource.cv.rawValue)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showSubscription = true
                    }
                },
                dismiss: { showCVPlusGate = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $showSubscription) {
            SubscriptionView(source: .cv)
        }
        .alert("Приватність CV".localized, isPresented: $showPrivacyDisclosure) {
            Button("Скасувати".localized, role: .cancel) { pendingPrivateAction = nil }
            Button("Продовжити".localized) {
                UserDefaults.standard.set(true, forKey: "cv_ai_privacy_disclosed")
                let action = pendingPrivateAction
                pendingPrivateAction = nil
                action?()
            }
        } message: {
            Text("Лише після вашої дії текст CV надсилається захищеним з’єднанням для покращення або перекладу. Текст CV не журналюється і не зберігається на сервері.".localized)
        }
        .onAppear {
            loadSavedCV()
            loadSavedPhoto()
            cvFreeActionsUsed = UserDefaults.standard.integer(forKey: cvPlusUsageKey)
            NotificationCenter.default.post(name: .setJourneyBottomBarHidden, object: true)
        }
        .task {
            await subscriptionManager.load()
            if let entitlements = await APIClient.fetchEntitlements(), !entitlements.is_premium {
                let backendUses = max(0, 3 - entitlements.cv_free_uses_remaining)
                cvFreeActionsUsed = max(cvFreeActionsUsed, backendUses)
                UserDefaults.standard.set(cvFreeActionsUsed, forKey: cvPlusUsageKey)
            }
        }
        .onDisappear {
            saveCV()
            NotificationCenter.default.post(name: .setJourneyBottomBarHidden, object: false)
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedPhotoData = data
                        saveSelectedPhoto(data)
                    }
                }
            }
        }
        .onChange(of: cv) { _, _ in
            if CVTranslationCachePolicy.shouldInvalidate(cachedSource: germanCVSource, currentSource: cv) {
                germanCV = nil
                germanCVSource = nil
                if previewLanguage == .german { previewLanguage = .ukrainian }
                translationError = nil
            }
        }
        .onChange(of: currentStep) { _, step in
            dismissKeyboard()
            if step == .preview { isInputFocused = false }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово".localized) { dismissKeyboard() }
                    .accessibilityIdentifier("cv.keyboard.done")
            }
        }
        .featureOnboarding(.cvBuilder)
    }

    private var cvTopBar: some View {
        HStack(spacing: 12) {
            Button {
                closeScreen()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.card)
                    .background(.ultraThinMaterial.opacity(0.55))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel("Назад".localized)
            .accessibilityIdentifier("cv.builder.back")

            Spacer()

            VStack(spacing: 2) {
                Text("journey.tool.cv.title".localized)
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundColor(JourneyVisual.primaryText)
                Text("Крок %@ із %@".localized(with: "\(currentStep.rawValue + 1)", "\(CVStep.allCases.count)"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
            }

            Spacer()

            Button {
                showTips = true
            } label: {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.card)
                    .background(.ultraThinMaterial.opacity(0.55))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
            }
            .accessibilityLabel("Поради для швейцарського CV".localized)
        }
        .padding(.horizontal, 16)
        .padding(.top, 58)
        .padding(.bottom, 8)
    }

    private func closeScreen() {
        dismissKeyboard()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var cvHero: some View {
        ZStack(alignment: .bottomLeading) {
            JourneyVisual.pageBackground

            VStack(alignment: .leading, spacing: 10) {
                if !isInputFocused {
                    // Sweezy reviewing a CV at the desk; hidden while typing to give the form room.
                    FocusedSceneImage(name: "story-jobs", focusY: 0.2)
                        .frame(height: 112)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(JourneyVisual.softBorder, lineWidth: 1)
                        )
                        .accessibilityHidden(true)
                        .transition(.opacity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CV, який\nпомітять".localized)
                            .font(.system(size: 29, weight: .bold, design: .default))
                            .foregroundColor(JourneyVisual.primaryText)
                            .lineSpacing(1)
                        Text("Заповни основні дані — ми допоможемо решту.".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                    }
                }
                progressBar
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(height: isInputFocused ? 148 : 300)
        .clipped()
        .animation(.easeInOut(duration: 0.2), value: isInputFocused)
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("\(currentStep.rawValue + 1)")
                    .font(.system(size: 12, weight: .black, design: .default))
                    .foregroundColor(.black)
                    .frame(width: 22, height: 22)
                    .background(JourneyVisual.lime)
                    .clipShape(Circle())
                Text(currentStep.title)
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .lineLimit(1)
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(height: 30)
            .background(JourneyVisual.lime)
            .clipShape(Capsule())

            HStack(spacing: 8) {
                ForEach(CVStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? JourneyVisual.accentStrong : JourneyVisual.softBorder)
                        .frame(maxWidth: .infinity)
                        .frame(height: step == currentStep ? 4 : 3)
                }
            }
        }
        .padding(6)
        .background(Theme.Colors.card)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Крок %@ з %@: %@".localized(with: "\(currentStep.rawValue + 1)", "\(CVStep.allCases.count)", "\(currentStep.title)"))
    }
    
    // MARK: - Step 1: Personal
    private var personalStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                CVInputCard {
                    HStack {
                        Text("Про тебе".localized)
                            .font(.system(size: 17, weight: .bold, design: .default))
                            .foregroundColor(JourneyVisual.primaryText)
                        Spacer()
                        Text("Основне".localized)
                            .font(.system(size: 10, weight: .bold, design: .default))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(JourneyVisual.lime.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    cvPhotoPicker

                    CVInputField(
                        icon: "person.fill",
                        title: "Повне ім'я".localized,
                        placeholder: "Олена Коваленко".localized,
                        text: $cv.personal.fullName
                    )

                    CVInputField(
                        icon: "briefcase.fill",
                        title: "Бажана посада".localized,
                        placeholder: "Marketing Manager",
                        text: $cv.personal.title
                    )
                    
                    CVInputField(
                        icon: "mappin.circle.fill",
                        title: "Місто, %@".localized(with: "\(activeCountry.subdivisionTitle.lowercased())"),
                        placeholder: locationPlaceholder,
                        text: $cv.personal.location
                    )
                }

                CVInputCard {
                    HStack {
                        Text("Контакти".localized)
                            .font(.system(size: 17, weight: .bold, design: .default))
                            .foregroundColor(JourneyVisual.primaryText)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }

                    CVInputField(
                        icon: "envelope.fill",
                        title: "Email",
                        placeholder: "olena@email.com",
                        text: $cv.personal.email,
                        keyboard: .emailAddress
                    )
                    
                    CVInputField(
                        icon: "phone.fill",
                        title: "Телефон".localized,
                        placeholder: phonePlaceholder,
                        text: $cv.personal.phone,
                        keyboard: .phonePad,
                        focus: $isInputFocused
                    )
                }

                swissTip("%@ Для CV %@ перевір вимоги вакансії. З міркувань приватності адресу можна обмежити містом.".localized(with: "\(activeCountry.flag)", activeCountry.inCountryPhrase))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
    }

    private var cvPhotoPicker: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            HStack(spacing: 12) {
                Group {
                    if let data = selectedPhotoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                .frame(width: 48, height: 48)
                .background(JourneyVisual.lime.opacity(0.1))
                .clipShape(Circle())
                .overlay(Circle().stroke(JourneyVisual.lime.opacity(0.55), lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedPhotoData == nil ? "Додай фото профілю".localized : "Змінити фото".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                    Text("Необов’язково · фото не входить до ATS PDF".localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 66)
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(JourneyVisual.softBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedPhotoData == nil ? "Додати фото профілю".localized : "Змінити фото профілю".localized)
    }

    // MARK: - Step 2: Summary
    private var summaryStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "text.quote",
                    title: "Короткий профіль".localized,
                    subtitle: "2–4 речення про себе та ваші сильні сторони".localized
                )
                
                CVInputCard {
                    CVTextArea(
                        title: "Про мене".localized,
                        placeholder: "Наприклад:\nДосвідчений маркетолог з 5+ роками досвіду в digital-маркетингу. Спеціалізуюсь на B2B-кампаніях та аналітиці.".localized,
                        text: $cv.personal.summary,
                        minHeight: 100,
                        focus: $isInputFocused
                    )
                }
                
                // AI Enhancement Button
                aiEnhanceButton(for: "summary") {
                    await enhanceSummaryWithAI()
                }
                
                swissTip("🎯 Профіль має бути конкретним: вкажіть роки досвіду, ключову спеціалізацію та що ви шукаєте.".localized)
            }
            .padding(20)
        }
    }
    
    // MARK: - Step 3: Experience
    private var experienceStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "briefcase.fill",
                    title: "Досвід роботи".localized,
                    subtitle: "Останні 2–3 позиції з досягненнями".localized
                )
                
                ForEach($cv.experience.indices, id: \.self) { index in
                    CVInputCard {
                        CVInputField(icon: "building.2.fill", title: "Компанія".localized, placeholder: "Company AG", text: $cv.experience[index].company)
                        CVInputField(icon: "person.text.rectangle", title: "Посада".localized, placeholder: "Marketing Specialist", text: $cv.experience[index].role)
                        CVInputField(icon: "calendar", title: "Період".localized, placeholder: "01.2022 – 12.2024", text: $cv.experience[index].period)
                        CVInputField(icon: "mappin", title: "Місто".localized, placeholder: "Zürich", text: $cv.experience[index].location)
                        CVTextArea(
                            title: "Досягнення".localized,
                            placeholder: "• Збільшив конверсію на 25%%\n• Керував бюджетом 50K %@".localized(with: "\(activeCountry.currencyCode)"),
                            text: $cv.experience[index].achievements,
                            minHeight: 70,
                            focus: $isInputFocused
                        )
                        
                        // AI improve for this experience
                        aiEnhanceButton(for: "досвід".localized) {
                            await enhanceExperienceWithAI(at: index)
                        }
                    }
                }
                
                addButton(title: "Додати досвід".localized) {
                    cv.experience.append(CVExperience())
                }
                
                swissTip("📊 Роботодавці цінують конкретні цифри: %%, %@, кількість проєктів.".localized(with: "\(activeCountry.currencyCode)"))
            }
            .padding(20)
        }
    }
    
    // MARK: - Step 4: Education
    private var educationStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "graduationcap.fill",
                    title: "Освіта".localized,
                    subtitle: "Університети, курси, сертифікати".localized
                )
                
                ForEach($cv.education.indices, id: \.self) { index in
                    CVInputCard {
                        CVInputField(icon: "building.columns.fill", title: "Заклад".localized, placeholder: "Kyiv National University", text: $cv.education[index].school)
                        CVInputField(icon: "scroll.fill", title: "Ступінь / Спеціальність".localized, placeholder: "Bachelor of Economics", text: $cv.education[index].degree)
                        CVInputField(icon: "calendar", title: "Роки".localized, placeholder: "2016 – 2020", text: $cv.education[index].period)
                    }
                }
                
                addButton(title: "Додати освіту".localized) {
                    cv.education.append(CVEducation())
                }
                
                swissTip("🎓 Якщо диплом ще не визнаний %@, вкажи це та додай інформацію про процес визнання.".localized(with: activeCountry.inCountryPhrase))
            }
            .padding(20)
        }
    }
    
    // MARK: - Step 5: Skills & Languages
    private var skillsStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "star.fill",
                    title: "Навички та мови".localized,
                    subtitle: "Технічні навички та рівень мов".localized
                )
                
                // Skills
                CVInputCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Ключові навички".localized, systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(JourneyVisual.accentText)
                        
                        Text("Введіть через кому".localized)
                            .font(.caption)
                            .foregroundColor(JourneyVisual.secondaryText)
                        
                        TextField("Excel, SQL, Project Management...", text: Binding(
                            get: { cv.skills.joined(separator: ", ") },
                            set: { cv.skills = $0.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                        ))
                        .focused($isInputFocused)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textOnPrimary)
                        .padding(12)
                        .background(Theme.Colors.card)
                        .cornerRadius(12)
                    }
                }
                
                // Languages
                CVInputCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Мови".localized, systemImage: "globe")
                            .font(.subheadline.bold())
                            .foregroundColor(JourneyVisual.accentText)
                        
                        ForEach($cv.languages.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                TextField("Мова".localized, text: $cv.languages[index].name)
                                    .focused($isInputFocused)
                                    .font(.subheadline)
                                    .foregroundColor(JourneyVisual.primaryText)
                                    .padding(10)
                                    .background(Theme.Colors.card)
                                    .cornerRadius(10)
                                
                                Picker("Рівень".localized, selection: $cv.languages[index].level) {
                                    Text("A1").tag("A1")
                                    Text("A2").tag("A2")
                                    Text("B1").tag("B1")
                                    Text("B2").tag("B2")
                                    Text("C1").tag("C1")
                                    Text("C2").tag("C2")
                                    Text("Рідна".localized).tag("Рідна".localized)
                                }
                                .pickerStyle(.menu)
                                .tint(JourneyVisual.accentText)
                            }
                        }
                        
                        addButton(title: "Додати мову".localized) {
                            cv.languages.append(CVLanguage(name: "", level: "B1"))
                        }
                    }
                }
                
                swissTip("🗣 Німецька (DE) або французька (FR) — ключова перевага. Вказуйте рівень за CEFR (A1–C2).".localized)
            }
            .padding(20)
        }
    }
    
    // MARK: - Step 6: Preview
    private var previewStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "doc.text.magnifyingglass",
                    title: "Перегляд резюме".localized,
                    subtitle: "ATS PDF без фото або текст для онлайн-форми".localized
                )
                
                // Language Switch
                languageSwitcher
                
                // Translation status
                if isTranslating {
                    HStack {
                        ProgressView()
                            .tint(Theme.Colors.primary)
                        Text("Перекладаємо на німецьку...".localized)
                            .font(.caption)
                            .foregroundColor(JourneyVisual.secondaryText)
                    }
                    .padding()
                }
                
                if let error = translationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                Text("Німецька версія охоплює профіль, досвід, освіту, навички та мови. Після будь-якої зміни вихідного CV переклад оновлюється.".localized)
                    .font(.caption2)
                    .foregroundColor(JourneyVisual.secondaryText)
                
                // Generated CV preview
                cvPreviewCard
                
                // Action buttons
                if let exportError {
                    Text(exportError)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                VStack(spacing: 12) {
                    Button {
                        let resume = previewLanguage == .ukrainian ? cv : (germanCV ?? cv)
                        let text = CVDocumentFormatter().text(from: resume, language: documentLanguage)
                        UIPasteboard.general.string = text
                        copiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedFeedback = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                            Text(copiedFeedback ? "Скопійовано!".localized : "Копіювати для онлайн-форми".localized)
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.primary)
                        .foregroundColor(Theme.Colors.textOnPrimary)
                        .cornerRadius(14)
                    }
                    
                    Button {
                        requestPlusProtectedLocalAction {
                            exportATSPDF()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.richtext")
                            Text("Експортувати ATS PDF".localized)
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.card)
                        .foregroundColor(JourneyVisual.primaryText)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(JourneyVisual.softBorder, lineWidth: 1)
                        )
                    }
                }
                Text("PDF — для завантаження файлу роботодавцю. Одноколонковий макет без фото з виділюваним текстом.".localized)
                    .font(.caption)
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            .padding(20)
        }
    }
    
    // MARK: - Language Switcher
    private var languageSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(PreviewLanguage.allCases, id: \.self) { lang in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        previewLanguage = lang
                    }
                    
                    // Trigger translation if switching to German and no translation yet
                    if lang == .german && germanCV == nil && !isTranslating {
                        requestPlusProtectedAIAction {
                            Task { await translateToGerman() }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(lang.flag)
                        Text(lang.name)
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(previewLanguage == lang ? JourneyVisual.primaryText : JourneyVisual.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        previewLanguage == lang
                            ? Theme.Colors.primary.opacity(0.3)
                            : Color.clear
                    )
                }
            }
        }
        .background(Theme.Colors.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(JourneyVisual.softBorder, lineWidth: 1)
        )
    }
    
    private var cvPreviewCard: some View {
        let displayCV = previewLanguage == .ukrainian ? cv : (germanCV ?? cv)
        
        return VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(displayCV.personal.fullName.isEmpty ? "Ваше ім'я".localized : displayCV.personal.fullName)
                    .font(.title2.bold())
                    .foregroundColor(JourneyVisual.primaryText)
                
                if !displayCV.personal.title.isEmpty {
                    Text(displayCV.personal.title)
                        .font(.subheadline)
                        .foregroundColor(JourneyVisual.accentText)
                }
                
                let contacts = [displayCV.personal.location, displayCV.personal.phone, displayCV.personal.email].filter { !$0.isEmpty }
                if !contacts.isEmpty {
                    Text(contacts.joined(separator: " • "))
                        .font(.caption)
                        .foregroundColor(JourneyVisual.secondaryText)
                }
            }
            
            Divider().background(Theme.Colors.card)
            
            // Summary
            if !displayCV.personal.summary.isEmpty {
                cvSection(title: previewLanguage == .german ? "PROFIL" : "ПРО МЕНЕ".localized, content: displayCV.personal.summary)
            }
            
            // Experience
            if !displayCV.experience.isEmpty && displayCV.experience.contains(where: { !$0.company.isEmpty }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(previewLanguage == .german ? "BERUFSERFAHRUNG" : "ДОСВІД РОБОТИ".localized)
                        .font(.caption.bold())
                        .foregroundColor(JourneyVisual.accentText)
                    
                    ForEach(displayCV.experience.filter { !$0.company.isEmpty }) { exp in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(exp.role) — \(exp.company)")
                                .font(.subheadline.bold())
                                .foregroundColor(JourneyVisual.primaryText)
                            Text("\(exp.period) • \(exp.location)")
                                .font(.caption)
                                .foregroundColor(JourneyVisual.secondaryText)
                            if !exp.achievements.isEmpty {
                                Text(exp.achievements)
                                    .font(.caption)
                                    .foregroundColor(JourneyVisual.secondaryText)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
            
            // Education
            if !displayCV.education.isEmpty && displayCV.education.contains(where: { !$0.school.isEmpty }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(previewLanguage == .german ? "AUSBILDUNG" : "ОСВІТА".localized)
                        .font(.caption.bold())
                        .foregroundColor(JourneyVisual.accentText)
                    
                    ForEach(displayCV.education.filter { !$0.school.isEmpty }) { edu in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(edu.degree)
                                .font(.subheadline.bold())
                                .foregroundColor(JourneyVisual.primaryText)
                            Text("\(edu.school) • \(edu.period)")
                                .font(.caption)
                                .foregroundColor(JourneyVisual.secondaryText)
                        }
                    }
                }
            }
            
            // Skills
            if !displayCV.skills.isEmpty {
                cvSection(title: previewLanguage == .german ? "FÄHIGKEITEN" : "НАВИЧКИ".localized, content: displayCV.skills.joined(separator: " • "))
            }
            
            // Languages
            if !displayCV.languages.isEmpty && displayCV.languages.contains(where: { !$0.name.isEmpty }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(previewLanguage == .german ? "SPRACHEN" : "МОВИ".localized)
                        .font(.caption.bold())
                        .foregroundColor(JourneyVisual.accentText)
                    
                    Text(displayCV.languages.filter { !$0.name.isEmpty }.map { "\($0.name) — \($0.level)" }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(JourneyVisual.secondaryText)
                }
            }
        }
        .padding(20)
        .accessibilityIdentifier("cv.preview.card")
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(JourneyVisual.softBorder)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.Colors.primary.opacity(0.5), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func cvSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(JourneyVisual.accentText)
            Text(content)
                .font(.caption)
                .foregroundColor(JourneyVisual.secondaryText)
        }
    }
    
    // MARK: - AI Enhancement Button
    private func aiEnhanceButton(for section: String, action: @escaping () async -> Void) -> some View {
        VStack(spacing: 6) {
            Button {
                requestPlusProtectedAIAction { Task { await action() } }
            } label: {
                HStack(spacing: 8) {
                    if processingSection == section {
                        ProgressView()
                            .tint(.purple)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                    }

                    Text("Покращити з AI".localized)
                        .font(.caption.bold())
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            .disabled(isAIProcessing)
            .accessibilityIdentifier("cv.ai.\(section)")

            if let aiError {
                Text(aiError).font(.caption).foregroundColor(.red)
            } else if let aiSuccess {
                Text(aiSuccess).font(.caption).foregroundColor(Theme.Colors.textPrimary)
            }
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep != .personal {
                Button {
                    moveToPreviousStep()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .frame(width: 54, height: 54)
                        .background(Theme.Colors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(JourneyVisual.softBorder, lineWidth: 1)
                        )
                }
                .accessibilityLabel("Попередній крок".localized)
            }

            Button {
                if currentStep == .preview {
                    saveCV()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    saveCV()
                    moveToNextStep()
                }
            } label: {
                HStack {
                    Text(currentStep == .preview ? "Зберегти CV".localized : "Зберегти й продовжити".localized)
                    Spacer()
                    Image(systemName: currentStep == .preview ? "checkmark" : "arrow.right")
                }
                .font(.system(size: 15, weight: .bold, design: .default))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: JourneyVisual.lime.opacity(0.18), radius: 12, y: 5)
            }
            .accessibilityIdentifier("cv.navigation.next")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Theme.Colors.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(JourneyVisual.softBorder)
                .frame(height: 1)
        }
    }

    private func moveToPreviousStep() {
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.24)) {
            if let index = CVStep.allCases.firstIndex(of: currentStep), index > 0 {
                currentStep = CVStep.allCases[index - 1]
            }
        }
    }

    private func moveToNextStep() {
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.24)) {
            if let index = CVStep.allCases.firstIndex(of: currentStep), index < CVStep.allCases.count - 1 {
                currentStep = CVStep.allCases[index + 1]
            }
        }
    }
    
    // MARK: - Helper Views
    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.primary.opacity(0.3), Theme.Colors.primaryDark.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(JourneyVisual.accentStrong)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(JourneyVisual.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(JourneyVisual.secondaryText)
            }
            
            Spacer()
        }
    }
    
    private func swissTip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(JourneyVisual.accentStrong)
            Text(text)
                .font(.caption)
                .foregroundColor(JourneyVisual.secondaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.Colors.accent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Colors.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func addButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(title)
            }
            .font(.subheadline.bold())
            .foregroundColor(JourneyVisual.accentText)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.primary.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.Colors.primary.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Tips Sheet
    private var swissCVTipsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    tipItem(icon: "1.circle.fill", title: "Формат".localized, text: "Лаконічний CV: до 2 сторінок, чітка структура, без зайвої графіки.".localized)
                    tipItem(icon: "2.circle.fill", title: "Фото".localized, text: "Професійне фото бажане, але не обов'язкове. Якщо додаєте — діловий стиль.".localized)
                    tipItem(icon: "3.circle.fill", title: "Мови".localized, text: "Вказуйте рівень за CEFR (A1–C2). Німецька/французька — величезний плюс.".localized)
                    tipItem(icon: "4.circle.fill", title: "Досвід".localized, text: "Від найновішого до найстаршого. Конкретні цифри та досягнення.".localized)
                    tipItem(icon: "5.circle.fill", title: "Рекомендації".localized, text: "'Referenzen auf Anfrage' — рекомендації за запитом.".localized)
                    tipItem(icon: "6.circle.fill", title: "Актуальність".localized, text: "Перевір контакти, дати та відповідність CV конкретній вакансії перед відправленням.".localized)
                }
                .padding(20)
            }
            .background(Color.clear)
            .navigationTitle("CV · \(activeCountry.nativeName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово".localized) { showTips = false }
                        .foregroundColor(JourneyVisual.accentText)
                }
            }
        }
        .journeyScreen(.alpine, darkness: 0.72)
    }
    
    private func tipItem(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(JourneyVisual.accentStrong)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(JourneyVisual.primaryText)
                Text(text)
                    .font(.caption)
                    .foregroundColor(JourneyVisual.secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card)
        .cornerRadius(14)
    }
    
    // MARK: - AI & Translation Logic
    
    private func translateToGerman() async {
        guard !isTranslating else { return }
        
        isTranslating = true
        translationError = nil
        
        let source = cv
        do {
            let translated = try await APIClient.translateCVToGerman(resume: source)
            await MainActor.run {
                guard cv == source else {
                    translationError = "CV змінився під час перекладу. Запустіть переклад ще раз.".localized
                    isTranslating = false
                    return
                }
                germanCV = translated
                germanCVSource = source
                translationError = nil
                isTranslating = false
            }
        } catch {
            await MainActor.run {
                translationError = cvAIErrorMessage(error)
                previewLanguage = .ukrainian
                isTranslating = false
            }
        }
    }
    
    private func enhanceSummaryWithAI() async {
        isAIProcessing = true
        processingSection = "summary"
        aiError = nil
        
        do {
            // Ask backend AI helper to generate a Swiss-style summary.
            let improved = try await APIClient.generateCVText(resume: cv, target: .summary)
            await MainActor.run {
                cv.personal.summary = improved
                aiSuccess = "Профіль покращено без додавання нових фактів.".localized
                isAIProcessing = false
                processingSection = nil
            }
        } catch {
            await MainActor.run {
                aiError = cvAIErrorMessage(error)
                isAIProcessing = false
                processingSection = nil
            }
        }
    }
    
    private func enhanceExperienceWithAI(at index: Int) async {
        guard index < cv.experience.count else { return }
        
        isAIProcessing = true
        processingSection = "досвід".localized
        aiError = nil
        
        do {
            let exp = cv.experience[index]
            let improved = try await APIClient.generateCVText(resume: cv, target: .experience(id: exp.id))
            await MainActor.run {
                cv.experience[index].achievements = improved
                aiSuccess = "Досягнення оформлено у швейцарському стилі без нових фактів.".localized
                isAIProcessing = false
                processingSection = nil
            }
        } catch {
            await MainActor.run {
                aiError = cvAIErrorMessage(error)
                isAIProcessing = false
                processingSection = nil
            }
        }
    }
    
    private func requestPrivateAIAction(_ action: @escaping () -> Void) {
        dismissKeyboard()
        guard sessionManager.isAuthenticated else {
            showAuthPrompt = true
            return
        }
        guard UserDefaults.standard.bool(forKey: "cv_ai_privacy_disclosed") else {
            pendingPrivateAction = action
            showPrivacyDisclosure = true
            return
        }
        action()
    }

    private var cvPlusUsageKey: String {
        let identity = lockManager.userEmail.isEmpty ? "guest" : lockManager.userEmail.lowercased()
        return "cv_plus_free_actions_used_\(identity)"
    }

    private func requestPlusProtectedAIAction(_ action: @escaping () -> Void) {
        guard subscriptionManager.isPremium else {
            guard cvFreeActionsUsed < 3 else {
                showCVPlusGate = true
                APIClient.logPaywall(eventType: "view", context: SubscriptionSource.cv.rawValue)
                return
            }
            requestPrivateAIAction {
                consumeFreeCVAction()
                action()
            }
            return
        }
        requestPrivateAIAction(action)
    }

    private func requestPlusProtectedLocalAction(_ action: @escaping () -> Void) {
        guard subscriptionManager.isPremium else {
            guard cvFreeActionsUsed < 3 else {
                showCVPlusGate = true
                APIClient.logPaywall(eventType: "view", context: SubscriptionSource.cv.rawValue)
                return
            }
            consumeFreeCVAction()
            action()
            return
        }
        action()
    }

    private func consumeFreeCVAction() {
        cvFreeActionsUsed = min(3, cvFreeActionsUsed + 1)
        UserDefaults.standard.set(cvFreeActionsUsed, forKey: cvPlusUsageKey)
    }

    private func cvAIErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case 401: return "Сесія завершилась. Увійдіть знову.".localized
        case 402:
            cvFreeActionsUsed = 3
            UserDefaults.standard.set(3, forKey: cvPlusUsageKey)
            showCVPlusGate = true
            return "Безкоштовний ліміт використано. Відкрий Sweezy Plus для продовження.".localized
        case 422: return "Перевірте заповнені поля CV та спробуйте ще раз.".localized
        default:
            if nsError.domain == NSURLErrorDomain {
                return "Немає з’єднання. Перевірте інтернет і повторіть.".localized
            }
            return "Сервіс AI тимчасово недоступний. Спробуйте пізніше.".localized
        }
    }

    private func dismissKeyboard() {
        isInputFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var documentLanguage: CVDocumentLanguage {
        previewLanguage == .german ? .german : .ukrainian
    }

    private func exportATSPDF() {
        let resume = previewLanguage == .ukrainian ? cv : (germanCV ?? cv)
        let formatter = CVDocumentFormatter()
        do {
            let url = try PaginatedTextPDFExporter().export(
                text: formatter.text(from: resume, language: documentLanguage),
                filename: formatter.filename(for: resume, language: documentLanguage),
                title: "CV — \(resume.personal.fullName)"
            )
            exportError = nil
            saveCV()
            presentActivityVC(UIActivityViewController(activityItems: [url], applicationActivities: nil))
        } catch {
            exportError = "Не вдалося створити PDF. Перевірте, чи CV містить текст.".localized
        }
    }

    private func presentActivityVC(_ controller: UIActivityViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let presenter = scene.windows.first?.rootViewController else { return }
        presenter.present(controller, animated: true)
    }
    
    private func saveCV() {
        // Persist per user so that different accounts do not see each other's data
        guard !lockManager.userEmail.isEmpty else { return }
        if let data = try? JSONEncoder().encode(cv) {
            let key = "cv_saved_data_\(lockManager.userEmail.lowercased())"
            try? ProtectedLocalStore.write(data, for: key)
        }
    }

    private var cvPhotoURL: URL? {
        let identity = lockManager.userEmail.isEmpty ? "guest" : lockManager.userEmail.lowercased()
        let safeIdentity = identity.map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
        guard let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return supportURL
            .appendingPathComponent("CVPhotos", isDirectory: true)
            .appendingPathComponent("\(safeIdentity).jpg", isDirectory: false)
    }

    private func saveSelectedPhoto(_ data: Data) {
        guard data.count <= 8_000_000, let url = cvPhotoURL else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        ProtectedLocalStore.protectExistingFile(at: url)
    }

    private func loadSavedPhoto() {
        guard let url = cvPhotoURL else { return }
        selectedPhotoData = try? Data(contentsOf: url)
    }
    
    private func loadSavedCV() {
        var loaded = CVResume.empty
        if !lockManager.userEmail.isEmpty {
            let key = "cv_saved_data_\(lockManager.userEmail.lowercased())"
            if let data = ProtectedLocalStore.data(for: key, migratingFrom: key),
               let saved = try? JSONDecoder().decode(CVResume.self, from: data) {
                loaded = saved
            }
        }
        cv = loaded
        
        // Ensure at least one entry in arrays for initial UI
        if cv.experience.isEmpty { cv.experience.append(CVExperience()) }
        if cv.education.isEmpty { cv.education.append(CVEducation()) }
        if cv.languages.isEmpty { cv.languages.append(CVLanguage(name: "Українська".localized, level: "Рідна".localized)) }
    }
}

// MARK: - Reusable Input Components

private struct CVInputCard<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

private struct CVInputField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var focus: FocusState<Bool>.Binding?
    @FocusState private var localFocus: Bool
    
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(JourneyVisual.secondaryText)
                .frame(width: 34, height: 34)
                .background(Theme.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)

                TextField(placeholder, text: $text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(JourneyVisual.primaryText)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                    .autocorrectionDisabled(keyboard == .emailAddress)
                    .focused(focus ?? $localFocus)
                    .accessibilityIdentifier("cv.field.\(title)")
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 58)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(text.isEmpty ? Color.white.opacity(0.1) : JourneyVisual.lime.opacity(0.32), lineWidth: 1)
        )
    }
}

private struct CVTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    var focus: FocusState<Bool>.Binding
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(JourneyVisual.accentText.opacity(0.9))
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused(focus)
                    .accessibilityIdentifier("cv.textarea.\(title)")
                    .font(.subheadline)
                    .foregroundColor(JourneyVisual.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
                    .padding(10)
                    .background(Theme.Colors.card)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(JourneyVisual.softBorder, lineWidth: 1)
                    )
                
                if text.isEmpty {
                    Text(placeholder)
                        .font(.caption)
                        .foregroundColor(JourneyVisual.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
        }
            .featureOnboarding(.cvBuilder)
    }
}
