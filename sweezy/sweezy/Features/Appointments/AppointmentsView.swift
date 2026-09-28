//
//  AppointmentsView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI

struct AppointmentsView: View {
    @EnvironmentObject private var repository: AppointmentRepository
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddAppointment = false
    @State private var editingAppointment: Appointment?
    @State private var selectedSegment = 0
    /// Only a sheet needs its own Close; when pushed, the back button already does that job.
    var showsCloseButton = false
    
    private let segments = ["appointments.upcoming".localized, "appointments.past".localized]
    
    private var upcomingAppointments: [Appointment] {
        repository.appointments.filter { !$0.isPast }.sorted { $0.dateTime < $1.dateTime }
    }
    
    private var pastAppointments: [Appointment] {
        repository.appointments.filter { $0.isPast }.sorted { $0.dateTime > $1.dateTime }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            segmentControl
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

            appointmentsListSection
        }
        .background(JourneyVisual.pageBackground.ignoresSafeArea())
        .navigationTitle("appointments.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddAppointment = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAppointment) {
            AddAppointmentView { appointment in
                repository.add(appointment)
            }
        }
        .sheet(item: $editingAppointment) { appointment in
            AddAppointmentView(appointment: appointment) { updatedAppointment in
                repository.update(updatedAppointment)
            }
        }
        .featureOnboarding(.appointments)
    }

    private var segmentControl: some View {
        HStack(spacing: 4) {
            ForEach(0..<segments.count, id: \.self) { index in
                let selected = selectedSegment == index
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selectedSegment = index }
                } label: {
                    Text(segments[index])
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(selected ? .black : JourneyVisual.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(selected ? JourneyVisual.lime : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.Colors.card, in: Capsule())
        .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
    }
    
    private var appointmentsListSection: some View {
        Group {
            if currentAppointments.isEmpty {
                EmptyStateView(
                    systemImage: "calendar",
                    title: "appointments.no_appointments".localized,
                    subtitle: "appointments.empty_subtitle".localized,
                    actionTitle: "appointments.add".localized
                ) {
                    showingAddAppointment = true
                }
            } else {
                appointmentsList
            }
        }
    }
    
    private var currentAppointments: [Appointment] {
        selectedSegment == 0 ? upcomingAppointments : pastAppointments
    }
    
    private var appointmentsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                // swipeActions only work inside List, so edit/delete live in a menu on the card.
                ForEach(currentAppointments) { appointment in
                    AppointmentCard(
                        appointment: appointment,
                        onEdit: { editingAppointment = appointment },
                        onDelete: { repository.delete(appointment) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 120)
        }
    }
}

struct AppointmentShimmerRow: View {
    @State private var animate = false
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 14)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .overlay(
            LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.3), Color.white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .rotationEffect(.degrees(30))
                .offset(x: animate ? 400 : -400)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

struct AppointmentCard: View {
    let appointment: Appointment
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Date tile: the thing people scan for first.
            VStack(spacing: 0) {
                Text(appointment.dateTime.formatted(.dateTime.day().locale(locale)))
                    .font(.system(size: 22, weight: .black).monospacedDigit())
                Text(appointment.dateTime.formatted(.dateTime.month(.abbreviated).locale(locale)).uppercased())
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(appointment.isPast ? JourneyVisual.secondaryText : .black)
            .frame(width: 56, height: 62)
            .background(appointment.isPast ? JourneyVisual.softSurface : JourneyVisual.lime,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(appointment.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    if onEdit != nil || onDelete != nil {
                        Menu {
                            if let onEdit {
                                Button(action: onEdit) {
                                    Label("appointments.edit".localized, systemImage: "pencil")
                                }
                            }
                            if let onDelete {
                                Button(role: .destructive, action: onDelete) {
                                    Label("common.delete".localized, systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(JourneyVisual.secondaryText)
                                .frame(width: 32, height: 32)
                                .background(JourneyVisual.softSurface, in: Circle())
                        }
                        .accessibilityLabel("common.more".localized)
                    }
                }

                Label(appointment.dateTime.formatted(.dateTime.hour().minute().locale(locale)), systemImage: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)

                if let location = appointment.location {
                    Label(location.name, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(1)
                }

                if let description = appointment.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    JourneyCategoryIcon(symbol: appointment.category.iconName, swatch: appointment.category.swatch, size: 22)
                    Text(appointment.category.localizedName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                    Spacer(minLength: 4)
                    if appointment.isToday {
                        statusPill("appointments.today".localized, prominent: true)
                    } else {
                        statusPill(appointment.status.localizedName, prominent: false)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
        .contextMenu {
            if let onEdit {
                Button(action: onEdit) { Label("appointments.edit".localized, systemImage: "pencil") }
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) { Label("common.delete".localized, systemImage: "trash") }
            }
        }
    }

    private func statusPill(_ text: String, prominent: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(prominent ? .black : JourneyVisual.secondaryText)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(prominent ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule())
    }
}

struct AddAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    let existingAppointment: Appointment?
    let onSave: (Appointment) -> Void
    
    @State private var title: String
    @State private var description: String
    @State private var selectedCategory: AppointmentCategory
    @State private var selectedDate: Date
    @State private var locationName: String
    @State private var isSaving = false

    init(appointment: Appointment? = nil, onSave: @escaping (Appointment) -> Void) {
        self.existingAppointment = appointment
        self.onSave = onSave
        _title = State(initialValue: appointment?.title ?? "")
        _description = State(initialValue: appointment?.description ?? "")
        _selectedCategory = State(initialValue: appointment?.category ?? .government)
        _selectedDate = State(initialValue: appointment?.dateTime ?? Date())
        _locationName = State(initialValue: appointment?.location?.name ?? appointment?.location?.address.city ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("appointments.appointment_title".localized, text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(AppointmentCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.localizedName)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section("appointments.date".localized) {
                    DatePicker("Date and Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("appointments.location".localized) {
                    TextField("Location name", text: $locationName)
                }
            }
            .journeyForm()
            .navigationTitle(existingAppointment == nil ? "appointments.add".localized : "appointments.edit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isSaving = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            saveAppointment()
                            isSaving = false
                        }
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("common.save".localized)
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
        .journeyScreen(.city, darkness: 0.7)
    }
    
    private func saveAppointment() {
        let location = locationName.isEmpty ? nil : AppointmentLocation(
            name: locationName,
            address: Address(
                street: "",
                houseNumber: "",
                postalCode: "",
                city: locationName,
                canton: .zurich
            )
        )

        let appointment: Appointment
        if let existingAppointment {
            appointment = existingAppointment.updating(
                title: title,
                description: description.isEmpty ? nil : description,
                category: selectedCategory,
                dateTime: selectedDate,
                location: location
            )
        } else {
            appointment = Appointment(
                title: title,
                description: description.isEmpty ? nil : description,
                category: selectedCategory,
                dateTime: selectedDate,
                location: location
            )
        }
        
        onSave(appointment)
        dismiss()
    }
}

#Preview {
    AppointmentsView()
        .environmentObject(AppContainer().appointmentRepository)
}
