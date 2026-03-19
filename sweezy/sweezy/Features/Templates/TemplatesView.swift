//
//  TemplatesView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var accountManager: AccountManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: TemplateCategory?
    @State private var searchText: String = ""
    
    private var filteredTemplates: [DocumentTemplate] {
        let templates = appContainer.contentService.getTemplatesForLocale(appContainer.currentLocale.identifier)
        
        let byCategory = selectedCategory == nil ? templates : templates.filter { $0.category == selectedCategory }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bySearch = trimmed.isEmpty ? byCategory : byCategory.filter { $0.title.localizedCaseInsensitiveContains(trimmed) || $0.description.localizedCaseInsensitiveContains(trimmed) }
        return bySearch.sorted { $0.title < $1.title }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdaptivePageBackground()
                
                VStack(spacing: 0) {
                    headerSection

                    searchSection
                    categoryFiltersSection
                
                    contentSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .task {
                if appContainer.contentService.templates.isEmpty {
                    await appContainer.contentService.refreshContent()
                }
            }
            .featureOnboarding(.templates)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("📄")
                            .font(.title2)
                        Text("Шаблони документів")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("Готові шаблони для швейцарських документів")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.secondaryText)
                
                TextField("Пошук шаблонів...", text: $searchText)
                    .foregroundColor(Theme.Colors.primaryText)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Colors.tertiaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.clear, lineWidth: 1)
            )
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
    
    // MARK: - Category Filters
    private var categoryFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                TemplateCategoryChip(
                    title: "Усі",
                    isSelected: selectedCategory == nil,
                    icon: "doc.on.doc"
                ) {
                    selectedCategory = nil
                }
                
                ForEach(TemplateCategory.allCases, id: \.self) { category in
                    TemplateCategoryChip(
                        title: category.localizedName,
                        isSelected: selectedCategory == category,
                        icon: category.iconName
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        Group {
            if appContainer.contentService.isLoading {
                loadingView
            } else if filteredTemplates.isEmpty {
                emptyStateView
            } else {
                // Public (non-account-based) content must be accessible without login (App Store 5.1.1).
                templatesListSection
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(0..<3, id: \.self) { idx in
                TemplateShimmerView()
                    .padding(.horizontal, Theme.Spacing.md)
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.md)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            VStack(spacing: Theme.Spacing.sm) {
                Text("Шаблони не знайдено")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text("Спробуйте змінити фільтри")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Button(action: { selectedCategory = nil; searchText = "" }) {
                Text("Скинути фільтри")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.Colors.accent)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var lockOverlay: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.accent)
            
            Text("Зареєструйтесь для доступу")
                .font(.headline)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text("Шаблони доступні для зареєстрованих користувачів")
                .font(.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.5))
        )
        .padding(Theme.Spacing.xl)
    }
    
    private var templatesListSection: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(filteredTemplates) { template in
                    NavigationLink(destination: TemplateDetailView(template: template)) {
                        TemplateCardView(template: template)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Category Chip
struct TemplateCategoryChip: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        Theme.Colors.accent
                    } else {
                        Theme.Colors.tertiaryBackground
                    }
                }
            )
            .foregroundColor(
                isSelected
                    ? .white
                    : Theme.Colors.primaryText
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected
                            ? Color.clear
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Template Card View
struct TemplateCardView: View {
    let template: DocumentTemplate
    
    var body: some View {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(template.category.swiftUIColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: template.category.iconName)
                        .font(.title3)
                        .foregroundColor(template.category.swiftUIColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                        Text(template.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                            .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        
                        Text(template.description)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            
            // Tags row
            HStack(spacing: 8) {
                TagPill(text: template.category.localizedName, color: template.category.swiftUIColor)
                TagPill(text: template.templateType.localizedName, color: .purple)
                    
                    Spacer()
                    
                    if template.isOfficial {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                        Text("Офіційний")
                            .font(.caption2.weight(.medium))
                        }
                        .foregroundColor(.green)
                    }
                }
            }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.card)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Tag Pill
struct TagPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                color.opacity(0.15)
            )
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

// MARK: - Template Detail View (Redesigned)
struct TemplateDetailView: View {
    let template: DocumentTemplate
    @EnvironmentObject private var appContainer: AppContainer
    @State private var fieldValues: [String: String] = [:]
    @State private var showingPreview = false
    @State private var isGenerating = false
    
    var body: some View {
        ZStack {
            Theme.Colors.primaryBackground.ignoresSafeArea()
            
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    templateHeaderCard
                
                    formSection
                
                    generateButton
                    
                    Spacer(minLength: 100)
            }
            .padding(Theme.Spacing.md)
            }
        }
        .navigationTitle(template.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPreview) {
            DocumentPreviewView(
                baseTemplate: template,
                templatesGroup: groupTemplates,
                fieldValues: fieldValues
            )
        }
        .onAppear {
            initializeFieldValues()
        }
    }
    
    // MARK: - Header Card
    private var templateHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(template.category.swiftUIColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: template.category.iconName)
                        .font(.title2)
                        .foregroundColor(template.category.swiftUIColor)
                }
                
                Spacer()
                
                if template.isOfficial {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Офіційний")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                }
            }
            
            Text(template.description)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
            
            HStack(spacing: 8) {
                TagPill(text: template.category.localizedName, color: template.category.swiftUIColor)
                TagPill(text: template.templateType.localizedName, color: .purple)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.card)
        )
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Заповніть форму")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.Colors.primaryText)
            }
            
            VStack(spacing: Theme.Spacing.md) {
                ForEach(template.placeholders.sorted { $0.order < $1.order }) { placeholder in
                    TemplateFieldView(
                        placeholder: placeholder,
                        value: Binding(
                            get: { fieldValues[placeholder.id] ?? "" },
                            set: { fieldValues[placeholder.id] = $0 }
                        )
                    )
                }
            }
        }
    }
    
    // MARK: - Generate Button
    private var generateButton: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button(action: {
                isGenerating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    generateDocument()
                    isGenerating = false
                }
            }) {
                HStack(spacing: 10) {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "doc.badge.plus")
                        Text("Створити документ")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if allRequiredFieldsFilled {
                            Theme.Colors.accent
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                )
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!allRequiredFieldsFilled || isGenerating)
            
            if !allRequiredFieldsFilled {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                    Text("Обов'язкове поле")
                        .font(.caption)
                }
                .foregroundColor(.red.opacity(0.8))
            }
        }
    }
    
    private var allRequiredFieldsFilled: Bool {
        template.hasAllRequiredFields(values: fieldValues)
    }
    
    private func initializeFieldValues() {
        for placeholder in template.placeholders {
            if fieldValues[placeholder.id] == nil {
                fieldValues[placeholder.id] = placeholder.defaultValue ?? ""
            }
        }
    }
    
    private func generateDocument() {
        showingPreview = true
    }
    
    // MARK: - Template group helpers
    private var groupTemplates: [DocumentTemplate] {
        guard let groupTag = template.tags.first(where: { $0.hasPrefix("group:") }) else {
            return [template]
        }
        let all = appContainer.contentService.templates.filter { $0.tags.contains(groupTag) }
        if all.isEmpty {
            return [template]
        }
        return all
    }
}

// MARK: - Template Field View
struct TemplateFieldView: View {
    let placeholder: TemplatePlaceholder
    @Binding var value: String
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
    
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(placeholder.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.Colors.primaryText)
                
                if placeholder.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.subheadline.weight(.bold))
                }
            }
            
            if let description = placeholder.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            
            fieldInput
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.tertiaryBackground)
        )
    }
    
    @ViewBuilder
    private var fieldInput: some View {
                switch placeholder.type {
                case .text:
            styledTextField(placeholder: "Введіть \(placeholder.label.lowercased())")
                
                case .multilineText:
            styledTextField(placeholder: "Введіть \(placeholder.label.lowercased())", isMultiline: true)
                
                case .email:
            styledTextField(placeholder: "Введіть email", keyboardType: .emailAddress)
                
                case .phone:
            styledTextField(placeholder: "Введіть номер телефону", keyboardType: .phonePad)
                
                case .number:
            styledTextField(placeholder: "Введіть число", keyboardType: .numberPad)
                
                case .date:
            styledDatePicker
                
                case .dropdown:
                    if let options = placeholder.options {
                styledDropdown(options: options)
                    }
                
                case .checkbox:
            styledToggle
                
                default:
            styledTextField(placeholder: "Введіть \(placeholder.label.lowercased())")
        }
    }
    
    private func styledTextField(placeholder placeholderText: String, keyboardType: UIKeyboardType = .default, isMultiline: Bool = false) -> some View {
        Group {
            if isMultiline {
                TextField(placeholderText, text: $value, axis: .vertical)
                    .lineLimit(3...6)
            } else {
                TextField(placeholderText, text: $value)
            }
        }
        .keyboardType(keyboardType)
        .autocapitalization(keyboardType == .emailAddress ? .none : .sentences)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .foregroundColor(Theme.Colors.primaryText)
    }
    
    private var styledDatePicker: some View {
        DatePicker("", selection: Binding(
            get: { Self.iso8601Formatter.date(from: value) ?? Date() },
            set: { value = Self.iso8601Formatter.string(from: $0) }
        ), displayedComponents: .date)
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(Theme.Colors.accent)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func styledDropdown(options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    value = option
                }
            }
        } label: {
            HStack {
                Text(value.isEmpty ? "Оберіть..." : value)
                    .foregroundColor(value.isEmpty
                        ? Theme.Colors.tertiaryText
                        : Theme.Colors.primaryText)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var styledToggle: some View {
        Toggle(isOn: Binding(
            get: { value == "true" },
            set: { value = $0 ? "true" : "false" }
        )) {
            EmptyView()
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
    }
}

// MARK: - Document Preview View (Redesigned)
struct DocumentPreviewView: View {
    let baseTemplate: DocumentTemplate
    let templatesGroup: [DocumentTemplate]
    let fieldValues: [String: String]
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var selectedLanguage: String
    
    init(baseTemplate: DocumentTemplate, templatesGroup: [DocumentTemplate], fieldValues: [String: String]) {
        self.baseTemplate = baseTemplate
        self.templatesGroup = templatesGroup
        self.fieldValues = fieldValues
        _selectedLanguage = State(initialValue: baseTemplate.language)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.primaryBackground.ignoresSafeArea()
                
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        if availableLanguages.count > 1 {
                            HStack(spacing: 8) {
                                Text("Мова листа")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                
                                Spacer()
                                
                                Picker("", selection: $selectedLanguage) {
                                    ForEach(availableLanguages, id: \.self) { code in
                                        Text(languageDisplayName(for: code))
                                            .tag(code)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 240)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                        
                        Text(generatedContent)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Theme.Colors.primaryText)
                            .padding(Theme.Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                            )
                        
                        Spacer(minLength: 100)
                    }
                        .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Попередній перегляд")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Копіювати")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.Colors.accent)
                    }
                    
                    Button(action: shareDocument) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Експорт")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
        }
    }
    
    // MARK: - Derived content
    private var availableLanguages: [String] {
        let codes = Set(templatesGroup.map { $0.language })
        return Array(codes).sorted()
    }
    
    private var currentTemplate: DocumentTemplate {
        if let match = templatesGroup.first(where: { $0.language.lowercased() == selectedLanguage.lowercased() }) {
            return match
        }
        return baseTemplate
    }
    
    private var generatedContent: String {
        currentTemplate.generateContent(with: fieldValues)
    }
    
    private func languageDisplayName(for code: String) -> String {
        switch code.lowercased() {
        case "uk": return "Українська"
        case "de": return "Deutsch"
        case "en": return "English"
        default: return code.uppercased()
        }
    }
    
    // MARK: - Actions
    private func copyToClipboard() {
        UIPasteboard.general.string = generatedContent
    }
    
    private func shareDocument() {
        guard let pdfURL = createPDF(from: generatedContent, title: currentTemplate.title) else {
            let activityVC = UIActivityViewController(
                activityItems: [generatedContent],
                applicationActivities: nil
            )
            presentActivityVC(activityVC)
            return
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [pdfURL],
            applicationActivities: nil
        )
        presentActivityVC(activityVC)
    }
    
    private func createPDF(from text: String, title: String) -> URL? {
        let pdfMetaData = [
            kCGPDFContextTitle: title,
            kCGPDFContextCreator: "Sweezy App"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).pdf")
        
        do {
            try renderer.writePDF(to: tempURL) { context in
                context.beginPage()
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12)
                ]
                let textRect = CGRect(x: 40, y: 40, width: pageWidth - 80, height: pageHeight - 80)
                text.draw(in: textRect, withAttributes: attributes)
            }
            return tempURL
        } catch {
            print("❌ Failed to create PDF: \(error)")
            return nil
        }
    }
    
    private func presentActivityVC(_ activityVC: UIActivityViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Template Shimmer View
struct TemplateShimmerView: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 14)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.3),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
                .rotationEffect(.degrees(30))
                .offset(x: animate ? 400 : -400)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// MARK: - Template Shimmer Row (Legacy support)
struct TemplateShimmerRow: View {
    var body: some View {
        TemplateShimmerView()
    }
}

// MARK: - Template Card (Legacy support)
struct TemplateCard: View {
    let template: DocumentTemplate
    
    var body: some View {
        TemplateCardView(template: template)
    }
}

#Preview {
    TemplatesView()
        .environmentObject(AppContainer())
        .environmentObject(AppLockManager())
        .environmentObject(AccountManager())
}
