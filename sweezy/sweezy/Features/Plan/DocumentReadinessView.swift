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
                VStack(alignment: .leading, spacing: 18) {
                    header
                    progressCard
                    // One list with hairlines instead of a stack of cards.
                    VStack(spacing: 0) {
                        let documents = appContainer.lifeAdmin.documents
                        ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                            documentRow(document)
                            if index < documents.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
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
                .navigationTitle(document.displayTitle)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("companion.documents.title".localized)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(JourneyVisual.primaryText)
                .accessibilityAddTraits(.isHeader)
            Label("companion.documents.privacy".localized, systemImage: "lock.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    /// Ring, count and one line from Sweezy; the line changes for a moment when something gets ticked.
    private var progressCard: some View {
        HStack(spacing: 14) {
            JourneyProgressRing(done: readyCount, total: max(appContainer.lifeAdmin.documents.count, 1), size: 56, lineWidth: 6, showsPercent: true)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(completedDocumentTitle == nil
                     ? "companion.documents.intro".localized
                     : "companion.documents.done".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .contentTransition(.opacity)
                Text(completedDocumentTitle ?? "companion.documents.subtitle".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                Text("\(readyCount)/\(appContainer.lifeAdmin.documents.count)")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(JourneyVisual.accentText)
                    .accessibilityLabel("\("companion.documents.progress".localized): \(readyCount)/\(appContainer.lifeAdmin.documents.count)")
                    .accessibilityIdentifier("documents.progress")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: completedDocumentTitle)
    }

    private func documentRow(_ document: ReadinessDocument) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Button {
                let markingReady = !document.isReady
                appContainer.lifeAdmin.toggleDocument(document.id)
                if markingReady, let updated = appContainer.lifeAdmin.documents.first(where: { $0.id == document.id }), updated.status != .expired {
                    completedDocumentTitle = document.displayTitle
                    companionReaction += 1
                } else {
                    completedDocumentTitle = nil
                }
            } label: {
                Image(systemName: document.isReady ? "checkmark.circle.fill" : "circle")
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: document.isReady)
                    .font(.system(size: 24))
                    .foregroundStyle(document.isReady ? JourneyVisual.accentStrong : JourneyVisual.secondaryText.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(document.displayTitle). \(document.isReady ? "companion.documents.unmark".localized : "companion.documents.mark".localized)")
            .accessibilityValue(statusText(document.status))
            .accessibilityIdentifier("documents.toggle.\(document.id)")

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(document.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(JourneyVisual.primaryText)
                    Spacer(minLength: 4)
                    Text(statusText(document.status))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(statusColor(document.status))
                }
                Text(document.displayRequiredFor)
                    .font(.system(size: 13))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { documentActions(document) }
                    VStack(alignment: .leading, spacing: 6) { documentActions(document) }
                }
                .padding(.top, 4)
            }
            .padding(.top, 10)
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func documentActions(_ document: ReadinessDocument) -> some View {
        Button {
            expiryDate = document.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            editingDocument = document
        } label: {
            documentChip(expiryText(document), icon: "calendar")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("documents.expiry.\(document.id)")
        if let url = document.sourceURL {
            Button { openURL(url) } label: {
                documentChip(document.sourceTitle, icon: "arrow.up.right")
            }
            .buttonStyle(.plain)
        }
    }

    /// Small capsule for a row action; the padding keeps the tap area 44 pt tall.
    private func documentChip(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(JourneyVisual.primaryText)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(JourneyVisual.pageBackground, in: Capsule())
            .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
            .padding(.vertical, 7)
            .contentShape(Rectangle())
    }

    private var readyCount: Int { appContainer.lifeAdmin.documents.filter { $0.isReady && $0.status != .expired }.count }
    private var progress: CGFloat {
        guard !appContainer.lifeAdmin.documents.isEmpty else { return 0 }
        return CGFloat(readyCount) / CGFloat(appContainer.lifeAdmin.documents.count)
    }

    private func expiryText(_ document: ReadinessDocument) -> String {
        document.expiryDate?.formatted(.dateTime.day().month(.abbreviated).year().locale(AppLanguage.current.locale)) ?? "companion.documents.add_expiry".localized
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
