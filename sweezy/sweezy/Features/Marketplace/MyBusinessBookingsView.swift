import SwiftUI

struct MyBusinessBookingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bookings: [BusinessBooking] = []
    @State private var loading = true
    @State private var cancellingID: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.pageBackground.ignoresSafeArea()
                if loading {
                    ProgressView().tint(JourneyVisual.lime)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            header
                            if bookings.isEmpty { emptyState }
                            ForEach(bookings.sorted(by: { $0.startsAt > $1.startsAt })) { booking in bookingCard(booking) }
                        }
                        .padding(18).padding(.bottom, 32)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Мої записи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } } }
            .task { await load() }
            .alert("Не вдалося виконати дію", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Sweezy Booking", systemImage: "calendar.badge.checkmark").font(.caption.bold()).tracking(1.2).foregroundStyle(Theme.Colors.textPrimary)
            Text("Усі твої записи\nв одному місці").font(.system(size: 32, weight: .black, design: .default)).foregroundStyle(JourneyVisual.primaryText)
            Text("Статуси оновлює бізнес. Майбутній запис можна скасувати тут.").font(.subheadline).foregroundStyle(JourneyVisual.secondaryText)
        }
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "calendar.badge.plus").font(.system(size: 40)).foregroundStyle(Theme.Colors.textPrimary)
            Text("Записів поки немає").font(.title3.bold()).foregroundStyle(JourneyVisual.primaryText)
            Text("Відкрий послугу перевіреного бізнесу та обери вільний час.").font(.subheadline).foregroundStyle(JourneyVisual.secondaryText).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 42).padding(.horizontal, 24)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 24))
    }

    private func bookingCard(_ booking: BusinessBooking) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.businessName ?? "Sweezy business").font(.headline).foregroundStyle(JourneyVisual.primaryText)
                    if let service = booking.serviceTitle { Text(service).font(.caption).foregroundStyle(JourneyVisual.secondaryText) }
                    Text(booking.startsAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.bold()).foregroundStyle(Theme.Colors.textPrimary)
                }
                Spacer()
                statusBadge(booking.status)
            }
            if let location = booking.location, !location.isEmpty { Label(location, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(JourneyVisual.secondaryText) }
            if !booking.notes.isEmpty { Text(booking.notes).font(.caption).foregroundStyle(JourneyVisual.secondaryText).lineLimit(3) }
            if canCancel(booking) {
                Button { Task { await cancel(booking) } } label: {
                    HStack { if cancellingID == booking.id { ProgressView().tint(JourneyVisual.primaryText) }; Text("Скасувати запис"); Spacer(); Image(systemName: "xmark.circle") }
                        .font(.subheadline.bold()).foregroundStyle(JourneyVisual.primaryText).padding(.horizontal, 15).frame(height: 46)
                        .background(.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain).disabled(cancellingID != nil)
            }
        }
        .padding(17)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(JourneyVisual.softBorder))
    }

    private func statusBadge(_ status: String) -> some View {
        let title: String
        let color: Color
        switch status {
        case "confirmed": (title, color) = ("Підтверджено", JourneyVisual.lime)
        case "completed": (title, color) = ("Завершено", .cyan)
        case "cancelled": (title, color) = ("Скасовано", .red)
        case "no_show": (title, color) = ("Не відбувся", .orange)
        default: (title, color) = ("Очікує", .yellow)
        }
        return Text(title.uppercased()).font(.caption2.bold()).foregroundStyle(color).padding(.horizontal, 9).padding(.vertical, 6).background(color.opacity(0.12), in: Capsule())
    }

    private func canCancel(_ booking: BusinessBooking) -> Bool {
        booking.startsAt > Date() && !["cancelled", "completed", "no_show"].contains(booking.status)
    }

    private func load() async {
        loading = bookings.isEmpty
        defer { loading = false }
        do { bookings = try await BusinessProAPI.myPublicBookings() }
        catch { errorMessage = error.localizedDescription }
    }

    private func cancel(_ booking: BusinessBooking) async {
        cancellingID = booking.id
        defer { cancellingID = nil }
        do {
            let updated = try await BusinessProAPI.cancelPublicBooking(id: booking.id)
            if let index = bookings.firstIndex(where: { $0.id == updated.id }) { bookings[index] = updated }
        } catch { errorMessage = error.localizedDescription }
    }
}
