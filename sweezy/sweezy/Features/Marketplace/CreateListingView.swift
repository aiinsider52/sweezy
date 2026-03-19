import SwiftUI

struct CreateListingView: View {
    var onCreated: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

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
    @State private var errorMessage: String?

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
                    VStack(spacing: 24) {
                        titleSection
                        categorySection
                        cantonSection
                        descriptionSection
                        priceSection
                        contactSection
                        authorSection

                        submitButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
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

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("marketplace.field.title".localized)
            TextField("marketplace.field.title_placeholder".localized, text: $title)
                .textFieldStyle(.roundedBorder)
                .onChange(of: title) { _, newValue in
                    if newValue.count > 100 { title = String(newValue.prefix(100)) }
                }
            HStack {
                Spacer()
                Text("\(title.count)/100")
                    .font(.caption2)
                    .foregroundColor(title.count > 90 ? Theme.Colors.error : Theme.Colors.textTertiary)
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("marketplace.field.category".localized)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ServiceCategory.allCases) { cat in
                        Button {
                            category = cat
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 12))
                                Text(cat.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(category == cat
                                          ? cat.color.opacity(0.25)
                                          : Theme.Colors.adaptiveCard)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(category == cat ? cat.color.opacity(0.4) : Theme.Colors.adaptiveBorder, lineWidth: 1)
                            )
                            .foregroundColor(category == cat ? cat.color : Theme.Colors.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Canton

    private var cantonSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("marketplace.field.canton".localized)
            Picker("", selection: $canton) {
                ForEach(SwissCanton.all, id: \.code) { c in
                    Text("\(c.code) — \(c.name)").tag(c.code)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.Colors.primary)
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("marketplace.field.description".localized)
            TextEditor(text: $description)
                .frame(minHeight: 100, maxHeight: 200)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.adaptiveBorder, lineWidth: 1)
                )
                .onChange(of: description) { _, newValue in
                    if newValue.count > 1000 { description = String(newValue.prefix(1000)) }
                }
            HStack {
                if description.count < 20 && !description.isEmpty {
                    Text("marketplace.field.description_min".localized)
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

    // MARK: - Price

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("marketplace.field.price".localized, optional: true)
            TextField("marketplace.field.price_placeholder".localized, text: $priceInfo)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("marketplace.field.contact".localized)

            Picker("", selection: $contactType) {
                ForEach(ContactType.allCases) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField(contactType.placeholder, text: $contactValue)
                .textFieldStyle(.roundedBorder)
                .keyboardType(contactType == .email ? .emailAddress : contactType == .telegram ? .default : .phonePad)
                .textContentType(contactType == .email ? .emailAddress : contactType == .phone ? .telephoneNumber : nil)
        }
    }

    // MARK: - Author

    private var authorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("marketplace.field.author".localized)
            TextField("marketplace.field.author_placeholder".localized, text: $authorName)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            Group {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("marketplace.submit".localized)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isValid
                          ? LinearGradient(colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                                           startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                           startPoint: .leading, endPoint: .trailing))
            )
            .foregroundColor(.white)
        }
        .disabled(!isValid || isSubmitting)
        .padding(.top, 8)
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

    // MARK: - Helpers

    private func sectionLabel(_ text: String, optional: Bool = false) -> some View {
        HStack(spacing: 4) {
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
