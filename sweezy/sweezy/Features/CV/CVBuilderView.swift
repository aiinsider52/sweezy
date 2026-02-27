//
//  CVBuilderView.swift
//  sweezy
//
//  Professional CV Builder following Swiss standards.
//  Features: step-by-step wizard, DE translation, AI enhancement.
//

import SwiftUI
import UIKit

struct CVBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    
    // Step-by-step navigation
    @State private var currentStep: CVStep = .personal
    
    // CV Data
    @State private var cv = CVResume.empty
    
    // Translation
    @State private var previewLanguage: PreviewLanguage = .ukrainian
    @State private var germanCV: CVResume?
    @State private var isTranslating = false
    @State private var translationError: String?
    
    // AI Enhancement
    @State private var isAIProcessing = false
    @State private var aiError: String?
    
    // UI State
    @State private var showTips = false
    @State private var copiedFeedback = false
    
    // TEMPORARY (App Store review): IAP removed — everything is unlocked.
    
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
    
    private let hasPremiumAccess: Bool = true
    private let hasAIAccess: Bool = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Winter background
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.08, blue: 0.16),
                        Color(red: 0.06, green: 0.12, blue: 0.22),
                        Color(red: 0.05, green: 0.1, blue: 0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressBar
                    
                    // Content
                    TabView(selection: $currentStep) {
                        personalStepView.tag(CVStep.personal)
                        summaryStepView.tag(CVStep.summary)
                        experienceStepView.tag(CVStep.experience)
                        educationStepView.tag(CVStep.education)
                        skillsStepView.tag(CVStep.skills)
                        previewStepView.tag(CVStep.preview)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                    
                    // Navigation buttons
                    navigationButtons
                }
            }
            .navigationTitle("CV Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрити") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showTips.toggle()
                    } label: {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                    }
                }
            }
            .sheet(isPresented: $showTips) {
                swissCVTipsSheet
            }
            .onAppear {
                loadSavedCV()
                // TEMPORARY: no subscription/entitlement refresh in this build.
            }
        }
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(CVStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 6) {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.cyan : Color.white.opacity(0.2))
                        .frame(width: step == currentStep ? 12 : 8, height: step == currentStep ? 12 : 8)
                        .overlay(
                            Circle()
                                .stroke(Color.cyan.opacity(0.5), lineWidth: step == currentStep ? 2 : 0)
                                .frame(width: 16, height: 16)
                        )
                    
                    if step == currentStep {
                        Text(step.title)
                            .font(.caption2.bold())
                            .foregroundColor(.cyan)
                    }
                }
                
                if step != CVStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color.cyan : Color.white.opacity(0.15))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Step 1: Personal
    private var personalStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "person.crop.circle.fill",
                    title: "Особисті дані",
                    subtitle: "Базова інформація для зв'язку"
                )
                
                CVInputCard {
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
                        keyboard: .phonePad
                    )
                }
                
                swissTip("🇨🇭 У Швейцарії прийнято вказувати повну адресу та дату народження, але для приватності можна обмежитись містом.")
            }
            .padding(20)
        }
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
                        minHeight: 100
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
                            minHeight: 70
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
                            .foregroundColor(.cyan)
                        
                        Text("Введіть через кому")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("Excel, SQL, Project Management...", text: Binding(
                            get: { cv.skills.joined(separator: ", ") },
                            set: { cv.skills = $0.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                        ))
                        .font(.subheadline)
                        .foregroundColor(.white)
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
                            .foregroundColor(.cyan)
                        
                        ForEach($cv.languages.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                TextField("Мова", text: $cv.languages[index].name)
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
                                .tint(.cyan)
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
                    subtitle: "Перевірте, перекладіть та скопіюйте"
                )
                
                // Language Switch
                languageSwitcher
                
                // Translation status
                if isTranslating {
                    HStack {
                        ProgressView()
                            .tint(.cyan)
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
                
                // Generated CV preview
                cvPreviewCard
                
                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        let text = previewLanguage == .ukrainian ? generateCVText(from: cv) : generateCVText(from: germanCV ?? cv)
                        UIPasteboard.general.string = text
                        copiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedFeedback = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                            Text(copiedFeedback ? "Скопійовано!" : "Копіювати")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cyan)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    
                    Button {
                        saveCV()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Зберегти")
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
                        Task {
                            await translateToGerman()
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
                            ? Color.cyan.opacity(0.3)
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
                        .foregroundColor(.cyan)
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
                        .foregroundColor(.cyan)
                    
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
                        .foregroundColor(.cyan)
                    
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
                        .foregroundColor(.cyan)
                    
                    Text(displayCV.languages.filter { !$0.name.isEmpty }.map { "\($0.name) — \($0.level)" }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.5), Color.white.opacity(0.1)],
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
                .foregroundColor(.cyan)
            Text(content)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - AI Enhancement Button
    private func aiEnhanceButton(for section: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 8) {
                if isAIProcessing {
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
    }
    
    // MARK: - Premium Prompt Sheet (removed)
    // TEMPORARY (App Store review): IAP removed, so there is no premium upsell UI.
    private var premiumPromptSheet: some View { EmptyView() }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep != .personal {
                Button {
                    withAnimation {
                        if let idx = CVStep.allCases.firstIndex(of: currentStep), idx > 0 {
                            currentStep = CVStep.allCases[idx - 1]
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Назад")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(14)
                }
            }
            
            Spacer()
            
            if currentStep != .preview {
                Button {
                    withAnimation {
                        if let idx = CVStep.allCases.firstIndex(of: currentStep), idx < CVStep.allCases.count - 1 {
                            currentStep = CVStep.allCases[idx + 1]
                        }
                    }
                } label: {
                    HStack {
                        Text("Далі")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: .cyan.opacity(0.4), radius: 8, y: 4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.4))
    }
    
    // MARK: - Helper Views
    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.cyan)
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
                .foregroundColor(.yellow)
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
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
            .foregroundColor(.cyan)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.cyan.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
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
            .background(Color(red: 0.05, green: 0.1, blue: 0.18).ignoresSafeArea())
            .navigationTitle("Швейцарські стандарти CV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { showTips = false }
                        .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private func tipItem(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.cyan)
            
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
        
        do {
            // Use backend AI / deterministic translation via API
            // For now we generate a DE-style version of the summary and experience text using the same CV payload.
            // If backend translation is not available, we gracefully fall back to original content.
            var translated = cv
            
            // Translate summary by asking backend to re-generate it in German (if possible)
            if !cv.personal.summary.isEmpty {
                if let deSummary = try? await APIClient.generateCVText(resume: cv, target: .summary) {
                    translated.personal.summary = deSummary
                }
            }
            
            // Experience: reuse backend generator per experience entry when possible
            for i in cv.experience.indices {
                let exp = cv.experience[i]
                guard !exp.achievements.isEmpty else { continue }
                if let text = try? await APIClient.generateCVText(resume: cv, target: .experience(id: exp.id)) {
                    translated.experience[i].achievements = text
                }
            }
            
            await MainActor.run {
                germanCV = translated
                isTranslating = false
            }
        } catch {
            await MainActor.run {
                translationError = "Помилка перекладу. Спробуйте пізніше."
                isTranslating = false
            }
        }
    }
    
    private func enhanceSummaryWithAI() async {
        guard hasAIAccess else { return }
        
        isAIProcessing = true
        aiError = nil
        
        do {
            // Ask backend AI helper to generate a Swiss-style summary.
            let improved = try await APIClient.generateCVText(resume: cv, target: .summary)
            await MainActor.run {
                cv.personal.summary = improved
                isAIProcessing = false
            }
        } catch {
            await MainActor.run {
                aiError = "Помилка AI. Спробуйте пізніше."
                isAIProcessing = false
            }
        }
    }
    
    private func enhanceExperienceWithAI(at index: Int) async {
        guard hasAIAccess, index < cv.experience.count else { return }
        
        isAIProcessing = true
        aiError = nil
        
        do {
            let exp = cv.experience[index]
            let improved = try await APIClient.generateCVText(resume: cv, target: .experience(id: exp.id))
            await MainActor.run {
                cv.experience[index].achievements = improved
                isAIProcessing = false
            }
        } catch {
            await MainActor.run {
                aiError = "Помилка AI. Спробуйте пізніше."
                isAIProcessing = false
            }
        }
    }
    
    // TEMPORARY: subscription/entitlement code removed.
    
    // MARK: - CV Text Generation
    private func generateCVText(from resume: CVResume) -> String {
        var lines: [String] = []
        
        lines.append(resume.personal.fullName)
        if !resume.personal.title.isEmpty { lines.append(resume.personal.title) }
        
        let contacts = [resume.personal.location, resume.personal.phone, resume.personal.email].filter { !$0.isEmpty }
        if !contacts.isEmpty { lines.append(contacts.joined(separator: " • ")) }
        lines.append("")
        
        if !resume.personal.summary.isEmpty {
            lines.append(previewLanguage == .german ? "PROFIL" : "ПРО МЕНЕ")
            lines.append(resume.personal.summary)
            lines.append("")
        }
        
        let validExperience = resume.experience.filter { !$0.company.isEmpty }
        if !validExperience.isEmpty {
            lines.append(previewLanguage == .german ? "BERUFSERFAHRUNG" : "ДОСВІД РОБОТИ")
            for exp in validExperience {
                lines.append("\(exp.period) — \(exp.role), \(exp.company), \(exp.location)")
                if !exp.achievements.isEmpty { lines.append(exp.achievements) }
            }
            lines.append("")
        }
        
        let validEducation = resume.education.filter { !$0.school.isEmpty }
        if !validEducation.isEmpty {
            lines.append(previewLanguage == .german ? "AUSBILDUNG" : "ОСВІТА")
            for edu in validEducation {
                lines.append("\(edu.period) — \(edu.degree), \(edu.school)")
            }
            lines.append("")
        }
        
        if !resume.skills.isEmpty {
            lines.append(previewLanguage == .german ? "FÄHIGKEITEN" : "НАВИЧКИ")
            lines.append(resume.skills.joined(separator: ", "))
            lines.append("")
        }
        
        let validLanguages = resume.languages.filter { !$0.name.isEmpty }
        if !validLanguages.isEmpty {
            lines.append(previewLanguage == .german ? "SPRACHEN" : "МОВИ")
            lines.append(validLanguages.map { "\($0.name): \($0.level)" }.joined(separator: ", "))
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func saveCV() {
        // Persist per user so that different accounts do not see each other's data
        guard !lockManager.userEmail.isEmpty else { return }
        if let data = try? JSONEncoder().encode(cv) {
            let key = "cv_saved_data_\(lockManager.userEmail.lowercased())"
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func loadSavedCV() {
        var loaded = CVResume.empty
        if !lockManager.userEmail.isEmpty {
            let key = "cv_saved_data_\(lockManager.userEmail.lowercased())"
            if let data = UserDefaults.standard.data(forKey: key),
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
        VStack(spacing: 12, content: content)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundColor(.cyan.opacity(0.9))
            
            TextField(placeholder, text: $text)
                .font(.subheadline)
                .foregroundColor(.white)
                .keyboardType(keyboard)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

private struct CVTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.cyan.opacity(0.9))
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
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
