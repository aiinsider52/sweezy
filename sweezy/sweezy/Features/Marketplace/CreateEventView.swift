import SwiftUI

struct CreateEventView: View {
    var onCreated: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var title = ""
    @State private var description = ""
    @State private var category: EventCategory = .community
    @State private var canton = "ZH"
    @State private var city = ""
    @State private var venueName = ""
    @State private var address = ""
    @State private var startsAt = Date().addingTimeInterval(3600 * 24)
    @State private var endsAt = Date().addingTimeInterval(3600 * 26)
    @State private var isFree = true
    @State private var priceInfo = ""
    @State private var contactType: ContactType = .telegram
    @State private var contactValue = ""
    @State private var organizerName = ""

    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showMyEvents = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 &&
        !contactValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !organizerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.city.rawValue, blurRadius: 7, darkness: 0.72)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        infoCard
                        locationCard
                        scheduleCard
                        pricingCard
                        contactCard
                        organizerCard
                        submitButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("events.create_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("events.my_events".localized) { showMyEvents = true }
                        .font(.subheadline)
                }
            }
            .sheet(isPresented: $showSuccess) { successSheet }
            .sheet(isPresented: $showMyEvents) { MyEventsView() }
            .alert("marketplace.error_title".localized, isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("common.ok".localized) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .journeyScreen(.city, darkness: 0.72)
    }

    private var infoCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                formLabel("marketplace.field.title".localized, icon: "sparkles")
                TextField("events.title_placeholder".localized, text: $title)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                formLabel("marketplace.field.category".localized, icon: "tag.fill")
                categoryScroll

                formLabel("marketplace.field.description".localized, icon: "text.alignleft")
                TextEditor(text: $description)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var locationCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                formLabel("marketplace.field.canton".localized, icon: "mappin.and.ellipse")
                Menu {
                    ForEach(SwissCanton.all, id: \.code) { cantonOption in
                        Button(cantonOption.name) { canton = cantonOption.code }
                    }
                } label: {
                    pickerRow(title: SwissCanton.all.first(where: { $0.code == canton })?.name ?? canton)
                }

                formLabel("events.city".localized, icon: "building.2.fill")
                TextField("events.city_placeholder".localized, text: $city)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                formLabel("events.venue".localized, icon: "mappin.circle.fill", optional: true)
                TextField("events.venue_placeholder".localized, text: $venueName)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                formLabel("events.address".localized, icon: "location.fill", optional: true)
                TextField("events.address_placeholder".localized, text: $address)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var scheduleCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                formLabel("events.date_time".localized, icon: "calendar.badge.clock")

                DatePicker("events.starts_at".localized, selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .tint(Theme.Colors.primary)

                DatePicker("events.ends_at".localized, selection: $endsAt, in: startsAt..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .tint(Theme.Colors.primary)
            }
        }
    }

    private var pricingCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $isFree) {
                    Label("events.free_toggle".localized, systemImage: "ticket.fill")
                        .foregroundColor(Theme.Colors.textPrimary)
                }
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
    }

    private var contactCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                formLabel("marketplace.field.contact".localized, icon: "paperplane.fill")

                Picker("", selection: $contactType) {
                    ForEach(ContactType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                TextField(contactType.placeholder, text: $contactValue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var organizerCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                formLabel("events.organizer".localized, icon: "person.crop.circle.fill")
                TextField("events.organizer_placeholder".localized, text: $organizerName)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 10) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "calendar.badge.plus")
                }
                Text("events.publish".localized)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(isValid ? Theme.Colors.primary : Theme.Colors.textTertiary.opacity(0.35))
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(!isValid || isSubmitting)
    }

    private var successSheet: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Colors.primary, Theme.Colors.accentTurquoise],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("events.success_title".localized)
                .font(.title2.bold())
                .foregroundColor(Theme.Colors.textPrimary)

            Text("events.success_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

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
                    .foregroundColor(Theme.Colors.textOnPrimary)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
    }

    private var categoryScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EventCategory.allCases) { item in
                    Button {
                        category = item
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                            Text(item.displayName)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(category == item ? item.color.opacity(0.18) : Theme.Colors.adaptiveSurface)
                        )
                        .overlay(
                            Capsule()
                                .stroke(category == item ? item.color.opacity(0.55) : Theme.Colors.adaptiveBorder.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(category == item ? item.color : Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pickerRow(title: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.down")
                .foregroundColor(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
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

    private func submit() async {
        guard isValid else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let payload = EventListingCreate(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                canton: canton,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                venueName: venueName.nilIfBlank,
                address: address.nilIfBlank,
                startsAt: startsAt,
                endsAt: endsAt,
                isFree: isFree,
                priceInfo: isFree ? nil : priceInfo.nilIfBlank,
                contactType: contactType,
                contactValue: contactValue.trimmingCharacters(in: .whitespacesAndNewlines),
                organizerName: organizerName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            _ = try await APIClient.createEvent(payload)
            EventBus.shared.emit(GamEvent(
                type: .marketplaceContribution,
                metadata: [
                    "entityId": payload.title,
                    "title": "Event submitted"
                ]
            ))
            onCreated?()
            showSuccess = true
        } catch {
            if (error as NSError).code == 401 {
                sessionManager.signOut()
                errorMessage = "auth.session_expired".localized
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
