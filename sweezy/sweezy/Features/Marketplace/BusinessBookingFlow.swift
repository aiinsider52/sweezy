import SwiftUI

struct BusinessBookingFlow: View {
    @Environment(\.dismiss) private var dismiss
    let profile: PublicBusinessProfile
    let listingID: String

    @State private var selectedServiceID: String
    @State private var selectedDay = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
    @State private var slots: [BusinessBookingSlot] = []
    @State private var selectedSlot: BusinessBookingSlot?
    @State private var notes = ""
    @State private var loading = false
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var booked: BusinessBooking?

    init(profile: PublicBusinessProfile, listingID: String) {
        self.profile = profile
        self.listingID = listingID
        let preferred = profile.services.first(where: { $0.listingID == listingID }) ?? profile.services.first
        _selectedServiceID = State(initialValue: preferred?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.025, green: 0.035, blue: 0.028).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        hero
                        servicePicker
                        dayPicker
                        slotPicker
                        notesField
                        confirmation
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 36)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task(id: "\(selectedServiceID)-\(selectedDay.timeIntervalSince1970)") { await loadSlots() }
            .alert("Запис надіслано", isPresented: Binding(get: { booked != nil }, set: { if !$0 { booked = nil } })) {
                Button("Готово") { dismiss() }
            } message: {
                Text("Бізнес отримав заявку. Після підтвердження статус оновиться у Sweezy.")
            }
            .alert("Не вдалося записатися", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2.bold())
                    .foregroundStyle(.black)
                    .frame(width: 54, height: 54)
                    .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 17))
                Spacer()
                if profile.isVerified {
                    Label("ПЕРЕВІРЕНО", systemImage: "checkmark.seal.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(JourneyVisual.lime)
                }
            }
            Text("Записатися до\n\(profile.displayName)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("Обери послугу та вільний час. Заявка потрапить прямо в календар бізнесу.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(.top, 10)
    }

    @ViewBuilder private var servicePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("1 · Послуга")
            ForEach(profile.services) { service in
                Button {
                    selectedServiceID = service.id
                    selectedSlot = nil
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: service.id == selectedServiceID ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(service.id == selectedServiceID ? JourneyVisual.lime : .white.opacity(0.28))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(service.title).font(.headline).foregroundStyle(.white)
                            Text("\(service.durationMinutes) хв · \(service.priceText)").font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                    }
                    .padding(15)
                    .background(.white.opacity(service.id == selectedServiceID ? 0.09 : 0.045), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(service.id == selectedServiceID ? JourneyVisual.lime.opacity(0.55) : .white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("2 · День")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(nextDays, id: \.self) { day in
                        Button {
                            selectedDay = day
                            selectedSlot = nil
                        } label: {
                            VStack(spacing: 5) {
                                Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption2.bold())
                                Text(day.formatted(.dateTime.day())).font(.title3.weight(.black))
                            }
                            .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: selectedDay) ? .black : .white)
                            .frame(width: 58, height: 66)
                            .background(Calendar.current.isDate(day, inSameDayAs: selectedDay) ? JourneyVisual.lime : .white.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var slotPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("3 · Час")
            if loading {
                ProgressView().tint(JourneyVisual.lime).frame(maxWidth: .infinity).padding(24)
            } else if slots.isEmpty {
                Text("На цей день вільних слотів немає.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.52))
                    .frame(maxWidth: .infinity)
                    .padding(22)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 9)], spacing: 9) {
                    ForEach(slots) { slot in
                        Button {
                            selectedSlot = slot
                        } label: {
                            Text(slot.startsAt.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline.bold())
                                .foregroundStyle(selectedSlot == slot ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(selectedSlot == slot ? JourneyVisual.lime : .white.opacity(0.07), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("4 · Коментар")
            TextField("Що бізнесу варто знати?", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .foregroundStyle(.white)
                .padding(15)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
        }
    }

    private var confirmation: some View {
        VStack(spacing: 12) {
            if let selectedSlot, let service = selectedService {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.title).font(.headline).foregroundStyle(.white)
                        Text(selectedSlot.startsAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Text(service.priceText).font(.caption.bold()).foregroundStyle(JourneyVisual.lime)
                }
            }
            Button { Task { await submit() } } label: {
                HStack {
                    if submitting { ProgressView().tint(.black) }
                    Text(submitting ? "Надсилаємо…" : "Підтвердити запис").font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(JourneyVisual.lime, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedSlot == nil || submitting)
            .opacity(selectedSlot == nil ? 0.45 : 1)
            Text("Запис підтверджує власник. Скасувати можна у Sweezy.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.38))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(JourneyVisual.lime.opacity(0.2)))
    }

    private var nextDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date().addingTimeInterval(86_400))
        return (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var selectedService: BusinessServiceItem? {
        profile.services.first(where: { $0.id == selectedServiceID })
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption.bold()).tracking(1.5).foregroundStyle(JourneyVisual.lime)
    }

    private func loadSlots() async {
        guard !selectedServiceID.isEmpty else { slots = []; return }
        loading = true
        defer { loading = false }
        do {
            slots = try await BusinessProAPI.publicSlots(userID: profile.userID, serviceID: selectedServiceID, day: selectedDay)
        } catch {
            slots = []
            errorMessage = error.localizedDescription
        }
    }

    private func submit() async {
        guard let selectedSlot else { return }
        submitting = true
        defer { submitting = false }
        do {
            booked = try await BusinessProAPI.requestPublicBooking(
                userID: profile.userID,
                payload: .init(serviceID: selectedServiceID, startsAt: selectedSlot.startsAt, notes: notes)
            )
        } catch {
            errorMessage = error.localizedDescription
            await loadSlots()
        }
    }
}
