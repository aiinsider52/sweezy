import SwiftUI

struct EditListingView: View {
    let listing: ServiceListing
    var onSaved: ((ServiceListing) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var title: String
    @State private var description: String
    @State private var priceInfo: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private enum Field: Hashable {
        case title, description, price
    }

    init(listing: ServiceListing, onSaved: ((ServiceListing) -> Void)? = nil) {
        self.listing = listing
        self.onSaved = onSaved
        _title = State(initialValue: listing.title)
        _description = State(initialValue: listing.description)
        _priceInfo = State(initialValue: listing.priceInfo ?? "")
    }

    private var isValid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
        description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.market.rawValue, blurRadius: 7, darkness: 0.72)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        headerCard
                        titleCard
                        descriptionCard
                        priceCard
                        saveButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("marketplace.edit_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
            }
            .alert("marketplace.error_title".localized, isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("common.ok".localized) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .journeyScreen(.market, darkness: 0.72)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(listing.categoryColor.opacity(0.18))
                        .frame(width: 54, height: 54)
                    Image(systemName: listing.categoryIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(listing.categoryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.categoryDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(listing.categoryColor)
                    Text("marketplace.edit_hint".localized)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var titleCard: some View {
        editorCard(title: "marketplace.field.title".localized, icon: "pencil.line") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("marketplace.field.title_placeholder".localized, text: $title)
                    .focused($focusedField, equals: .title)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    }

    private var descriptionCard: some View {
        editorCard(title: "marketplace.field.description".localized, icon: "text.alignleft") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $description)
                    .focused($focusedField, equals: .description)
                    .frame(minHeight: 130, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: description) { _, newValue in
                        if newValue.count > 1000 { description = String(newValue.prefix(1000)) }
                    }

                HStack {
                    Text("marketplace.field.description_min".localized)
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.textTertiary)
                    Spacer()
                    Text("\(description.count)/1000")
                        .font(.caption2)
                        .foregroundColor(description.count > 950 ? Theme.Colors.error : Theme.Colors.textTertiary)
                }
            }
        }
    }

    private var priceCard: some View {
        editorCard(
            title: "marketplace.field.price".localized + " (" + "marketplace.optional".localized + ")",
            icon: "banknote"
        ) {
            TextField("marketplace.field.price_placeholder".localized, text: $priceInfo)
                .focused($focusedField, equals: .price)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var saveButton: some View {
        Button {
            Task { await saveChanges() }
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.down.fill")
                }

                Text("marketplace.save_changes".localized)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 14, y: 8)
        }
        .disabled(!isValid || isSaving)
        .opacity((!isValid || isSaving) ? 0.6 : 1)
    }

    private func editorCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Theme.Colors.primary)
                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.Colors.adaptiveSurface.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Colors.adaptiveBorder.opacity(0.3), lineWidth: 1)
            )
    }

    private func saveChanges() async {
        guard isValid, !isSaving else { return }
        isSaving = true

        do {
            let updated = try await APIClient.updateListing(
                id: listing.id,
                payload: ServiceListingUpdate(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    priceInfo: priceInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : priceInfo.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            onSaved?(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
