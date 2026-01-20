//
//  AppointmentsView.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI

struct AppointmentsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appointments: [Appointment] = []
    @State private var showingAddAppointment = false
    @State private var selectedSegment = 0
    @State private var isLoading = false
    
    private let segments = ["appointments.upcoming".localized, "appointments.past".localized]
    
    private var upcomingAppointments: [Appointment] {
        appointments.filter { !$0.isPast }.sorted { $0.dateTime < $1.dateTime }
    }
    
    private var pastAppointments: [Appointment] {
        appointments.filter { $0.isPast }.sorted { $0.dateTime > $1.dateTime }
    }
    
    var body: some View {
        NavigationStack {
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
                    appointments.append(appointment)
                }
            }
            .featureOnboarding(.appointments)
        }
        .onAppear {
            isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                loadAppointments()
                isLoading = false
            }
        }
    }
    
    private var appointmentsListSection: some View {
        Group {
            if isLoading {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        AppointmentShimmerRow()
                            .padding(.horizontal, Theme.Spacing.md)
                    }
                }
            } else if currentAppointments.isEmpty {
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
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            VStack(spacing: Theme.Spacing.sm) {
                Text("appointments.no_appointments".localized)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text("Add your first appointment to get started")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            PrimaryButton("appointments.add".localized) {
                showingAddAppointment = true
            }
            .frame(maxWidth: 200)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var appointmentsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(currentAppointments) { appointment in
                    AppointmentCard(appointment: appointment)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }
    
    private func loadAppointments() {
        // Mock appointments
        appointments = [
            Appointment(
                title: "Municipality Registration",
                description: "Register arrival with local authorities",
                category: .government,
                dateTime: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
            ),
            Appointment(
                title: "Doctor Appointment",
                description: "General health checkup",
                category: .healthcare,
                dateTime: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            )
        ]
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
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        if let description = appointment.description {
                            Text(description)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
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
                    .foregroundColor(Theme.Colors.secondaryText)
                    
                    if let location = appointment.location {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "location")
                                .font(.caption)
                            Text(location.name)
                                .font(Theme.Typography.caption)
                        }
                        .foregroundColor(Theme.Colors.secondaryText)
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
    let onSave: (Appointment) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: AppointmentCategory = .government
    @State private var selectedDate = Date()
    @State private var locationName = ""
    @State private var isSaving = false
    
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
            .navigationTitle("appointments.add".localized)
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
        
        let appointment = Appointment(
            title: title,
            description: description.isEmpty ? nil : description,
            category: selectedCategory,
            dateTime: selectedDate,
            location: location
        )
        
        onSave(appointment)
        dismiss()
    }
}

#Preview {
    AppointmentsView()
}
