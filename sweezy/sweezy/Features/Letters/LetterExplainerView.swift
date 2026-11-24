import PhotosUI
import SwiftUI
import UIKit
import VisionKit

/// "Розбери лист": photograph an official letter and get it explained in the app language,
/// with its deadline, payment details, where to go and who can help.
struct LetterExplainerView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var store = LetterStore.shared

    private enum Phase: Equatable {
        case idle
        case reading
        case explaining
    }

    @State private var phase: Phase = .idle
    @State private var preview: UIImage?
    @State private var showScanner = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var openedLetter: SavedLetter?
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var showAuth = false

    private var canScan: Bool { VNDocumentCameraViewController.isSupported }

    var body: some View {
        ZStack {
            JourneyVisual.pageBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if phase == .idle {
                        hero.journeyEntrance(delay: 0.02)
                        howItWorks.journeyEntrance(delay: 0.08)
                        actions.journeyEntrance(delay: 0.12)
                        if let errorMessage { errorBanner(errorMessage) }
                        privacyNote.journeyEntrance(delay: 0.16)
                        if !store.letters.isEmpty { archive.journeyEntrance(delay: 0.2) }
                    } else {
                        LetterScanningAnimation(image: preview, phase: phase == .reading ? 0 : 1)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 128)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: phase)
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { pages in
                showScanner = false
                if !pages.isEmpty { process(pages) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var pages: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        pages.append(image)
                    }
                }
                photoItems = []
                if !pages.isEmpty { process(pages) }
            }
        }
        .navigationDestination(item: $openedLetter) { letter in
            LetterResultView(letterID: letter.id)
                .statusBarScrim()
        }
        .fullScreenCover(isPresented: $showPaywall) { SubscriptionView(source: .letters) }
        .task { openDebugPreviewIfRequested() }
        .sheet(isPresented: $showAuth) {
            AuthEntryView(showsCloseButton: true) { showAuth = false }
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
    }

    // MARK: Intro

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("journey-tool-documents")
                .resizable()
                .scaledToFill()
                .frame(height: 250)
                .frame(maxWidth: .infinity)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.45), .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text("letters.title".localized)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(.white)
                Text("letters.subtitle".localized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Label("letters.badge.ai".localized, systemImage: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(JourneyVisual.lime, in: Capsule())
                .padding(14)
        }
    }

    private var howItWorks: some View {
        HStack(spacing: 10) {
            step(icon: "camera.viewfinder", text: "letters.how.scan".localized)
            step(icon: "text.magnifyingglass", text: "letters.how.explain".localized)
            step(icon: "bell.badge", text: "letters.how.remind".localized)
        }
    }

    private func step(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(JourneyVisual.accentStrong)
                .frame(width: 44, height: 44)
                .background(JourneyVisual.lime.opacity(0.22), in: Circle())
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(JourneyVisual.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if canScan {
                Button { start { showScanner = true } } label: {
                    Label("letters.scan".localized, systemImage: "doc.viewfinder.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(JourneyVisual.lime, in: Capsule())
                        .shadow(color: JourneyVisual.lime.opacity(0.4), radius: 16, y: 6)
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
                .accessibilityIdentifier("letters.scan")
            }
            if sessionManager.isAuthenticated {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 4, matching: .images) {
                    pickLabel(prominent: !canScan)
                }
                .accessibilityIdentifier("letters.pick")
            } else {
                Button { showAuth = true } label: { pickLabel(prominent: !canScan) }
                    .accessibilityIdentifier("letters.pick")
            }
        }
    }

    private func pickLabel(prominent: Bool) -> some View {
        Label("letters.pick".localized, systemImage: "photo.on.rectangle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(prominent ? .black : JourneyVisual.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(prominent ? JourneyVisual.lime : Theme.Colors.card, in: Capsule())
            .overlay(Capsule().stroke(prominent ? Color.clear : JourneyVisual.softBorder))
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(JourneyVisual.accentStrong)
            Text("letters.privacy".localized)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.Colors.warning)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.Colors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var archive: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("letters.archive".localized.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundColor(JourneyVisual.secondaryText)
            ForEach(store.letters) { letter in
                Button { openedLetter = letter } label: { LetterArchiveRow(letter: letter) }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
                    .contextMenu {
                        Button(role: .destructive) { store.remove(letter.id) } label: {
                            Label("common.delete".localized, systemImage: "trash")
                        }
                    }
            }
        }
    }

    // MARK: Flow

    private func openDebugPreviewIfRequested() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--preview-letter-scanning") {
            phase = .explaining
        } else if arguments.contains("--preview-letter"), openedLetter == nil {
            let sample = SavedLetter.debugSample
            if !store.letters.contains(where: { $0.id == sample.id }) { store.add(sample) }
            openedLetter = sample
        }
        #endif
    }

    private func start(_ action: () -> Void) {
        errorMessage = nil
        guard sessionManager.isAuthenticated else {
            showAuth = true
            return
        }
        action()
    }

    private func process(_ pages: [UIImage]) {
        errorMessage = nil
        preview = pages.first
        phase = .reading
        Task { @MainActor in
            do {
                let reading = try await LetterReader.read(pages)
                phase = .explaining
                let explanation = try await APIClient.explainLetter(text: reading.text)
                let letter = SavedLetter(id: UUID(), createdAt: Date(), explanation: explanation, payment: reading.payment, deadlineAdded: false)
                store.add(letter)
                appContainer.telemetry.track(.letterExplained, source: "letters", meta: [
                    "category": explanation.category,
                    "has_deadline": String(explanation.deadline != nil),
                    "has_payment": String(reading.payment != nil || explanation.amount != nil),
                    "pages": String(pages.count),
                ])
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                phase = .idle
                openedLetter = letter
            } catch {
                phase = .idle
                if (error as NSError).code == 402 {
                    appContainer.telemetry.track(.letterLimitReached, source: "letters")
                    showPaywall = true
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Result

struct LetterResultView: View {
    let letterID: UUID

    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var store = LetterStore.shared
    @State private var copied: String?
    @State private var specialistCategory: ServiceCategory?
    @State private var replyExpanded = false

    private var letter: SavedLetter? { store.letters.first { $0.id == letterID } }

    var body: some View {
        ZStack {
            JourneyVisual.pageBackground.ignoresSafeArea()
            if let letter {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        header(letter).journeyEntrance(delay: 0.02)
                        summary(letter.explanation).journeyEntrance(delay: 0.08)
                        if let date = letter.explanation.deadlineDate {
                            deadlineCard(letter, date: date).journeyEntrance(delay: 0.14)
                        }
                        if letter.payment != nil || letter.explanation.amount != nil {
                            paymentCard(letter).journeyEntrance(delay: 0.2)
                        }
                        if !letter.explanation.steps.isEmpty {
                            stepsCard(letter.explanation.steps).journeyEntrance(delay: 0.26)
                        }
                        quickActions(letter.explanation).journeyEntrance(delay: 0.3)
                        if let reply = letter.explanation.replyLetter {
                            replyCard(reply).journeyEntrance(delay: 0.34)
                        }
                        if !letter.explanation.warnings.isEmpty {
                            warnings(letter.explanation.warnings).journeyEntrance(delay: 0.38)
                        }
                        Text("letters.disclaimer".localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 128)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let copied {
                Label(copied, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(JourneyVisual.black.opacity(0.88), in: Capsule())
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: copied)
        .sheet(item: $specialistCategory) { category in
            MarketplaceView(initialCategory: category)
        }
    }

    private func header(_ letter: SavedLetter) -> some View {
        let kind = letter.explanation.kind
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                JourneyCategoryIcon(symbol: kind.icon, swatch: kind.swatch, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(kind.swatch.ink)
                    Text(letter.explanation.sender)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                urgencyBadge(letter.explanation.urgency)
            }
            Text(letter.explanation.title)
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func urgencyBadge(_ urgency: String) -> some View {
        let high = urgency == "high", low = urgency == "low"
        return Text("letters.urgency.\(urgency)".localized)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(high ? .white : .black)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(high ? Color(red: 0.86, green: 0.24, blue: 0.18) : (low ? JourneyVisual.softSurface : JourneyVisual.lime), in: Capsule())
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder))
    }

    private func label(_ key: String) -> some View {
        Text(key.localized.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundColor(JourneyVisual.secondaryText)
    }

    private func summary(_ explanation: LetterExplanation) -> some View {
        card {
            label("letters.section.about")
            Text(explanation.summary)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if !explanation.whatTheyWant.isEmpty {
                Divider().padding(.vertical, 2)
                label("letters.section.want")
                Text(explanation.whatTheyWant)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func deadlineCard(_ letter: SavedLetter, date: Date) -> some View {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: date).day ?? 0
        return HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 0) {
                Text(days < 0 ? "!" : "\(days)")
                    .font(.system(size: 40, weight: .heavy))
                    .monospacedDigit()
                Text("letters.days".localized)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(width: 86, height: 86)
            .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(letter.explanation.deadlineLabel ?? "letters.deadline".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                Button { addDeadline(letter, date: date) } label: {
                    Label(
                        letter.deadlineAdded ? "letters.deadline.added".localized : "letters.deadline.add".localized,
                        systemImage: letter.deadlineAdded ? "checkmark.circle.fill" : "bell.badge.fill"
                    )
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(letter.deadlineAdded ? JourneyVisual.accentText : JourneyVisual.primaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(letter.deadlineAdded ? JourneyVisual.lime.opacity(0.22) : JourneyVisual.softSurface, in: Capsule())
                }
                .disabled(letter.deadlineAdded)
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96, hapticStyle: .medium))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.lime.opacity(0.7), lineWidth: 1.5))
    }

    private func paymentCard(_ letter: SavedLetter) -> some View {
        let slip = letter.payment
        let amount = slip?.amount ?? letter.explanation.amount
        let currency = slip?.currency ?? letter.explanation.currency ?? ""
        return card {
            label("letters.section.payment")
            if let amount {
                Text("\(currency) \(amount.formatted(.number.precision(.fractionLength(2))))")
                    .font(.system(size: 32, weight: .heavy))
                    .monospacedDigit()
                    .foregroundColor(JourneyVisual.primaryText)
            }
            if let slip {
                if !slip.creditor.isEmpty { paymentRow("letters.payment.to", slip.creditor, copy: false) }
                paymentRow("IBAN", slip.formattedIBAN, copy: true)
                if let reference = slip.reference { paymentRow("letters.payment.reference", reference, copy: true) }
                Text("letters.payment.qr_hint".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("letters.payment.no_qr".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func paymentRow(_ titleKey: String, _ value: String, copy: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey.localized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)
                Text(value)
                    .font(.system(size: copy ? 14 : 15, weight: .semibold, design: copy ? .monospaced : .default))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(copy ? 1 : 2)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 6)
            if copy {
                Button { copyText(value.replacingOccurrences(of: " ", with: "")) } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .frame(width: 38, height: 38)
                        .background(JourneyVisual.softSurface, in: Circle())
                }
                .accessibilityLabel("letters.copy".localized)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(JourneyVisual.pageBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func stepsCard(_ steps: [String]) -> some View {
        card {
            label("letters.section.steps")
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .background(JourneyVisual.lime, in: Circle())
                    Text(step)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(JourneyVisual.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }
            }
        }
    }

    @ViewBuilder
    private func quickActions(_ explanation: LetterExplanation) -> some View {
        let category = specialistServiceCategory(explanation.specialist)
        if explanation.senderAddress != nil || category != nil {
            HStack(spacing: 10) {
                if let address = explanation.senderAddress {
                    actionTile(icon: "map.fill", title: "letters.action.map".localized) { openInMaps(address) }
                }
                if let category {
                    actionTile(icon: "person.badge.shield.checkmark.fill", title: "letters.action.specialist".localized) {
                        specialistCategory = category
                    }
                }
            }
        }
    }

    private func actionTile(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 38, height: 38)
                    .background(JourneyVisual.lime, in: Circle())
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(12)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder))
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97, hapticStyle: .light))
    }

    private func replyCard(_ reply: String) -> some View {
        card {
            HStack {
                label("letters.section.reply")
                Spacer()
                Button { copyText(reply) } label: {
                    Label("letters.copy".localized, systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(JourneyVisual.softSurface, in: Capsule())
                }
                ShareLink(item: reply) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .frame(width: 30, height: 30)
                        .background(JourneyVisual.softSurface, in: Circle())
                }
            }
            Text(reply)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(JourneyVisual.primaryText)
                .lineLimit(replyExpanded ? nil : 6)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Button { withAnimation(.easeInOut(duration: 0.25)) { replyExpanded.toggle() } } label: {
                Text((replyExpanded ? "letters.reply.less" : "letters.reply.more").localized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(JourneyVisual.accentText)
            }
        }
    }

    private func warnings(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.Colors.warning)
                    Text(item)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(JourneyVisual.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Actions

    private func addDeadline(_ letter: SavedLetter, date: Date) {
        let label = letter.explanation.deadlineLabel ?? letter.explanation.title
        appContainer.lifeAdmin.saveDeadline(kind: .other, title: "\(label) · \(letter.explanation.sender)", date: date)
        appContainer.telemetry.track(.letterDeadlineAdded, source: "letters", meta: ["category": letter.explanation.category])
        var updated = letter
        updated.deadlineAdded = true
        store.update(updated)
        Task { @MainActor in
            let service = appContainer.notificationService
            await service.refreshAuthorizationStatus()
            if service.authorizationStatus == .notDetermined {
                _ = await service.requestPermission()
            }
            appContainer.lifeAdmin.scheduleReminderSync()
        }
    }

    private func copyText(_ text: String) {
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        copied = "letters.copied".localized
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            copied = nil
        }
    }

    private func openInMaps(_ address: String) {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: address)]
        if let url = components.url { UIApplication.shared.open(url) }
    }

    private func specialistServiceCategory(_ specialist: String?) -> ServiceCategory? {
        switch specialist {
        case "translation": return .translation
        case "legal": return .legal
        case "accounting": return .accounting
        case "documents": return .documents
        default: return nil
        }
    }
}

// MARK: - Pieces

private struct LetterArchiveRow: View {
    let letter: SavedLetter

    var body: some View {
        let kind = letter.explanation.kind
        HStack(spacing: 12) {
            JourneyCategoryIcon(symbol: kind.icon, swatch: kind.swatch, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(letter.explanation.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(1)
                Text(letter.explanation.sender)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let date = letter.explanation.deadlineDate {
                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(JourneyVisual.lime, in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(JourneyVisual.secondaryText)
        }
        .padding(12)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder))
    }
}

/// A sheet of paper with a glowing lime line sweeping over it while the letter is read and explained.
struct LetterScanningAnimation: View {
    let image: UIImage?
    /// 0 while reading the text on the phone, 1 while the explanation is being written.
    let phase: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(JourneyVisual.lime.opacity(pulse ? 0.28 : 0.12))
                    .frame(width: 236, height: 316)
                    .blur(radius: 28)
                page
                    .frame(width: 210, height: 290)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [JourneyVisual.lime.opacity(0), JourneyVisual.lime.opacity(0.55), JourneyVisual.lime.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 70)
                        .overlay(Rectangle().fill(JourneyVisual.lime).frame(height: 3).shadow(color: JourneyVisual.lime, radius: 10))
                        .offset(y: sweep ? 250 : -30)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.8), lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 14)
                    .rotation3DEffect(.degrees(pulse ? 4 : -4), axis: (x: 0, y: 1, z: 0))
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 14) {
                stageRow("letters.stage.read".localized, state: phase == 0 ? .active : .done)
                stageRow("letters.stage.explain".localized, state: phase == 1 ? .active : .pending)
                stageRow("letters.stage.deadlines".localized, state: .pending)
            }
            .frame(maxWidth: 280, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { sweep = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var page: some View {
        if let image {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack(alignment: .topLeading) {
                Color.white
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<9, id: \.self) { index in
                        Capsule().fill(Color.black.opacity(0.1)).frame(width: index % 3 == 2 ? 110 : 170, height: 8)
                    }
                }
                .padding(20)
            }
        }
    }

    private enum StageState { case pending, active, done }

    private func stageRow(_ title: String, state: StageState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(state == .done ? JourneyVisual.lime : (state == .active ? JourneyVisual.lime.opacity(0.25) : JourneyVisual.softSurface))
                    .overlay(Circle().stroke(state == .pending ? JourneyVisual.softBorder : .clear, lineWidth: 1.5))
                    .frame(width: 28, height: 28)
                if state == .done {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .black)).foregroundColor(.black)
                } else if state == .active {
                    ProgressView().controlSize(.small).tint(JourneyVisual.accentStrong)
                }
            }
            Text(title)
                .font(.system(size: 16, weight: state == .active ? .bold : .medium))
                .foregroundColor(state == .pending ? JourneyVisual.secondaryText : JourneyVisual.primaryText)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: phase)
    }
}

/// VisionKit's document camera: edge detection, perspective correction and multi-page capture.
private struct DocumentScanner: UIViewControllerRepresentable {
    let onFinish: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void

        init(onFinish: @escaping ([UIImage]) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish((0..<min(scan.pageCount, 4)).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish([])
        }
    }
}

#if DEBUG
extension SavedLetter {
    /// A realistic tax bill for screenshots and UI checks without the camera or the network.
    static let debugSample = SavedLetter(
        id: UUID(uuidString: "6B1D7C2E-1A43-4F2B-9C0E-5A2D9E8F1B11")!,
        createdAt: Date(),
        explanation: LetterExplanation(
            sender: "Steueramt des Kantons Zürich",
            senderAddress: "Bändliweg 21, 8090 Zürich",
            category: "tax",
            title: "Рахунок за податки за 2025 рік",
            summary: "Податкова кантону Цюрих надіслала остаточний рахунок (Schlussrechnung) за податки 2025 року. Сума вже врахована з твоїх авансових платежів.",
            whatTheyWant: "Сплатити залишок податку до вказаної дати.",
            urgency: "high",
            deadline: Calendar.current.date(byAdding: .day, value: 24, to: Date()).map { date in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            },
            deadlineLabel: "Сплатити рахунок",
            amount: 1240.5,
            currency: "CHF",
            steps: [
                "Перевір, що в рахунку твоє ім'я та правильний рік",
                "Відскануй QR-код у банківському додатку або TWINT",
                "Збережи підтвердження оплати",
                "Якщо не згоден із сумою — подай заперечення (Einsprache) протягом 30 днів",
            ],
            replyLetter: "Sehr geehrte Damen und Herren\n\nIch habe Ihre Schlussrechnung vom [Datum] erhalten. Da ich mich in einer finanziell schwierigen Lage befinde, bitte ich Sie höflich um eine Ratenzahlung in [Anzahl] Raten.\n\nFreundliche Grüsse\n[Vorname Nachname]",
            replyLanguage: "de",
            specialist: "accounting",
            warnings: ["Після строку нараховують відсотки за прострочення (Verzugszins)."]
        ),
        payment: PaymentSlip(
            iban: "CH4431999123000889012",
            creditor: "Kantonales Steueramt Zürich",
            amount: 1240.5,
            currency: "CHF",
            reference: "210000000003139471430009017",
            message: "Staats- und Gemeindesteuern 2025"
        ),
        deadlineAdded: false
    )
}
#endif
