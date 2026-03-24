import SwiftUI

struct MyEventsView: View {
    var onEventsChanged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var events: [EventListing] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedEvent: EventListing?
    @State private var eventToEdit: EventListing?
    @State private var eventToDelete: EventListing?

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptivePageBackground()

                if isLoading {
                    ProgressView("common.loading".localized)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            summaryHero

                            if events.isEmpty {
                                emptyState
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(events) { event in
                                        MyEventCard(
                                            event: event,
                                            onOpen: { selectedEvent = event },
                                            onEdit: { eventToEdit = event },
                                            onDelete: { eventToDelete = event }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .padding(.bottom, 24)
                    }
                    .refreshable { await loadEvents() }
                }
            }
            .navigationTitle("events.my_events".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) { dismiss() }
                }
            }
            .task { await loadEvents() }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(eventId: event.id, initialEvent: event)
                    .presentationDetents([.large])
            }
            .sheet(item: $eventToEdit) { event in
                EditEventView(event: event) { updated in
                    replaceEvent(updated)
                    onEventsChanged?()
                }
            }
            .alert("events.delete_title".localized, isPresented: .init(
                get: { eventToDelete != nil },
                set: { if !$0 { eventToDelete = nil } }
            )) {
                Button("common.cancel".localized, role: .cancel) { eventToDelete = nil }
                Button("common.delete".localized, role: .destructive) {
                    guard let eventToDelete else { return }
                    Task { await deleteEvent(eventToDelete) }
                }
            } message: {
                Text("events.delete_message".localized)
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

    private var summaryHero: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.9), Theme.Colors.primary.opacity(0.85), Theme.Colors.accentTurquoise.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("events.cabinet_title".localized)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("events.cabinet_subtitle".localized)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                }

                HStack(spacing: 10) {
                    summaryPill(title: "events.cabinet.total".localized, value: events.count)
                    summaryPill(title: "marketplace.status.approved".localized, value: approvedCount)
                    summaryPill(title: "marketplace.status.pending".localized, value: pendingCount)
                    summaryPill(title: "marketplace.status.rejected".localized, value: rejectedCount)
                }
            }
            .padding(18)
        }
    }

    private func summaryPill(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(Theme.Colors.textTertiary)
            Text("events.empty_my_title".localized)
                .font(.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("events.empty_my_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var approvedCount: Int { events.filter { $0.status == .approved }.count }
    private var pendingCount: Int { events.filter { $0.status == .pending }.count }
    private var rejectedCount: Int { events.filter { $0.status == .rejected }.count }

    private func loadEvents() async {
        isLoading = events.isEmpty
        do {
            events = try await APIClient.fetchMyEvents()
        } catch {
            if (error as NSError).code == 401 {
                sessionManager.signOut()
                errorMessage = "auth.session_expired".localized
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func deleteEvent(_ event: EventListing) async {
        do {
            try await APIClient.deleteEvent(id: event.id)
            events.removeAll { $0.id == event.id }
            eventToDelete = nil
            onEventsChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceEvent(_ updated: EventListing) {
        if let index = events.firstIndex(where: { $0.id == updated.id }) {
            events[index] = updated
        }
    }
}

private struct MyEventCard: View {
    let event: EventListing
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(event.category.color.opacity(0.16))
                        .frame(width: 48, height: 48)
                    Image(systemName: event.category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(event.category.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        EventStatusBadge(status: event.status)
                        ListingBadgePill(text: event.category.displayName, color: event.category.color)
                    }
                }

                Spacer()
            }

            HStack(spacing: 14) {
                Label(event.city, systemImage: "mappin.circle.fill")
                Label("\(event.viewCount)", systemImage: "eye.fill")
                if let date = event.startsAt {
                    Text(date, style: .date)
                }
            }
            .font(.caption)
            .foregroundColor(Theme.Colors.textSecondary)

            if let reason = event.rejectionReason, event.status == .rejected {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                cabinetButton(title: "marketplace.open".localized, icon: "arrow.up.right.square") { onOpen() }
                cabinetButton(title: "marketplace.edit".localized, icon: "square.and.pencil") { onEdit() }
                cabinetButton(title: "common.delete".localized, icon: "trash", role: .destructive) { onDelete() }
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

    private func cabinetButton(title: String, icon: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.Colors.adaptiveSurface)
            .foregroundColor(role == .destructive ? .red : Theme.Colors.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct EventStatusBadge: View {
    let status: EventListingStatus

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var title: String {
        switch status {
        case .pending: return "marketplace.status.pending".localized
        case .approved: return "marketplace.status.approved".localized
        case .rejected: return "marketplace.status.rejected".localized
        }
    }

    private var color: Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}
