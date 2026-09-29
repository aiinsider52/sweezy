import SwiftUI

/// Form for proposing a place for the map. Nothing goes public until a moderator checks it.
struct SuggestPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var name = ""
    @State private var category: PlaceSuggestionCategory = .community
    @State private var street = ""
    @State private var postalCode = ""
    @State private var city = ""
    @State private var website = ""
    @State private var phone = ""
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var submitted: APIClient.PlaceSuggestion?
    @State private var mySuggestions: [APIClient.PlaceSuggestion] = []
    @State private var showAuth = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable, CaseIterable {
        case name, street, postal, city, website, phone, note
    }

    private static let noteLimit = 600

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        if let submitted {
                            successState(submitted)
                        } else if showsForm {
                            header
                            form
                        } else {
                            guestGate
                        }

                        if sessionManager.isAuthenticated, !mySuggestions.isEmpty {
                            mySuggestionsSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("place.suggest.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) { dismiss() }
                        .foregroundStyle(JourneyVisual.primaryText)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done".localized) { focusedField = nil }
                        .fontWeight(.bold)
                        .accessibilityIdentifier("place.suggest.keyboard_done")
                }
            }
            .task(id: sessionManager.isAuthenticated) {
                await loadMySuggestions()
            }
            .onChange(of: sessionManager.isAuthenticated) { _, authenticated in
                if authenticated { showAuth = false }
            }
            .sheet(isPresented: $showAuth) {
                AuthEntryView(showsCloseButton: true) { showAuth = false }
                    .environment(\.locale, appContainer.currentLocale)
                    .environmentObject(appContainer)
                    .environmentObject(lockManager)
                    .environmentObject(sessionManager)
            }
        }
        .accessibilityIdentifier("place.suggest.screen")
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("place.suggest.headline".localized)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("place.suggest.subtitle".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            SweezyCompanion(pose: .plan, size: 92)
        }
        .padding(16)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            field("place.suggest.field.name".localized, text: $name, prompt: "place.suggest.field.name.prompt".localized, focus: .name, identifier: "place.suggest.name")

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("place.suggest.field.category".localized)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                    ForEach(PlaceSuggestionCategory.allCases) { option in
                        categoryChip(option)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("place.suggest.field.address".localized)
                input(text: $street, prompt: "place.suggest.field.street.prompt".localized, focus: .street, identifier: "place.suggest.street")
                    .textContentType(.fullStreetAddress)
                HStack(spacing: 8) {
                    input(text: $postalCode, prompt: "place.suggest.field.postal.prompt".localized, focus: .postal, identifier: "place.suggest.postal")
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                        .frame(width: 110)
                    input(text: $city, prompt: "place.suggest.field.city.prompt".localized, focus: .city, identifier: "place.suggest.city")
                        .textContentType(.addressCity)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("place.suggest.field.contacts".localized)
                input(text: $website, prompt: "place.suggest.field.website.prompt".localized, focus: .website, identifier: "place.suggest.website")
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                input(text: $phone, prompt: "place.suggest.field.phone.prompt".localized, focus: .phone, identifier: "place.suggest.phone")
                    .keyboardType(.phonePad)
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("place.suggest.field.note".localized)
                ZStack(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("place.suggest.field.note.prompt".localized)
                            .font(.system(size: 15))
                            .foregroundStyle(JourneyVisual.secondaryText.opacity(0.8))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $note)
                        .font(.system(size: 15))
                        .foregroundStyle(JourneyVisual.primaryText)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(minHeight: 120)
                        .focused($focusedField, equals: .note)
                        .accessibilityIdentifier("place.suggest.note")
                        .onChange(of: note) { _, value in
                            if value.count > Self.noteLimit { note = String(value.prefix(Self.noteLimit)) }
                        }
                }
                .background(Theme.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
                Text("\(note.count)/\(Self.noteLimit)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(JourneyVisual.accentText)
                Text("place.suggest.moderation_note".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(JourneyVisual.softSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(JourneyVisual.coral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button { submit() } label: {
                HStack(spacing: 8) {
                    if isSubmitting { ProgressView().tint(.black) }
                    Text("place.suggest.submit".localized)
                    Image(systemName: "paperplane.fill")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(JourneyVisual.lime.opacity(canSubmit ? 1 : 0.45))
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || !canSubmit)
            .accessibilityIdentifier("place.suggest.submit")
        }
    }

    private var guestGate: some View {
        MascotEmptyState(
            title: "place.suggest.guest.title".localized,
            subtitle: "place.suggest.guest.subtitle".localized,
            pose: .plan,
            actionTitle: "place.suggest.guest.action".localized,
            actionIdentifier: "place.suggest.sign_in"
        ) {
            showAuth = true
        }
        .padding(.top, 24)
    }

    private func successState(_ suggestion: APIClient.PlaceSuggestion) -> some View {
        VStack(spacing: 18) {
            MascotEmptyState(
                title: "place.suggest.success.title".localized,
                subtitle: "place.suggest.success.subtitle".localized(with: suggestion.name),
                pose: .celebrate
            )
            Button { dismiss() } label: {
                Text("common.done".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
            Button("place.suggest.another".localized) { resetForm() }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(JourneyVisual.accentText)
        }
        .padding(.top, 12)
    }

    private var mySuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("place.suggest.mine".localized)
            ForEach(mySuggestions) { suggestion in
                let option = PlaceSuggestionCategory(rawValue: suggestion.category) ?? .other
                HStack(spacing: 12) {
                    JourneyCategoryIcon(symbol: option.icon, swatch: option.swatch, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(suggestion.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(JourneyVisual.primaryText)
                            .lineLimit(1)
                        Text(suggestion.status == "rejected"
                             ? (suggestion.rejectionReason ?? suggestion.city)
                             : suggestion.city)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(JourneyVisual.secondaryText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 6)
                    statusPill(suggestion.status)
                }
                .padding(12)
                .background(Theme.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(JourneyVisual.primaryText)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, focus: Field, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(label)
            input(text: text, prompt: prompt, focus: focus, identifier: identifier)
        }
    }

    private func input(text: Binding<String>, prompt: String, focus: Field, identifier: String) -> some View {
        TextField("", text: text, prompt: Text(prompt).foregroundStyle(JourneyVisual.secondaryText.opacity(0.8)))
            .focused($focusedField, equals: focus)
            .submitLabel(.next)
            .onSubmit { focusedField = next(after: focus) }
            .font(.system(size: 15))
            .foregroundStyle(JourneyVisual.primaryText)
            .padding(.horizontal, 15)
            .frame(height: 50)
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
            .accessibilityIdentifier(identifier)
    }

    private func categoryChip(_ option: PlaceSuggestionCategory) -> some View {
        let selected = category == option
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            category = option
        } label: {
            HStack(spacing: 7) {
                JourneyCategoryIcon(symbol: option.icon, swatch: option.swatch, size: 26)
                Text(option.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 42)
            .background(selected ? JourneyVisual.lime.opacity(0.35) : Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? JourneyVisual.accentStrong : JourneyVisual.softBorder, lineWidth: selected ? 1.6 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("place.suggest.category.\(option.rawValue)")
    }

    private func statusPill(_ status: String) -> some View {
        let (title, fill, ink): (String, Color, Color) = {
            switch status {
            case "approved": return ("place.suggest.status.approved".localized, JourneyVisual.lime, .black)
            case "rejected": return ("place.suggest.status.rejected".localized, JourneyVisual.coral.opacity(0.18), JourneyVisual.coral)
            default: return ("place.suggest.status.pending".localized, JourneyVisual.softSurface, JourneyVisual.secondaryText)
            }
        }()
        return Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(ink)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(fill)
            .clipShape(Capsule())
    }

    // MARK: - Logic

    private var showsForm: Bool {
        if sessionManager.isAuthenticated { return true }
        #if DEBUG
        return ProcessInfo.processInfo.environment["UITESTS"] == "1"
            && ProcessInfo.processInfo.arguments.contains("--ui-test-suggest-place")
        #else
        return false
        #endif
    }

    private func next(after field: Field) -> Field? {
        let all = Field.allCases
        guard let index = all.firstIndex(of: field), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        trimmed(name).count >= 3
            && trimmed(street).count >= 2
            && trimmed(postalCode).count >= 3
            && trimmed(city).count >= 2
            && trimmed(note).count >= 10
    }

    private func submit() {
        focusedField = nil
        guard canSubmit else {
            errorMessage = "place.suggest.validation".localized
            return
        }
        isSubmitting = true
        errorMessage = nil
        let payload = APIClient.PlaceSuggestionPayload(
            name: trimmed(name),
            category: category.rawValue,
            street: trimmed(street),
            postalCode: trimmed(postalCode),
            city: trimmed(city),
            countryCode: APIClient.countryCode,
            subdivisionCode: APIClient.subdivisionCode,
            website: trimmed(website).isEmpty ? nil : trimmed(website),
            phone: trimmed(phone).isEmpty ? nil : trimmed(phone),
            note: trimmed(note)
        )
        Task {
            do {
                let created = try await APIClient.submitPlaceSuggestion(payload)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                submitted = created
                mySuggestions.insert(created, at: 0)
            } catch {
                let code = (error as NSError).code
                errorMessage = code == 429
                    ? "place.suggest.error.rate_limited".localized
                    : "place.suggest.error.generic".localized
            }
            isSubmitting = false
        }
    }

    private func resetForm() {
        name = ""
        street = ""
        postalCode = ""
        city = ""
        website = ""
        phone = ""
        note = ""
        category = .community
        submitted = nil
    }

    private func loadMySuggestions() async {
        guard sessionManager.isAuthenticated else {
            mySuggestions = []
            return
        }
        mySuggestions = (try? await APIClient.fetchMyPlaceSuggestions()) ?? mySuggestions
    }
}
