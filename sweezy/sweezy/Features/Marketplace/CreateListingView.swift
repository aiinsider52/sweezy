import SwiftUI

struct CreateListingView: View {
    var onCreated: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title = ""
    @State private var description = ""
    @State private var category: ServiceCategory = .other
    @State private var canton = "ZH"
    @State private var priceInfo = ""
    @State private var contactType: ContactType = .telegram
    @State private var contactValue = ""
    @State private var authorName = ""

    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showMyListings = false
    @State private var showCantonPicker = false
    @State private var errorMessage: String?

    @State private var suggestedCategory: ServiceCategory?
    @State private var categorySuggestionVisible = false

    @FocusState private var focusedField: FormField?

    private enum FormField: Hashable {
        case title, description, price, contact, author
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        description.trimmingCharacters(in: .whitespaces).count >= 20 &&
        !contactValue.trimmingCharacters(in: .whitespaces).isEmpty &&
        !authorName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptivePageBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        titleCard
                        categoryCard
                        cantonCard
                        descriptionCard
                        priceCard
                        contactCard
                        authorCard
                        submitButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("marketplace.create_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("marketplace.my_listings".localized) {
                        showMyListings = true
                    }
                    .font(.subheadline)
                }
            }
            .sheet(isPresented: $showSuccess) {
                successSheet
            }
            .sheet(isPresented: $showMyListings) {
                MyListingsView()
            }
            .sheet(isPresented: $showCantonPicker) {
                CantonPickerSheet(selectedCanton: $canton)
            }
            .alert("marketplace.error_title".localized, isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Title Card

    private var titleCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 10) {
                formLabel("marketplace.field.title".localized, icon: "pencil.line")

                TextField("marketplace.field.title_placeholder".localized, text: $title)
                    .focused($focusedField, equals: .title)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: title) { _, newValue in
                        if newValue.count > 100 { title = String(newValue.prefix(100)) }
                        updateCategorySuggestion(for: newValue)
                    }

                HStack {
                    if let suggested = suggestedCategory, categorySuggestionVisible, suggested != category {
                        suggestedCategoryBadge(suggested)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    Spacer()
                    Text("\(title.count)/100")
                        .font(.caption2)
                        .foregroundColor(title.count > 90 ? Theme.Colors.error : Theme.Colors.textTertiary)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: categorySuggestionVisible)
            }
        }
    }

    // MARK: - Category Card

    private var categoryCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 10) {
                formLabel("marketplace.field.category".localized, icon: "tag.fill")

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 8)
                ], spacing: 8) {
                    ForEach(ServiceCategory.allCases) { cat in
                        categoryChip(cat)
                    }
                }
            }
        }
    }

    private func categoryChip(_ cat: ServiceCategory) -> some View {
        let isSelected = category == cat
        let isSuggested = suggestedCategory == cat && categorySuggestionVisible && !isSelected

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                category = cat
                if suggestedCategory == cat {
                    categorySuggestionVisible = false
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: cat.icon)
                    .font(.system(size: 11))
                Text(cat.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? cat.color.opacity(0.2)
                          : isSuggested
                            ? cat.color.opacity(0.08)
                            : Theme.Colors.adaptiveCard.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected
                            ? cat.color.opacity(0.6)
                            : isSuggested
                              ? cat.color.opacity(0.4)
                              : Color.clear,
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSuggested {
                    Image(systemName: "sparkle")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(cat.color)
                        .padding(4)
                }
            }
            .foregroundColor(isSelected ? cat.color : isSuggested ? cat.color.opacity(0.8) : Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Canton Card

    private var cantonCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 10) {
                formLabel("marketplace.field.canton".localized, icon: "mappin.and.ellipse")

                Button {
                    showCantonPicker = true
                } label: {
                    HStack(spacing: 12) {
                        cantonFlag(canton)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Theme.Colors.primary.opacity(0.1))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(cantonDisplayName(canton))
                                .font(.body.weight(.medium))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(canton == "all" ? "" : canton)
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Description Card

    private var descriptionCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 10) {
                formLabel("marketplace.field.description".localized, icon: "text.alignleft")

                TextEditor(text: $description)
                    .focused($focusedField, equals: .description)
                    .font(.body)
                    .frame(minHeight: 100, maxHeight: 180)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: description) { _, newValue in
                        if newValue.count > 1000 { description = String(newValue.prefix(1000)) }
                    }

                HStack {
                    if description.count < 20 && !description.isEmpty {
                        Label("marketplace.field.description_min".localized, systemImage: "exclamationmark.circle")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.warning)
                    }
                    Spacer()
                    Text("\(description.count)/1000")
                        .font(.caption2)
                        .foregroundColor(description.count > 950 ? Theme.Colors.error : Theme.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Price Card

    private var priceCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 10) {
                formLabel("marketplace.field.price".localized, icon: "banknote.fill", optional: true)

                HStack(spacing: 10) {
                    Image(systemName: "swiss.franc.sign")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.Colors.textTertiary)
                        .frame(width: 20)

                    TextField("marketplace.field.price_placeholder".localized, text: $priceInfo)
                        .focused($focusedField, equals: .price)
                        .font(.body)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Contact Card

    private var contactCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                formLabel("marketplace.field.contact".localized, icon: "bubble.left.fill")

                HStack(spacing: 6) {
                    ForEach(ContactType.allCases) { type in
                        contactTypeButton(type)
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: contactType.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.primary)
                        .frame(width: 20)

                    TextField(contactType.placeholder, text: $contactValue)
                        .focused($focusedField, equals: .contact)
                        .font(.body)
                        .keyboardType(contactType == .email ? .emailAddress : contactType == .telegram ? .default : .phonePad)
                        .textContentType(contactType == .email ? .emailAddress : contactType == .phone ? .telephoneNumber : nil)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func contactTypeButton(_ type: ContactType) -> some View {
        let isSelected = contactType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                contactType = type
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                Text(type.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? Theme.Colors.primary.opacity(0.15)
                          : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Theme.Colors.primary.opacity(0.4) : Theme.Colors.adaptiveBorder,
                            lineWidth: isSelected ? 1.5 : 0.5)
            )
            .foregroundColor(isSelected ? Theme.Colors.primary : Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Author Card

    private var authorCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 10) {
                formLabel("marketplace.field.author".localized, icon: "person.fill")

                HStack(spacing: 10) {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(authorName.isEmpty ? "?" : String(authorName.prefix(1)).uppercased())
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Theme.Colors.primary)
                        )

                    TextField("marketplace.field.author_placeholder".localized, text: $authorName)
                        .focused($focusedField, equals: .author)
                        .font(.body)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 10) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15))
                    Text("marketplace.submit".localized)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isValid
                          ? LinearGradient(colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                                           startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.2)],
                                           startPoint: .leading, endPoint: .trailing))
            )
            .foregroundColor(isValid ? .white : Theme.Colors.textTertiary)
            .shadow(color: isValid ? Theme.Colors.primary.opacity(0.3) : .clear, radius: 10, y: 5)
        }
        .disabled(!isValid || isSubmitting)
        .padding(.top, 4)
    }

    // MARK: - Success Sheet

    private var successSheet: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Colors.primary, Theme.Colors.primaryLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("marketplace.success_title".localized)
                .font(.title2.bold())
                .foregroundColor(Theme.Colors.textPrimary)

            Text("marketplace.success_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                showSuccess = false
                dismiss()
            } label: {
                Text("common.ok".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Shared Components

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme == .dark
                  ? Color.white.opacity(0.06)
                  : Color.black.opacity(0.03))
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.adaptiveCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Colors.adaptiveBorder, lineWidth: 0.5)
        )
    }

    private func formLabel(_ text: String, icon: String, optional: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.primary)
            Text(text)
                .font(.subheadline.bold())
                .foregroundColor(Theme.Colors.textPrimary)
            if optional {
                Text("(\("marketplace.optional".localized))")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textTertiary)
            }
        }
    }

    private func suggestedCategoryBadge(_ cat: ServiceCategory) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                category = cat
                categorySuggestionVisible = false
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkle")
                    .font(.system(size: 9, weight: .bold))
                Image(systemName: cat.icon)
                    .font(.system(size: 10))
                Text(cat.displayName)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(cat.color.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(cat.color.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(cat.color)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Canton Helpers

    private func cantonDisplayName(_ code: String) -> String {
        SwissCanton.all.first(where: { $0.code == code })?.name ?? code
    }

    private func cantonFlag(_ code: String) -> some View {
        Text(cantonEmoji(code))
            .font(.system(size: 20))
    }

    private func cantonEmoji(_ code: String) -> String {
        switch code {
        case "all": return "🇨🇭"
        case "ZH": return "🏙️"
        case "BE": return "🐻"
        case "LU": return "⛰️"
        case "GE": return "⛲"
        case "BS": return "🏛️"
        case "TI": return "🌴"
        case "VD": return "🍇"
        case "AG": return "🏰"
        case "SG": return "⭐"
        case "GR": return "🦌"
        case "VS": return "🏔️"
        default: return "📍"
        }
    }

    // MARK: - Auto-Suggest Category

    private func updateCategorySuggestion(for text: String) {
        let lower = text.lowercased()
        guard lower.count >= 3 else {
            withAnimation { categorySuggestionVisible = false }
            return
        }

        let mapping: [(keywords: [String], category: ServiceCategory)] = [
            (["переклад", "translat", "übersetzu", "dolmetsch", "перевод", "interpret"], .translation),
            (["документ", "document", "dokument", "довідк", "справк", "паспорт", "дозвіл", "permit", "bewillig"], .documents),
            (["репетит", "tutor", "nachhilfe", "урок", "lesson", "навчан", "math", "english", "deutsch", "мов"], .tutoring),
            (["програм", "develop", "web", "сайт", "app", "software", "it ", "комп'ютер", "computer", "код"], .it),
            (["макіяж", "makeup", "beauty", "nail", "нігт", "волосс", "hair", "стриж", "brows", "lash"], .beauty),
            (["прибир", "clean", "reinig", "пральн", "миття", "wash", "hauswart"], .cleaning),
            (["бухгалт", "account", "buchhalt", "steuer", "податк", "tax", "фінанс", "financ"], .accounting),
            (["юрист", "legal", "lawyer", "advokat", "rechts", "закон", "право", "law"], .legal),
            (["дит", "child", "baby", "nanny", "няня", "kinder", "betreuung", "догляд"], .childcare),
            (["переїзд", "moving", "umzug", "transport", "вантаж", "delivery", "lieferung"], .moving),
            (["ремонт", "repair", "reparatur", "сантехн", "plumb", "electric", "handwerk", "fix"], .repair),
        ]

        for entry in mapping {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                let newSuggested = entry.category
                if suggestedCategory != newSuggested || !categorySuggestionVisible {
                    suggestedCategory = newSuggested
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        categorySuggestionVisible = true
                    }
                }
                return
            }
        }

        withAnimation { categorySuggestionVisible = false }
    }

    // MARK: - Submit

    private func submit() async {
        guard isValid else { return }
        isSubmitting = true

        let payload = ServiceListingCreate(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            category: category,
            canton: canton,
            priceInfo: priceInfo.isEmpty ? nil : priceInfo,
            contactType: contactType,
            contactValue: contactValue.trimmingCharacters(in: .whitespaces),
            authorName: authorName.trimmingCharacters(in: .whitespaces)
        )

        do {
            _ = try await APIClient.createListing(payload)
            onCreated?()
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}

// MARK: - Canton Picker Sheet

private struct CantonPickerSheet: View {
    @Binding var selectedCanton: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [(code: String, name: String)] {
        if searchText.isEmpty { return SwissCanton.all }
        let lower = searchText.lowercased()
        return SwissCanton.all.filter {
            $0.code.lowercased().contains(lower) || $0.name.lowercased().contains(lower)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptivePageBackground()

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered, id: \.code) { canton in
                            cantonRow(canton)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .searchable(text: $searchText, prompt: "marketplace.canton.search".localized)
            .navigationTitle("marketplace.field.canton".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func cantonRow(_ canton: (code: String, name: String)) -> some View {
        let isSelected = selectedCanton == canton.code
        return Button {
            selectedCanton = canton.code
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(cantonEmoji(canton.code))
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isSelected
                                  ? Theme.Colors.primary.opacity(0.15)
                                  : Theme.Colors.adaptiveCard)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(canton.name)
                        .font(.body.weight(.medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    if canton.code != "all" {
                        Text(canton.code)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textTertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? Theme.Colors.primary.opacity(0.08)
                          : Theme.Colors.adaptiveCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Theme.Colors.primary.opacity(0.3) : Theme.Colors.adaptiveBorder.opacity(0.5), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func cantonEmoji(_ code: String) -> String {
        switch code {
        case "all": return "🇨🇭"
        case "ZH": return "🏙️"
        case "BE": return "🐻"
        case "LU": return "⛰️"
        case "GE": return "⛲"
        case "BS": return "🏛️"
        case "TI": return "🌴"
        case "VD": return "🍇"
        case "AG": return "🏰"
        case "SG": return "⭐"
        case "GR": return "🦌"
        case "VS": return "🏔️"
        default: return "📍"
        }
    }
}
