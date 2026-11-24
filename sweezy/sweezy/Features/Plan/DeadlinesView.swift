import SwiftUI

/// "My deadlines": permit, passport, insurance, tax and any other date the user must not miss.
/// Every date gets local reminders 30, 7 and 1 day before, at 09:00.
struct DeadlinesView: View {
    var showsCloseButton = false

    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var editor: DeadlineEditorTarget?

    private var items: [ExpiryItem] { appContainer.lifeAdmin.expiryItems }

    var body: some View {
        ZStack {
            JourneyVisual.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if items.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(items) { item in row(item) }
                        }
                    }
                    reminderNote
                }
                .padding(.horizontal, 20)
                .padding(.top, showsCloseButton ? 56 : 12)
                .padding(.bottom, 120)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsCloseButton {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .frame(width: 38, height: 38)
                        .background(Theme.Colors.card, in: Circle())
                        .overlay(Circle().stroke(JourneyVisual.softBorder))
                }
                .accessibilityLabel("common.close".localized)
                .padding(.trailing, 16)
                .padding(.top, 12)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AuthPrimaryButton(title: "deadline.add".localized, identifier: "deadlines.add") {
                editor = DeadlineEditorTarget(item: nil, kind: suggestedKind)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(JourneyVisual.pageBackground.opacity(0.96).ignoresSafeArea(edges: .bottom))
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appContainer.lifeAdmin.prepareDocuments(for: appContainer.userProfile) }
        .sheet(item: $editor) { target in
            DeadlineEditorSheet(target: target)
                .environmentObject(appContainer)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier("deadlines.screen")
    }

    /// First kind the user has not filled in yet, so "Add" opens on the most likely one.
    private var suggestedKind: DeadlineKind {
        let used = Set(items.map(\.kind))
        return [DeadlineKind.permit, .insurance, .passport, .tax].first { !used.contains($0) } ?? .other
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("deadline.eyebrow".localized)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundColor(JourneyVisual.accentText)
            Text("deadline.title".localized)
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(JourneyVisual.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text("deadline.subtitle".localized)
                .font(.system(size: 15))
                .foregroundColor(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ item: ExpiryItem) -> some View {
        Button { editor = DeadlineEditorTarget(item: item, kind: item.kind) } label: {
            HStack(spacing: 14) {
                JourneyCategoryIcon(symbol: item.kind.icon, swatch: item.kind.swatch, size: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .lineLimit(2)
                    Text(item.date.formatted(.dateTime.day().month(.wide).year().locale(AppLanguage.current.locale)))
                        .font(.system(size: 13))
                        .foregroundColor(JourneyVisual.secondaryText)
                }
                Spacer(minLength: 8)
                countdownPill(item)
            }
            .padding(14)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder))
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
        .contextMenu {
            if let url = item.kind.source(for: appContainer.lifeAdmin.reminderCountry) {
                Button { openURL(url) } label: { Label("deadline.how_to".localized, systemImage: "arrow.up.right") }
            }
            Button(role: .destructive) { appContainer.lifeAdmin.removeDeadline(item) } label: {
                Label("deadline.delete".localized, systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.countdown)
    }

    private func countdownPill(_ item: ExpiryItem) -> some View {
        let urgent = item.daysLeft <= 7
        let soon = item.daysLeft <= 30
        return Text(item.countdown)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(urgent ? .white : .black)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                urgent ? Color(red: 0.86, green: 0.27, blue: 0.22) : (soon ? Color(red: 1, green: 0.82, blue: 0.4) : JourneyVisual.lime),
                in: Capsule()
            )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            StoryScene(name: "documents", height: 170)
            Text("deadline.empty".localized)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 8) {
                ForEach([DeadlineKind.permit, .insurance, .passport, .tax, .drivingLicense]) { kind in
                    Button { editor = DeadlineEditorTarget(item: nil, kind: kind) } label: {
                        Label(kind.title, systemImage: kind.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(JourneyVisual.primaryText)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(Theme.Colors.card, in: Capsule())
                            .overlay(Capsule().stroke(JourneyVisual.softBorder))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96, hapticStyle: .light))
                }
            }
        }
    }

    private var reminderNote: some View {
        Label("deadline.reminder_note".localized, systemImage: "bell.badge")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(JourneyVisual.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct DeadlineEditorTarget: Identifiable {
    let id = UUID()
    let item: ExpiryItem?
    let kind: DeadlineKind
}

private struct DeadlineEditorSheet: View {
    let target: DeadlineEditorTarget

    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var kind: DeadlineKind
    @State private var customTitle: String
    @State private var date: Date
    @FocusState private var focus: Field?

    private enum Field { case title }

    init(target: DeadlineEditorTarget) {
        self.target = target
        _kind = State(initialValue: target.kind)
        let personalTitle = target.item.flatMap { $0.title == $0.kind.title ? nil : $0.title } ?? ""
        _customTitle = State(initialValue: personalTitle)
        _date = State(initialValue: target.item?.date ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date())
    }

    private var needsTitle: Bool { kind == .other }
    private var canSave: Bool { !needsTitle || !customTitle.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text(target.item == nil ? "deadline.add".localized : "deadline.edit".localized)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(DeadlineKind.allCases) { option in
                        Button { withAnimation(.easeOut(duration: 0.15)) { kind = option } } label: {
                            VStack(spacing: 7) {
                                JourneyCategoryIcon(symbol: option.icon, swatch: option.swatch, size: 34, selected: kind == option)
                                Text(option.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(JourneyVisual.primaryText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.85)
                            }
                            .frame(maxWidth: .infinity, minHeight: 84)
                            .background(kind == option ? JourneyVisual.lime.opacity(0.22) : Theme.Colors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(kind == option ? JourneyVisual.accentStrong : JourneyVisual.softBorder, lineWidth: kind == option ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(kind == option ? .isSelected : [])
                    }
                }

                if kind == .other || kind == .tax || kind == .drivingLicense {
                    AuthField(
                        label: "deadline.field.title".localized,
                        placeholder: kind == .other ? "deadline.field.title_placeholder".localized : kind.title,
                        icon: "pencil",
                        text: $customTitle,
                        focus: $focus,
                        field: .title,
                        capitalization: .sentences
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text((kind.expires ? "deadline.field.expires" : "deadline.field.due").localized.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1)
                        .foregroundColor(JourneyVisual.secondaryText)
                    DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(JourneyVisual.accentStrong)
                        .environment(\.locale, AppLanguage.current.locale)
                        .padding(8)
                        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill").foregroundColor(JourneyVisual.accentText)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(kind.hint)
                            .font(.system(size: 13))
                            .foregroundColor(JourneyVisual.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if let url = kind.source(for: appContainer.lifeAdmin.reminderCountry) {
                            Button { openURL(url) } label: {
                                Label("deadline.how_to".localized, systemImage: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(JourneyVisual.accentText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(JourneyVisual.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let item = target.item {
                    Button(role: .destructive) {
                        appContainer.lifeAdmin.removeDeadline(item)
                        dismiss()
                    } label: {
                        Text("deadline.delete".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .padding(.top, 8)
        }
        .background(JourneyVisual.pageBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AuthPrimaryButton(title: "deadline.save".localized, isEnabled: canSave, identifier: "deadlines.save") {
                Task { await save() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(JourneyVisual.pageBackground.ignoresSafeArea(edges: .bottom))
        }
    }

    @MainActor
    private func save() async {
        let title = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        appContainer.lifeAdmin.saveDeadline(kind: kind, title: title.isEmpty ? nil : title, date: date, editing: target.item)
        // Ask for notifications here, where a reminder is the obvious point, rather than at launch.
        let service = appContainer.notificationService
        await service.refreshAuthorizationStatus()
        if service.authorizationStatus == .notDetermined {
            _ = await service.requestPermission()
        }
        appContainer.lifeAdmin.scheduleReminderSync()
        dismiss()
    }
}
