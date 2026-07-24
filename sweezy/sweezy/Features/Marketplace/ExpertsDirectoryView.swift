//
//  ExpertsDirectoryView.swift
//  sweezy
//
//  Verified expert directory with specialty/language filters.
//

import SwiftUI

@MainActor
final class ExpertsDirectoryViewModel: ObservableObject {
    @Published var experts: [ServiceListing] = []
    @Published var isLoading = false
    @Published var error: String?

    @Published var specialty: ExpertSpecialty?
    @Published var language: String?
    @Published var canton: String?

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.fetchExperts(
                specialty: specialty?.rawValue,
                language: language,
                canton: canton
            )
            self.experts = result
            self.error = nil
        } catch {
            self.error = "\(error)"
        }
    }
}

struct ExpertsDirectoryView: View {
    @StateObject private var vm = ExpertsDirectoryViewModel()
    @EnvironmentObject private var appContainer: AppContainer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("experts.section.title".localized)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .padding(.horizontal, Theme.Spacing.md)

                filterBar

                if vm.isLoading && vm.experts.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if vm.experts.isEmpty {
                    Text("No experts match these filters yet.")
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(Theme.Spacing.md)
                } else {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(vm.experts) { expert in
                            NavigationLink(destination: ExpertDetailView(expert: expert).environmentObject(appContainer)) {
                                ExpertCard(expert: expert)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                appContainer.telemetry.retention(.expertViewed, source: "experts_list", message: nil, meta: ["id": expert.id])
                            })
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Color.clear)
        .navigationTitle("experts.section.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.reload() }
        .journeyScreen(.market, darkness: 0.7)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                pill(label: "All", isOn: vm.specialty == nil) {
                    vm.specialty = nil
                    Task { await vm.reload() }
                }
                ForEach(ExpertSpecialty.allCases) { spec in
                    pill(label: "\(spec.emoji) \(spec.localizedName)", isOn: vm.specialty == spec) {
                        vm.specialty = (vm.specialty == spec) ? nil : spec
                        Task { await vm.reload() }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private func pill(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(isOn ? Theme.Colors.primary : Theme.Colors.adaptiveCard)
                .foregroundColor(isOn ? .black : Theme.Colors.textPrimary)
                .clipShape(Capsule())
        }
    }
}

private struct ExpertCard: View {
    let expert: ServiceListing

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                if let spec = expert.expertSpecialtyEnum {
                    Text(spec.emoji)
                        .font(.system(size: 28))
                        .frame(width: 48, height: 48)
                        .background(Theme.Colors.primary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(expert.authorName)
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    if let spec = expert.expertSpecialtyEnum {
                        Text(spec.localizedName)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                Spacer()
            }
            Text(expert.expertBio ?? expert.description)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(3)
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(expert.expertLanguages.prefix(4), id: \.self) { lang in
                    Text(lang.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.Colors.adaptiveCard)
                        .clipShape(Capsule())
                }
                Spacer()
                if let hours = expert.responseTimeHours {
                    Text(String(format: NSLocalizedString("experts.response_time", comment: ""), hours))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .fill(Theme.Colors.adaptiveCard)
        )
    }
}

// MARK: - Expert detail

struct ExpertDetailView: View {
    let expert: ServiceListing
    @EnvironmentObject private var appContainer: AppContainer
    @State private var questions: [ExpertQuestion] = []
    @State private var showAskSheet = false
    @State private var showBookingSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(expert.authorName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                    }
                    if let spec = expert.expertSpecialtyEnum {
                        Text("\(spec.emoji) \(spec.localizedName)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.Colors.primary)
                    }
                }

                if let bio = expert.expertBio, !bio.isEmpty {
                    Text(bio).font(.system(size: 15))
                } else {
                    Text(expert.description).font(.system(size: 15))
                }

                HStack(spacing: 10) {
                    Button {
                        showBookingSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Записатися").font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(JourneyVisual.lime).foregroundColor(.black)
                        .cornerRadius(Theme.CornerRadius.lg)
                    }

                    Button {
                        showAskSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("experts.cta.ask".localized).font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.Colors.adaptiveCard).foregroundColor(Theme.Colors.textPrimary)
                        .cornerRadius(Theme.CornerRadius.lg)
                    }
                }

                if !questions.isEmpty {
                    Text("Recent answered questions")
                        .font(.system(size: 18, weight: .semibold))
                    ForEach(questions) { q in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(q.questionText).font(.system(size: 14, weight: .semibold))
                            if let answer = q.answerText {
                                Text(answer).font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                .fill(Theme.Colors.adaptiveCard)
                        )
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .journeyScreen(.market, darkness: 0.72)
        .task {
            self.questions = (try? await APIClient.fetchExpertQuestions(listingId: expert.id)) ?? []
        }
        .sheet(isPresented: $showAskSheet) {
            AskExpertView(expert: expert)
                .environmentObject(appContainer)
        }
        .sheet(isPresented: $showBookingSheet) {
            BookExpertAppointmentView(expert: expert)
                .environmentObject(appContainer)
        }
    }
}

private struct BookExpertAppointmentView: View {
    let expert: ServiceListing
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: "journey-market-consultant", blurRadius: 8, darkness: 0.76)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Консультація")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Label(expert.authorName, systemImage: "checkmark.seal.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(JourneyVisual.lime)

                        JourneyGlassPanel(cornerRadius: 22) {
                            VStack(alignment: .leading, spacing: 14) {
                                DatePicker("Дата і час", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                    .tint(JourneyVisual.lime)
                                TextField("Що потрібно обговорити", text: $notes, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding(12)
                                    .background(Color.black.opacity(0.24))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .foregroundColor(.white)
                            .padding(16)
                        }

                        JourneyPrimaryButton(title: didSave ? "Запит збережено" : "Зберегти зустріч") {
                            saveAppointment()
                        }
                        .disabled(didSave)

                        Text("Sweezy збереже зустріч і нагадування. Щоб підтвердити час з експертом, надішліть запит через «Запитати».")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.58))
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveAppointment() {
        let appointment = Appointment(
            title: "Консультація: \(expert.authorName)",
            description: notes.isEmpty ? expert.expertSpecialtyEnum?.localizedName : notes,
            category: .integration,
            dateTime: date,
            duration: 3600,
            contactInfo: ContactInfo(
                name: expert.authorName,
                title: "Sweezy Expert",
                phoneNumber: nil,
                email: nil,
                website: nil,
                department: nil
            )
        )
        appContainer.appointmentRepository.add(appointment)
        didSave = true
        appContainer.telemetry.info("expert_appointment_created", source: "experts", message: nil, meta: ["expert_id": expert.id])
    }
}

struct AskExpertView: View {
    let expert: ServiceListing
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var didSucceed = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("experts.qa.title".localized)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Replying to **\(expert.authorName)**")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("experts.qa.placeholder".localized)
                            .foregroundColor(Theme.Colors.textTertiary)
                            .padding(.top, 8).padding(.leading, 4)
                    }
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.adaptiveCard)
                .cornerRadius(Theme.CornerRadius.md)

                if didSucceed {
                    Text("experts.qa.thanks".localized)
                        .foregroundColor(Theme.Colors.success)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundColor(.red).font(.system(size: 13))
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text("experts.qa.submit".localized).font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(canSubmit ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.4))
                    .foregroundColor(.white).cornerRadius(Theme.CornerRadius.lg)
                }
                .disabled(!canSubmit)

                Spacer()
            }
            .padding(Theme.Spacing.md)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) { dismiss() }
                }
            }
        }
        .journeyScreen(.market, darkness: 0.74)
    }

    private var canSubmit: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 && !isSubmitting
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let lang = appContainer.userProfile?.preferredLanguage
        do {
            _ = try await APIClient.askExpert(
                listingId: expert.id,
                questionText: text.trimmingCharacters(in: .whitespacesAndNewlines),
                askerName: appContainer.userProfile?.fullName,
                askerLanguage: lang
            )
            didSucceed = true
            text = ""
            appContainer.telemetry.retention(.expertQuestionAsked, source: "ask_expert",
                                             message: nil, meta: ["id": expert.id])
            EventBus.shared.emit(GamEvent(
                type: .expertQuestionAsked,
                metadata: [
                    "entityId": expert.id,
                    "title": "Question to \(expert.authorName)"
                ]
            ))
            try? await Task.sleep(nanoseconds: 800_000_000)
            dismiss()
        } catch {
            errorMessage = "\(error)"
        }
    }
}
