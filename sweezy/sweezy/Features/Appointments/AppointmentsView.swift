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
    
    private let segments = ["appointments.upcoming".localized, "appointments.past".localized]
    
    private var upcomingAppointments: [Appointment] {
        repository.appointments.filter { !$0.isPast }.sorted { $0.dateTime < $1.dateTime }
    }
    
    private var pastAppointments: [Appointment] {
        repository.appointments.filter { $0.isPast }.sorted { $0.dateTime > $1.dateTime }
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // Segment control
                Picker("Appointments", selection: $selectedSegment) {
                    ForEach(0..<segments.count, id: \.self) { index in
                        Text(segments[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                
                // Appointments list
                appointmentsListSection
        }
        .navigationTitle("appointments.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("common.close".localized) {
                    dismiss()
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
        .journeyScreen(.city, darkness: 0.66)
    }
    
    private var appointmentsListSection: some View {
        Group {
            if currentAppointments.isEmpty {
                EmptyStateView(
                    systemImage: "calendar",
                    title: "appointments.no_appointments".localized,
                    subtitle: "guides.no_results_subtitle".localized,
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
                ForEach(currentAppointments) { appointment in
                    AppointmentCard(appointment: appointment)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                editingAppointment = appointment
                            } label: {
                                Label("appointments.edit".localized, systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                repository.delete(appointment)
                            } label: {
                                Label("common.delete".localized, systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
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
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(appointment.title)
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        if let description = appointment.description {
                            Text(description)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: appointment.category.iconName)
                        .font(.title2)
                        .foregroundColor(Color(appointment.category.color))
                }
                
                // Date and time
                HStack(spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(appointment.formattedDate)
                            .font(Theme.Typography.caption)
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                    
                    if let location = appointment.location {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "location")
                                .font(.caption)
                            Text(location.name)
                                .font(Theme.Typography.caption)
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                
                // Status
                HStack {
                    TagChip(appointment.status.localizedName, style: .status)
                    
                    Spacer()
                    
                    if appointment.isToday {
                        TagChip("appointments.today".localized, style: .category)
                    } else if appointment.isUpcoming {
                        TagChip("Upcoming", style: .filter)
                    }
                }
            }
        }
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
