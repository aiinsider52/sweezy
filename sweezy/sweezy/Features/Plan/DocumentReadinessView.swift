import SwiftUI

struct DocumentReadinessView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.openURL) private var openURL
    @State private var editingDocument: ReadinessDocument?
    @State private var expiryDate = Date()
    @State private var companionReaction = 0
    @State private var completedDocumentTitle: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            JourneyVisual.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    progressCard
                    ForEach(appContainer.lifeAdmin.documents) { document in
                        documentRow(document)
                    }
                }
                .padding(20)
                .padding(.bottom, 128)
            }
        }
        .statusBarScrim()
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("documents.screen")
        .task(id: companionReaction) {
            guard companionReaction > 0 else { return }
            do {
                try await Task.sleep(for: .seconds(2))
                completedDocumentTitle = nil
            } catch { }
        }
        .onAppear { appContainer.lifeAdmin.prepareDocuments(for: appContainer.userProfile) }
        .sheet(item: $editingDocument) { document in
            NavigationStack {
                Form {
                    DatePicker("companion.documents.expiry".localized, selection: $expiryDate, displayedComponents: .date)
                    Button("companion.documents.remove_expiry".localized) {
                        appContainer.lifeAdmin.setExpiry(nil, for: document.id)
                        editingDocument = nil
                    }
                }
                .navigationTitle(document.title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("companion.documents.save".localized) {
                            appContainer.lifeAdmin.setExpiry(expiryDate, for: document.id)
                            editingDocument = nil
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Sweezy sorting folders and ticking a checklist at a library desk.
            StoryScene(name: "documents", height: 190)
                .padding(.bottom, 8)

            Text("companion.documents.title".localized)
                .font(.largeTitle.bold())
                .foregroundStyle(JourneyVisual.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text("companion.documents.privacy".localized)
                .font(.footnote)
                .foregroundStyle(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SweezyCompanionHeader(
                title: completedDocumentTitle == nil
                    ? "companion.documents.intro".localized
                    : "companion.documents.done".localized,
                subtitle: completedDocumentTitle ?? "companion.documents.subtitle".localized,
                pose: .documents,
                size: 124,
                reaction: companionReaction,
                onPhoto: false
            )
            HStack {
                Text("companion.documents.progress".localized)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(readyCount)/\(appContainer.lifeAdmin.documents.count)")
                    .font(.headline.monospacedDigit())
                    .accessibilityIdentifier("documents.progress")
            }
            .foregroundStyle(Theme.Colors.textPrimary)
            ProgressView(value: Double(progress))
                .tint(JourneyVisual.accentStrong)
                .accessibilityLabel("companion.documents.progress".localized)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: progress)
        }
        .padding(18)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private func documentRow(_ document: ReadinessDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    let markingReady = !document.isReady
                    appContainer.lifeAdmin.toggleDocument(document.id)
                    if markingReady, let updated = appContainer.lifeAdmin.documents.first(where: { $0.id == document.id }), updated.status != .expired {
                        completedDocumentTitle = document.title
                        companionReaction += 1
                    } else {
                        completedDocumentTitle = nil
                    }
                } label: {
                    Image(systemName: document.isReady ? "checkmark.circle.fill" : "circle")
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: document.isReady)
                        .font(.title2)
                        .foregroundStyle(document.isReady ? Theme.Colors.primaryDark : Theme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(document.title). \(document.isReady ? "companion.documents.unmark".localized : "companion.documents.mark".localized)")
                .accessibilityValue(statusText(document.status))
                .accessibilityIdentifier("documents.toggle.\(document.id)")

                VStack(alignment: .leading, spacing: 5) {
                    Text(document.title)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(document.requiredFor)
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(statusText(document.status))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor(document.status))
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { documentActions(document) }
                VStack(alignment: .leading, spacing: 2) { documentActions(document) }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(14)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func documentActions(_ document: ReadinessDocument) -> some View {
        if let url = document.sourceURL {
            Button { openURL(url) } label: {
                Label(document.sourceTitle, systemImage: "arrow.up.right.square")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        Button {
            expiryDate = document.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            editingDocument = document
        } label: {
            Label(expiryText(document), systemImage: "calendar")
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("documents.expiry.\(document.id)")
    }

    private var readyCount: Int { appContainer.lifeAdmin.documents.filter { $0.isReady && $0.status != .expired }.count }
    private var progress: CGFloat {
        guard !appContainer.lifeAdmin.documents.isEmpty else { return 0 }
        return CGFloat(readyCount) / CGFloat(appContainer.lifeAdmin.documents.count)
    }

    private func expiryText(_ document: ReadinessDocument) -> String {
        document.expiryDate?.formatted(.dateTime.day().month(.abbreviated).year()) ?? "companion.documents.add_expiry".localized
    }

    private func statusText(_ status: ReadinessDocumentStatus) -> String {
        switch status {
        case .missing: return "companion.documents.missing".localized
        case .ready: return "companion.documents.ready".localized
        case .expiring: return "companion.documents.expiring".localized
        case .expired: return "companion.documents.expired".localized
        }
    }

    private func statusColor(_ status: ReadinessDocumentStatus) -> Color {
        switch status {
        case .ready: return Theme.Colors.primaryDark
        case .expiring: return .orange
        case .expired: return .red
        case .missing: return Theme.Colors.textSecondary
        }
    }
}
