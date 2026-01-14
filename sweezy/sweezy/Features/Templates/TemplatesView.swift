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
                // Winter gradient background (always festive)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.2),
                        Color(red: 0.08, green: 0.15, blue: 0.28),
                        Color(red: 0.06, green: 0.12, blue: 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Subtle snowfall
                WinterSceneLite(intensity: .light)
                
                VStack(spacing: 0) {
                    // Header with winter decoration
                    headerSection

                // Search + Category filters
                    searchSection
                categoryFiltersSection
                
                    // Content
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
        }
    }
    
    // MARK: - Header Section (Winter styled)
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
                
                // Winter decoration
                if true {
                    Text("❄️")
                        .font(.title)
                        .opacity(0.8)
                }
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
                    .foregroundColor(WinterTheme.isActive ? .cyan.opacity(0.7) : Theme.Colors.secondaryText)
                
                TextField("Пошук шаблонів...", text: $searchText)
                    .foregroundColor(WinterTheme.isActive ? .white : Theme.Colors.primaryText)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(WinterTheme.isActive ? .white.opacity(0.5) : Theme.Colors.tertiaryText)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(WinterTheme.isActive ? Color.white.opacity(0.1) : Theme.Colors.tertiaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(WinterTheme.isActive ? Color.cyan.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
    
    // MARK: - Category Filters
    private var categoryFiltersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                WinterCategoryChip(
                    title: "Усі",
                    isSelected: selectedCategory == nil,
                    icon: "doc.on.doc"
                ) {
                    selectedCategory = nil
                }
                
                ForEach(TemplateCategory.allCases, id: \.self) { category in
                    WinterCategoryChip(
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
                if lockManager.isRegistered {
                    templatesListSection
                } else {
                    ZStack {
                        templatesListSection.blur(radius: 4)
                        winterLockOverlay
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(0..<3, id: \.self) { idx in
                WinterTemplateShimmer()
                    .padding(.horizontal, Theme.Spacing.md)
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.md)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if WinterTheme.isActive {
                Text("📄❄️")
                    .font(.system(size: 60))
            } else {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.tertiaryText)
            }
            
            VStack(spacing: Theme.Spacing.sm) {
                Text("Шаблони не знайдено")
                    .font(Theme.Typography.headline)
                    .foregroundColor(WinterTheme.isActive ? .white : Theme.Colors.primaryText)
                
                Text("Спробуйте змінити фільтри")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(WinterTheme.isActive ? .white.opacity(0.7) : Theme.Colors.secondaryText)
            }
            
            Button(action: { selectedCategory = nil; searchText = "" }) {
                Text("Скинути фільтри")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(WinterTheme.isActive ? .cyan : Theme.Colors.accent)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var winterLockOverlay: some View {
        VStack(spacing: Theme.Spacing.md) {
            if WinterTheme.isActive {
                Text("🔒❄️")
                    .font(.system(size: 50))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.accent)
            }
            
            Text("Зареєструйтесь для доступу")
                .font(.headline)
                .foregroundColor(WinterTheme.isActive ? .white : Theme.Colors.primaryText)
            
            Text("Шаблони доступні для зареєстрованих користувачів")
                .font(.subheadline)
                .foregroundColor(WinterTheme.isActive ? .white.opacity(0.7) : Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(WinterTheme.isActive ? Color.black.opacity(0.7) : Color.black.opacity(0.5))
        )
        .padding(Theme.Spacing.xl)
    }
    
    private var templatesListSection: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(filteredTemplates) { template in
                    NavigationLink(destination: TemplateDetailView(template: template)) {
                        WinterTemplateCard(template: template)
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

// MARK: - Winter Category Chip
struct WinterCategoryChip: View {
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
                        if WinterTheme.isActive {
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.6), Color.teal.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            Theme.Colors.accent
                        }
                    } else {
                        if WinterTheme.isActive {
                            Color.white.opacity(0.1)
                        } else {
                            Theme.Colors.tertiaryBackground
                        }
                    }
                }
            )
            .foregroundColor(
                isSelected
                    ? .white
                    : (WinterTheme.isActive ? .white.opacity(0.8) : Theme.Colors.primaryText)
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected
                            ? Color.clear
                            : (WinterTheme.isActive ? Color.cyan.opacity(0.2) : Color.clear),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Winter Template Card
struct WinterTemplateCard: View {
    let template: DocumentTemplate
    
    var body: some View {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: 12) {
                // Icon with winter styling
                ZStack {
                    if WinterTheme.isActive {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.3), Color.teal.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: template.category.iconName)
                            .font(.title3)
                            .foregroundColor(.cyan)
                    } else {
                        Circle()
                            .fill(template.category.swiftUIColor.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: template.category.iconName)
                            .font(.title3)
                            .foregroundColor(template.category.swiftUIColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                        Text(template.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(WinterTheme.isActive ? .white : Theme.Colors.primaryText)
                            .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        
                        Text(template.description)
                        .font(.caption)
                        .foregroundColor(WinterTheme.isActive ? .white.opacity(0.6) : Theme.Colors.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(WinterTheme.isActive ? .cyan.opacity(0.6) : Theme.Colors.tertiaryText)
            }
            
            // Tags row
            HStack(spacing: 8) {
                WinterTagPill(text: template.category.localizedName, color: template.category.swiftUIColor)
                WinterTagPill(text: template.templateType.localizedName, color: .purple)
                    
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
            Group {
                if WinterTheme.isActive {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.3), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.Colors.card)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
            }
        )
    }
}

// MARK: - Winter Tag Pill
struct WinterTagPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                WinterTheme.isActive
                    ? color.opacity(0.2)
                    : color.opacity(0.15)
            )
            .foregroundColor(WinterTheme.isActive ? .white.opacity(0.9) : color)
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
            // Winter background
            if WinterTheme.isActive {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.2),
                        Color(red: 0.08, green: 0.15, blue: 0.25),
                        Color(red: 0.05, green: 0.1, blue: 0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                Theme.Colors.primaryBackground.ignoresSafeArea()
            }
            
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Header card
                    templateHeaderCard
                
                    // Form section
                    formSection
                
                // Generate button
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
                    if WinterTheme.isActive {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.4), Color.teal.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: template.category.iconName)
                            .font(.title2)
                            .foregroundColor(.cyan)
                    } else {
                        Circle()
                            .fill(template.category.swiftUIColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: template.category.iconName)
                            .font(.title2)
                            .foregroundColor(template.category.swiftUIColor)
                    }
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
                .foregroundColor(WinterTheme.isActive ? .white.opacity(0.8) : Theme.Colors.secondaryText)
            
            HStack(spacing: 8) {
                WinterTagPill(text: template.category.localizedName, color: template.category.swiftUIColor)
                WinterTagPill(text: template.templateType.localizedName, color: .purple)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            Group {
                if WinterTheme.isActive {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.Colors.card)
                }
            }
        )
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                if WinterTheme.isActive {
                    Text("📝")
                        .font(.title3)
                }
                Text("Заповніть форму")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(WinterTheme.isActive ? .white : Theme.Colors.primaryText)
            }
            
            VStack(spacing: Theme.Spacing.md) {
                ForEach(template.placeholders.sorted { $0.order < $1.order }) { placeholder in
                    WinterTemplateFieldView(
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
                            if WinterTheme.isActive {
                                LinearGradient(
                                    colors: [Color.teal, Color.cyan.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Theme.Colors.accent
                            }
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

// MARK: - Winter Template Field View
struct WinterTemplateFieldView: View {
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
            // Label
            HStack(spacing: 4) {
                Text(placeholder.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(WinterTheme.isActive ? .white : Theme.Colors.primaryText)
                
                if placeholder.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.subheadline.weight(.bold))
                }
            }
            
            if let description = placeholder.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(WinterTheme.isActive ? .white.opacity(0.5) : Theme.Colors.tertiaryText)
            }
            
            // Input field
            fieldInput
        }
        .padding(Theme.Spacing.md)
        .background(
            Group {
                if WinterTheme.isActive {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.Colors.tertiaryBackground)
                }
            }
        )
    }
    
    @ViewBuilder
    private var fieldInput: some View {
                switch placeholder.type {
                case .text:
            winterTextField(placeholder: "Введіть \(placeholder.label.lowercased())")
                
                case .multilineText:
            winterTextField(placeholder: "Введіть \(placeholder.label.lowercased())", isMultiline: true)
                
                case .email:
            winterTextField(placeholder: "Введіть email", keyboardType: .emailAddress)
                
                case .phone:
            winterTextField(placeholder: "Введіть номер телефону", keyboardType: .phonePad)
                
                case .number:
            winterTextField(placeholder: "Введіть число", keyboardType: .numberPad)
                
                case .date:
            winterDatePicker
                
                case .dropdown:
                    if let options = placeholder.options {
                winterDropdown(options: options)
                    }
                
                case .checkbox:
            winterToggle
                
                default:
            winterTextField(placeholder: "Введіть \(placeholder.label.lowercased())")
        }
    }
    
    private func winterTextField(placeholder placeholderText: String, keyboardType: UIKeyboardType = .default, isMultiline: Bool = false) -> some View {
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
                .fill(WinterTheme.isActive ? Color.white.opacity(0.08) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(WinterTheme.isActive ? Color.cyan.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .foregroundColor(WinterTheme.isActive ? .white : Theme.Colors.primaryText)
    }
    
    private var winterDatePicker: some View {
        DatePicker("", selection: Binding(
            get: { Self.iso8601Formatter.date(from: value) ?? Date() },
            set: { value = Self.iso8601Formatter.string(from: $0) }
        ), displayedComponents: .date)
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(WinterTheme.isActive ? .cyan : Theme.Colors.accent)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(WinterTheme.isActive ? Color.white.opacity(0.08) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(WinterTheme.isActive ? Color.cyan.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func winterDropdown(options: [String]) -> some View {
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
                        ? (WinterTheme.isActive ? .white.opacity(0.4) : Theme.Colors.tertiaryText)
                        : (WinterTheme.isActive ? .white : Theme.Colors.primaryText))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(WinterTheme.isActive ? .cyan.opacity(0.7) : Theme.Colors.secondaryText)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(WinterTheme.isActive ? Color.white.opacity(0.08) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(WinterTheme.isActive ? Color.cyan.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var winterToggle: some View {
        Toggle(isOn: Binding(
            get: { value == "true" },
            set: { value = $0 ? "true" : "false" }
        )) {
            EmptyView()
        }
        .toggleStyle(SwitchToggleStyle(tint: WinterTheme.isActive ? .cyan : Theme.Colors.accent))
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
                // Background
                if WinterTheme.isActive {
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.1, blue: 0.2),
                            Color(red: 0.08, green: 0.15, blue: 0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                } else {
                    Theme.Colors.primaryBackground.ignoresSafeArea()
                }
                
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        // Language switcher
                        if availableLanguages.count > 1 {
                            HStack(spacing: 8) {
                                Text("Мова листа")
                                    .font(.caption)
                                    .foregroundColor(WinterTheme.isActive ? .white.opacity(0.7) : Theme.Colors.secondaryText)
                                
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
                        
                        // Document content
                        Text(generatedContent)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(WinterTheme.isActive ? .white : Theme.Colors.primaryText)
                            .padding(Theme.Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(WinterTheme.isActive ? Color.white.opacity(0.08) : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(WinterTheme.isActive ? Color.cyan.opacity(0.2) : Color.gray.opacity(0.1), lineWidth: 1)
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
                            .foregroundStyle(WinterTheme.isActive ? .white.opacity(0.7) : Theme.Colors.secondaryText)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Копіювати")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(WinterTheme.isActive ? .cyan : Theme.Colors.accent)
                    }
                    
                    Button(action: shareDocument) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Експорт")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(WinterTheme.isActive ? .cyan : Theme.Colors.accent)
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

// MARK: - Winter Template Shimmer
struct WinterTemplateShimmer: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(WinterTheme.isActive ? Color.cyan.opacity(0.1) : Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(WinterTheme.isActive ? Color.cyan.opacity(0.1) : Color.gray.opacity(0.2))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(WinterTheme.isActive ? Color.cyan.opacity(0.1) : Color.gray.opacity(0.2))
                    .frame(width: 160, height: 14)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(WinterTheme.isActive ? Color.white.opacity(0.05) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(WinterTheme.isActive ? Color.cyan.opacity(0.1) : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(WinterTheme.isActive ? 0.1 : 0.3),
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
        WinterTemplateShimmer()
    }
}

// MARK: - Template Card (Legacy support)
struct TemplateCard: View {
    let template: DocumentTemplate
    
    var body: some View {
        WinterTemplateCard(template: template)
    }
}

#Preview {
    TemplatesView()
        .environmentObject(AppContainer())
        .environmentObject(AppLockManager())
        .environmentObject(AccountManager())
}
