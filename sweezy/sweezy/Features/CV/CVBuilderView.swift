//
//  CVBuilderView.swift
//  sweezy
//
//  Professional CV Builder following Swiss standards.
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
    @State private var pendingPrivateAction: (() -> Void)?
    @FocusState private var isInputFocused: Bool
    
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
            case .ukrainian: return "Українська"
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
            case .personal: return "Особисті дані"
            case .summary: return "Профіль"
            case .experience: return "Досвід"
            case .education: return "Освіта"
            case .skills: return "Навички"
            case .preview: return "Перегляд"
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
                Color(red: 0.025, green: 0.03, blue: 0.028)
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
        .alert("Приватність CV", isPresented: $showPrivacyDisclosure) {
            Button("Скасувати", role: .cancel) { pendingPrivateAction = nil }
            Button("Продовжити") {
                UserDefaults.standard.set(true, forKey: "cv_ai_privacy_disclosed")
                let action = pendingPrivateAction
                pendingPrivateAction = nil
                action?()
            }
        } message: {
            Text("Лише після вашої дії текст CV надсилається захищеним з’єднанням для покращення або перекладу. Текст CV не журналюється і не зберігається на сервері.")
        }
        .onAppear {
            loadSavedCV()
            loadSavedPhoto()
            NotificationCenter.default.post(name: .setJourneyBottomBarHidden, object: true)
        }
        .onDisappear {
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
                Button("Готово") { dismissKeyboard() }
                    .accessibilityIdentifier("cv.keyboard.done")
            }
        }
        .preferredColorScheme(.dark)
        .featureOnboarding(.cvBuilder)
    }

    private var cvTopBar: some View {
        HStack(spacing: 12) {
            Button {
                closeScreen()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.42))
                    .background(.ultraThinMaterial.opacity(0.55))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel("Назад")
            .accessibilityIdentifier("cv.builder.back")

            Spacer()

            VStack(spacing: 2) {
                Text("CV Builder")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                Text("Крок \(currentStep.rawValue + 1) із \(CVStep.allCases.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
            }

            Spacer()

            Button {
                showTips = true
            } label: {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(JourneyVisual.lime)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.42))
                    .background(.ultraThinMaterial.opacity(0.55))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .accessibilityLabel("Поради для швейцарського CV")
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
            Image("cv-builder-hero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: isInputFocused ? 148 : 276)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.62),
                    Color(red: 0.025, green: 0.03, blue: 0.028)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            VStack(alignment: .leading, spacing: 10) {
                if !isInputFocused {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CV, який\nпомітять")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.55), radius: 8, y: 2)
                            .lineSpacing(-2)
                        Text("Заповни основні дані — ми допоможемо решту.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
                    }
                }
                progressBar
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(height: isInputFocused ? 148 : 276)
        .clipped()
        .animation(.easeInOut(duration: 0.2), value: isInputFocused)
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("\(currentStep.rawValue + 1)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 22, height: 22)
                    .background(JourneyVisual.lime)
                    .clipShape(Circle())
                Text(currentStep.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
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
                        .fill(step.rawValue <= currentStep.rawValue ? JourneyVisual.lime : Color.white.opacity(0.22))
                        .frame(maxWidth: .infinity)
                        .frame(height: step == currentStep ? 4 : 3)
                }
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.58))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Крок \(currentStep.rawValue + 1) з \(CVStep.allCases.count): \(currentStep.title)")
    }
    
    // MARK: - Step 1: Personal
    private var personalStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                CVInputCard {
                    HStack {
                        Text("Про тебе")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text("Основне")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(JourneyVisual.lime)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(JourneyVisual.lime.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    cvPhotoPicker

                    CVInputField(
                        icon: "person.fill",
                        title: "Повне ім'я",
                        placeholder: "Олена Коваленко",
                        text: $cv.personal.fullName
                    )

                    CVInputField(
                        icon: "briefcase.fill",
                        title: "Бажана посада",
                        placeholder: "Marketing Manager",
                        text: $cv.personal.title
                    )
                    
                    CVInputField(
                        icon: "mappin.circle.fill",
                        title: "Місто, кантон",
                        placeholder: "Zürich, ZH",
                        text: $cv.personal.location
                    )
                }

                CVInputCard {
                    HStack {
                        Text("Контакти")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(JourneyVisual.lime)
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
                        title: "Телефон",
                        placeholder: "+41 79 123 45 67",
                        text: $cv.personal.phone,
                        keyboard: .phonePad,
                        focus: $isInputFocused
                    )
                }

                swissTip("🇨🇭 У Швейцарії прийнято вказувати повну адресу та дату народження, але для приватності можна обмежитись містом.")
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
                            .foregroundColor(JourneyVisual.lime)
                    }
                }
                .frame(width: 48, height: 48)
                .background(JourneyVisual.lime.opacity(0.1))
                .clipShape(Circle())
                .overlay(Circle().stroke(JourneyVisual.lime.opacity(0.55), lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedPhotoData == nil ? "Додай фото профілю" : "Змінити фото")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Необов’язково · фото не входить до ATS PDF")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.34))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 66)
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedPhotoData == nil ? "Додати фото профілю" : "Змінити фото профілю")
    }

    // MARK: - Step 2: Summary
    private var summaryStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "text.quote",
                    title: "Короткий профіль",
                    subtitle: "2–4 речення про себе та ваші сильні сторони"
                )
                
                CVInputCard {
                    CVTextArea(
                        title: "Про мене",
                        placeholder: "Наприклад:\nДосвідчений маркетолог з 5+ роками досвіду в digital-маркетингу. Спеціалізуюсь на B2B-кампаніях та аналітиці.",
                        text: $cv.personal.summary,
                        minHeight: 100,
                        focus: $isInputFocused
                    )
                }
                
                // AI Enhancement Button
                aiEnhanceButton(for: "summary") {
                    await enhanceSummaryWithAI()
                }
                
                swissTip("🎯 Профіль має бути конкретним: вкажіть роки досвіду, ключову спеціалізацію та що ви шукаєте.")
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
                    title: "Досвід роботи",
                    subtitle: "Останні 2–3 позиції з досягненнями"
                )
                
                ForEach($cv.experience.indices, id: \.self) { index in
                    CVInputCard {
                        CVInputField(icon: "building.2.fill", title: "Компанія", placeholder: "Company AG", text: $cv.experience[index].company)
                        CVInputField(icon: "person.text.rectangle", title: "Посада", placeholder: "Marketing Specialist", text: $cv.experience[index].role)
                        CVInputField(icon: "calendar", title: "Період", placeholder: "01.2022 – 12.2024", text: $cv.experience[index].period)
                        CVInputField(icon: "mappin", title: "Місто", placeholder: "Zürich", text: $cv.experience[index].location)
                        CVTextArea(
                            title: "Досягнення",
                            placeholder: "• Збільшив конверсію на 25%\n• Керував бюджетом 50K CHF",
                            text: $cv.experience[index].achievements,
                            minHeight: 70,
                            focus: $isInputFocused
                        )
                        
                        // AI improve for this experience
                        aiEnhanceButton(for: "досвід") {
                            await enhanceExperienceWithAI(at: index)
                        }
                    }
                }
                
                addButton(title: "Додати досвід") {
                    cv.experience.append(CVExperience())
                }
                
                swissTip("📊 Швейцарські роботодавці цінують конкретні цифри: %, CHF, кількість проєктів.")
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
                    title: "Освіта",
                    subtitle: "Університети, курси, сертифікати"
                )
                
                ForEach($cv.education.indices, id: \.self) { index in
                    CVInputCard {
                        CVInputField(icon: "building.columns.fill", title: "Заклад", placeholder: "Kyiv National University", text: $cv.education[index].school)
                        CVInputField(icon: "scroll.fill", title: "Ступінь / Спеціальність", placeholder: "Bachelor of Economics", text: $cv.education[index].degree)
                        CVInputField(icon: "calendar", title: "Роки", placeholder: "2016 – 2020", text: $cv.education[index].period)
                    }
                }
                
                addButton(title: "Додати освіту") {
                    cv.education.append(CVEducation())
                }
                
                swissTip("🎓 Якщо ваш диплом ще не визнаний в Швейцарії, вкажіть це та додайте інформацію про процес визнання.")
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
                    title: "Навички та мови",
                    subtitle: "Технічні навички та рівень мов"
                )
                
                // Skills
                CVInputCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Ключові навички", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.Colors.primary)
                        
                        Text("Введіть через кому")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("Excel, SQL, Project Management...", text: Binding(
                            get: { cv.skills.joined(separator: ", ") },
                            set: { cv.skills = $0.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                        ))
                        .focused($isInputFocused)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textOnPrimary)
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                
                // Languages
                CVInputCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Мови", systemImage: "globe")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.Colors.primary)
                        
                        ForEach($cv.languages.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                TextField("Мова", text: $cv.languages[index].name)
                                    .focused($isInputFocused)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                
                                Picker("Рівень", selection: $cv.languages[index].level) {
                                    Text("A1").tag("A1")
                                    Text("A2").tag("A2")
                                    Text("B1").tag("B1")
                                    Text("B2").tag("B2")
                                    Text("C1").tag("C1")
                                    Text("C2").tag("C2")
                                    Text("Рідна").tag("Рідна")
                                }
                                .pickerStyle(.menu)
                                .tint(Theme.Colors.primary)
                            }
                        }
                        
                        addButton(title: "Додати мову") {
                            cv.languages.append(CVLanguage(name: "", level: "B1"))
                        }
                    }
                }
                
                swissTip("🗣 Німецька (DE) або французька (FR) — ключова перевага. Вказуйте рівень за CEFR (A1–C2).")
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
                    title: "Перегляд резюме",
                    subtitle: "ATS PDF без фото або текст для онлайн-форми"
                )
                
                // Language Switch
                languageSwitcher
                
                // Translation status
                if isTranslating {
                    HStack {
                        ProgressView()
                            .tint(Theme.Colors.primary)
                        Text("Перекладаємо на німецьку...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                }
                
                if let error = translationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                Text("Німецька версія охоплює профіль, досвід, освіту, навички та мови. Після будь-якої зміни вихідного CV переклад оновлюється.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                
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
                            Text(copiedFeedback ? "Скопійовано!" : "Копіювати для онлайн-форми")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.primary)
                        .foregroundColor(Theme.Colors.textOnPrimary)
                        .cornerRadius(14)
                    }
                    
                    Button {
                        exportATSPDF()
                    } label: {
                        HStack {
                            Image(systemName: "doc.richtext")
                            Text("Експортувати ATS PDF")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                Text("PDF — для завантаження файлу роботодавцю. Одноколонковий макет без фото з виділюваним текстом.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.58))
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
                        requestPrivateAIAction {
                            Task { await translateToGerman() }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(lang.flag)
                        Text(lang.name)
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(previewLanguage == lang ? .white : .white.opacity(0.5))
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
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var cvPreviewCard: some View {
        let displayCV = previewLanguage == .ukrainian ? cv : (germanCV ?? cv)
        
        return VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(displayCV.personal.fullName.isEmpty ? "Ваше ім'я" : displayCV.personal.fullName)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                if !displayCV.personal.title.isEmpty {
                    Text(displayCV.personal.title)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.primary)
                }
                
                let contacts = [displayCV.personal.location, displayCV.personal.phone, displayCV.personal.email].filter { !$0.isEmpty }
                if !contacts.isEmpty {
                    Text(contacts.joined(separator: " • "))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Summary
            if !displayCV.personal.summary.isEmpty {
                cvSection(title: previewLanguage == .german ? "PROFIL" : "ПРО МЕНЕ", content: displayCV.personal.summary)
            }
            
            // Experience
            if !displayCV.experience.isEmpty && displayCV.experience.contains(where: { !$0.company.isEmpty }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(previewLanguage == .german ? "BERUFSERFAHRUNG" : "ДОСВІД РОБОТИ")
                        .font(.caption.bold())
                        .foregroundColor(Theme.Colors.primary)
                    
                    ForEach(displayCV.experience.filter { !$0.company.isEmpty }) { exp in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(exp.role) — \(exp.company)")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("\(exp.period) • \(exp.location)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            if !exp.achievements.isEmpty {
                                Text(exp.achievements)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
            
            // Education
            if !displayCV.education.isEmpty && displayCV.education.contains(where: { !$0.school.isEmpty }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(previewLanguage == .german ? "AUSBILDUNG" : "ОСВІТА")
                        .font(.caption.bold())
                        .foregroundColor(Theme.Colors.primary)
                    
                    ForEach(displayCV.education.filter { !$0.school.isEmpty }) { edu in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(edu.degree)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("\(edu.school) • \(edu.period)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            
            // Skills
            if !displayCV.skills.isEmpty {
                cvSection(title: previewLanguage == .german ? "FÄHIGKEITEN" : "НАВИЧКИ", content: displayCV.skills.joined(separator: " • "))
            }
            
            // Languages
            if !displayCV.languages.isEmpty && displayCV.languages.contains(where: { !$0.name.isEmpty }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(previewLanguage == .german ? "SPRACHEN" : "МОВИ")
                        .font(.caption.bold())
                        .foregroundColor(Theme.Colors.primary)
                    
                    Text(displayCV.languages.filter { !$0.name.isEmpty }.map { "\($0.name) — \($0.level)" }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(20)
        .accessibilityIdentifier("cv.preview.card")
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
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
                .foregroundColor(Theme.Colors.primary)
            Text(content)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - AI Enhancement Button
    private func aiEnhanceButton(for section: String, action: @escaping () async -> Void) -> some View {
        VStack(spacing: 6) {
            Button {
                requestPrivateAIAction { Task { await action() } }
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

                    Text("Покращити з AI")
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
                Text(aiSuccess).font(.caption).foregroundColor(JourneyVisual.lime)
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
                        .foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Попередній крок")
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
                    Text(currentStep == .preview ? "Зберегти CV" : "Зберегти й продовжити")
                    Spacer()
                    Image(systemName: currentStep == .preview ? "checkmark" : "arrow.right")
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
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
        .background(Color.black.opacity(0.96))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
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
                    .foregroundColor(Theme.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
    
    private func swissTip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(Theme.Colors.accent)
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
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
            .foregroundColor(Theme.Colors.primary)
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
                    tipItem(icon: "1.circle.fill", title: "Формат", text: "Стандартний швейцарський CV — 2 сторінки максимум. Чіткий, без зайвої графіки.")
                    tipItem(icon: "2.circle.fill", title: "Фото", text: "Професійне фото бажане, але не обов'язкове. Якщо додаєте — діловий стиль.")
                    tipItem(icon: "3.circle.fill", title: "Мови", text: "Вказуйте рівень за CEFR (A1–C2). Німецька/французька — величезний плюс.")
                    tipItem(icon: "4.circle.fill", title: "Досвід", text: "Від найновішого до найстаршого. Конкретні цифри та досягнення.")
                    tipItem(icon: "5.circle.fill", title: "Рекомендації", text: "'Referenzen auf Anfrage' — рекомендації за запитом.")
                    tipItem(icon: "6.circle.fill", title: "Дата", text: "У Швейцарії прийнято вказувати дату оновлення CV внизу.")
                }
                .padding(20)
            }
            .background(Color.clear)
            .navigationTitle("Швейцарські стандарти CV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { showTips = false }
                        .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .journeyScreen(.alpine, darkness: 0.72)
    }
    
    private func tipItem(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(text)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
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
                    translationError = "CV змінився під час перекладу. Запустіть переклад ще раз."
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
                aiSuccess = "Профіль покращено без додавання нових фактів."
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
        processingSection = "досвід"
        aiError = nil
        
        do {
            let exp = cv.experience[index]
            let improved = try await APIClient.generateCVText(resume: cv, target: .experience(id: exp.id))
            await MainActor.run {
                cv.experience[index].achievements = improved
                aiSuccess = "Досягнення оформлено у швейцарському стилі без нових фактів."
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

    private func cvAIErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case 401: return "Сесія завершилась. Увійдіть знову."
        case 402: return "Ця AI-функція тимчасово обмежена. Спробуйте пізніше."
        case 422: return "Перевірте заповнені поля CV та спробуйте ще раз."
        default:
            if nsError.domain == NSURLErrorDomain {
                return "Немає з’єднання. Перевірте інтернет і повторіть."
            }
            return "Сервіс AI тимчасово недоступний. Спробуйте пізніше."
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
            exportError = "Не вдалося створити PDF. Перевірте, чи CV містить текст."
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
        if cv.languages.isEmpty { cv.languages.append(CVLanguage(name: "Українська", level: "Рідна")) }
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
                    .fill(Color(red: 0.075, green: 0.082, blue: 0.078).opacity(0.98))
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
            .shadow(color: .black.opacity(0.2), radius: 12, y: 7)
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
                .foregroundColor(.white.opacity(0.74))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.52))

                TextField(placeholder, text: $text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                    .autocorrectionDisabled(keyboard == .emailAddress)
                    .focused(focus ?? $localFocus)
                    .accessibilityIdentifier("cv.field.\(title)")
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 58)
        .background(Color.white.opacity(0.035))
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
                .foregroundColor(Theme.Colors.primary.opacity(0.9))
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused(focus)
                    .accessibilityIdentifier("cv.textarea.\(title)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                if text.isEmpty {
                    Text(placeholder)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
        }
            .featureOnboarding(.cvBuilder)
    }
}
