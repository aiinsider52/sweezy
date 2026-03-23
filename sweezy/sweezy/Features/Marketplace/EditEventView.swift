import SwiftUI

struct EditEventView: View {
    let event: EventListing
    var onSaved: ((EventListing) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var title: String
    @State private var description: String
    @State private var venueName: String
    @State private var address: String
    @State private var startsAt: Date
    @State private var endsAt: Date
    @State private var isFree: Bool
    @State private var priceInfo: String

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(event: EventListing, onSaved: ((EventListing) -> Void)? = nil) {
        self.event = event
        self.onSaved = onSaved
        _title = State(initialValue: event.title)
        _description = State(initialValue: event.description)
        _venueName = State(initialValue: event.venueName ?? "")
        _address = State(initialValue: event.address ?? "")
        _startsAt = State(initialValue: event.startsAt ?? Date())
        _endsAt = State(initialValue: event.endsAt ?? ((event.startsAt ?? Date()).addingTimeInterval(7200)))
        _isFree = State(initialValue: event.isFree)
        _priceInfo = State(initialValue: event.priceInfo ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptivePageBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        editorCard(title: "marketplace.field.title".localized, icon: "sparkles") {
                            TextField("events.title_placeholder".localized, text: $title)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        editorCard(title: "marketplace.field.description".localized, icon: "text.alignleft") {
                            TextEditor(text: $description)
                                .frame(minHeight: 140)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        editorCard(title: "events.venue".localized, icon: "mappin.circle.fill") {
                            VStack(spacing: 10) {
                                TextField("events.venue_placeholder".localized, text: $venueName)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(fieldBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                TextField("events.address_placeholder".localized, text: $address)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(fieldBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        editorCard(title: "events.date_time".localized, icon: "calendar.badge.clock") {
                            VStack(spacing: 12) {
                                DatePicker("events.starts_at".localized, selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                                DatePicker("events.ends_at".localized, selection: $endsAt, in: startsAt..., displayedComponents: [.date, .hourAndMinute])
                            }
                            .tint(Theme.Colors.primary)
                        }

                        editorCard(title: "events.price".localized, icon: "banknote.fill") {
                            VStack(spacing: 12) {
                                Toggle("events.free_toggle".localized, isOn: $isFree)
                                    .tint(Theme.Colors.primary)
                                if !isFree {
                                    TextField("events.price_placeholder".localized, text: $priceInfo)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(fieldBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        Button {
                            Task { await saveChanges() }
                        } label: {
                            HStack {
                                if isSaving { ProgressView().tint(.white) }
                                Text("marketplace.save_changes".localized)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.Colors.primary)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("events.edit_title".localized)
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
    }

    private func editorCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.adaptiveCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Colors.adaptiveBorder.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
    }

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await APIClient.updateEvent(
                id: event.id,
                payload: EventListingUpdate(
                    title: title.nilIfBlank,
                    description: description.nilIfBlank,
                    venueName: venueName.nilIfBlank,
                    address: address.nilIfBlank,
                    startsAt: startsAt,
                    endsAt: endsAt,
                    isFree: isFree,
                    priceInfo: isFree ? nil : priceInfo.nilIfBlank
                )
            )
            onSaved?(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
