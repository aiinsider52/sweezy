import SwiftUI
import UIKit

private let letterLanguages: [(code: String, title: String)] = [("de", "Deutsch"), ("fr", "Français"), ("it", "Italiano"), ("en", "English")]

// MARK: - Application kit

/// "Підготувати відгук": how well the CV fits this job, what to fix, and a ready motivation letter,
/// email, tailored profile and likely interview questions in the employer's language.
struct ApplicationKitView: View {
    let job: APIClient.JobItem
    let cv: CVResume?
    var onUseLetter: ((String) async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @State private var letterLanguage: String
    @State private var kit: CareerAPI.Kit?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var showInterview = false
    @State private var copied: String?
    @State private var savedToTracker = false

    init(job: APIClient.JobItem, cv: CVResume?, onUseLetter: ((String) async -> Void)? = nil) {
        self.job = job
        self.cv = cv
        self.onUseLetter = onUseLetter
        _letterLanguage = State(initialValue: CareerAPI.defaultLetterLanguage(for: job))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.pageBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if cv == nil {
                            CareerNotice(icon: "person.text.rectangle", text: "career.kit.need_cv".localized)
                        } else if isLoading {
                            CareerThinking(lines: ["career.kit.stage.match", "career.kit.stage.letter", "career.kit.stage.questions"])
                                .padding(.top, 30)
                        } else if let kit {
                            result(kit)
                        } else {
                            intro
                        }
                        if let errorMessage { CareerNotice(icon: "exclamationmark.triangle.fill", text: errorMessage, warning: true) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) { dismiss() }
                }
            }
            .overlay(alignment: .bottom) { CopiedToast(text: copied) }
            .fullScreenCover(isPresented: $showPaywall) { SubscriptionView(source: .cv) }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--preview-career-kit") { kit = .debugSample }
                #endif
            }
            .fullScreenCover(isPresented: $showInterview) {
                InterviewCoachView(job: job, cvSummary: kit?.cvSummary ?? cv?.personal.summary ?? "", preferredLanguage: letterLanguage)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("career.kit.eyebrow".localized, systemImage: "wand.and.stars")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(JourneyVisual.accentText)
            Text(job.title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text([job.company, job.location].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(JourneyVisual.secondaryText)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                bullet("chart.bar.fill", "career.kit.includes.fit")
                bullet("envelope.fill", "career.kit.includes.letter")
                bullet("person.crop.rectangle", "career.kit.includes.summary")
                bullet("questionmark.bubble.fill", "career.kit.includes.questions")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder))

            Text("career.kit.letter_language".localized.uppercased())
                .font(.system(size: 11, weight: .bold)).tracking(0.8)
                .foregroundColor(JourneyVisual.secondaryText)
            languagePicker

            Button { Task { await generate() } } label: {
                Label("career.kit.generate".localized, systemImage: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(JourneyVisual.lime, in: Capsule())
                    .shadow(color: JourneyVisual.lime.opacity(0.4), radius: 14, y: 6)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
            .accessibilityIdentifier("career.kit.generate")
        }
    }

    private var languagePicker: some View {
        HStack(spacing: 2) {
            ForEach(letterLanguages, id: \.code) { item in
                Button { withAnimation(.easeInOut(duration: 0.2)) { letterLanguage = item.code } } label: {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(letterLanguage == item.code ? .black : JourneyVisual.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(letterLanguage == item.code ? JourneyVisual.lime : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(JourneyVisual.softSurface, in: Capsule())
    }

    private func bullet(_ icon: String, _ key: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 34, height: 34)
                .background(JourneyVisual.lime, in: Circle())
            Text(key.localized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func result(_ kit: CareerAPI.Kit) -> some View {
        // Fit
        HStack(alignment: .center, spacing: 16) {
            JourneyProgressRing(done: kit.fitScore, total: 100, size: 84, lineWidth: 9)
            VStack(alignment: .leading, spacing: 4) {
                Text("career.kit.fit".localized.uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(0.8)
                    .foregroundColor(JourneyVisual.secondaryText)
                Text(kit.verdict)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.lime.opacity(0.7), lineWidth: 1.5))

        if !kit.strengths.isEmpty || !kit.gaps.isEmpty {
            CareerCard(title: "career.kit.strengths_gaps".localized) {
                ForEach(kit.strengths, id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(JourneyVisual.primaryText)
                        .labelStyle(TintedIconLabel(tint: JourneyVisual.accentStrong))
                }
                ForEach(kit.gaps, id: \.self) { gap in
                    VStack(alignment: .leading, spacing: 3) {
                        Label(gap.title, systemImage: "arrow.up.right.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(JourneyVisual.primaryText)
                            .labelStyle(TintedIconLabel(tint: JourneyVisual.coral))
                        Text(gap.advice)
                            .font(.system(size: 14))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .padding(.leading, 28)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }

        CareerDocumentCard(
            title: "career.kit.letter".localized, text: kit.coverLetter, serif: true,
            onCopy: { copy(kit.coverLetter) },
            onPDF: { exportLetterPDF(kit) }
        )
        if let onUseLetter {
            Button {
                Task {
                    await onUseLetter(kit.coverLetter)
                    savedToTracker = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } label: {
                Label(savedToTracker ? "career.kit.saved_to_tracker".localized : "career.kit.save_to_tracker".localized,
                      systemImage: savedToTracker ? "checkmark.circle.fill" : "tray.and.arrow.down.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Theme.Colors.card, in: Capsule())
                    .overlay(Capsule().stroke(JourneyVisual.softBorder))
            }
            .disabled(savedToTracker)
        }

        CareerDocumentCard(
            title: "career.kit.email".localized,
            text: "\(kit.emailSubject)\n\n\(kit.emailBody)",
            onCopy: { copy("\(kit.emailSubject)\n\n\(kit.emailBody)") }
        )
        CareerDocumentCard(title: "career.kit.summary".localized, text: kit.cvSummary, onCopy: { copy(kit.cvSummary) })

        CareerCard(title: "career.kit.questions".localized) {
            ForEach(Array(kit.interviewQuestions.enumerated()), id: \.offset) { index, question in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(width: 24, height: 24)
                        .background(JourneyVisual.lime, in: Circle())
                    Text(question)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(JourneyVisual.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button { showInterview = true } label: {
                Label("career.interview.start_cta".localized, systemImage: "mic.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(JourneyVisual.black, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
            .padding(.top, 4)
        }

        HStack(spacing: 10) {
            languagePicker
            Button { Task { await generate() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(JourneyVisual.lime, in: Circle())
            }
            .accessibilityLabel("career.kit.regenerate".localized)
        }
        Text("career.ai_disclaimer".localized)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(JourneyVisual.secondaryText)
    }

    private func generate() async {
        guard let cv else { return }
        errorMessage = nil
        withAnimation { isLoading = true }
        defer { withAnimation { isLoading = false } }
        do {
            let result = try await CareerAPI.applicationKit(job: job, cv: cv, letterLanguage: letterLanguage)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { kit = result }
            appContainer.telemetry.info("career_kit_generated", source: "jobs", meta: ["fit": String(result.fitScore), "lang": letterLanguage])
            if result.fitScore >= 70 { Celebration.fire() }
        } catch {
            if (error as NSError).code == 402 { showPaywall = true } else { errorMessage = error.localizedDescription }
        }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        copied = "letters.copied".localized
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            copied = nil
        }
    }

    private func exportLetterPDF(_ kit: CareerAPI.Kit) {
        let name = (cv?.personal.fullName ?? "").replacingOccurrences(of: " ", with: "_")
        guard let url = try? PaginatedTextPDFExporter().export(
            text: kit.coverLetter,
            filename: "Motivationsschreiben_\(name.isEmpty ? "Sweezy" : name).pdf",
            title: "Motivationsschreiben — \(job.title)"
        ) else { return }
        presentShare([url])
    }
}

// MARK: - Interview coach

/// A realistic mock interview for one job, in the language of the job, with feedback after every
/// answer and a final score. Answers can be typed or dictated with the keyboard's microphone.
struct InterviewCoachView: View {
    let job: APIClient.JobItem
    let cvSummary: String
    var preferredLanguage = "de"

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    private struct Entry: Identifiable, Hashable {
        let id = UUID()
        let message: CareerAPI.InterviewMessage
        var feedback: CareerAPI.InterviewTurn?
    }

    @State private var language: String?
    @State private var entries: [Entry] = []
    @State private var draft = ""
    @State private var isWaiting = false
    @State private var finished: CareerAPI.InterviewTurn?
    @State private var progress = (current: 0, total: 6)
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.pageBackground.ignoresSafeArea()
                if language == nil {
                    start
                } else {
                    conversation
                }
            }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--preview-interview") {
                    language = "de"
                    progress = (2, 6)
                    entries = [
                        Entry(message: .init(role: "interviewer", content: "Erzählen Sie uns kurz etwas über sich und warum Sie sich bei uns bewerben.")),
                        Entry(message: .init(role: "candidate", content: "Ich bin Product Designer mit sechs Jahren Erfahrung. Ich habe in Kyjiw ein Design System für eine Bank aufgebaut."),
                              feedback: CareerAPI.InterviewTurn(feedback: "Гарний старт: конкретний досвід і результат. Додай, чому саме ця компанія — це те, що вони хочуть почути.", score: 4,
                                                                betterAnswer: "Ich bin Product Designer mit sechs Jahren Erfahrung, zuletzt habe ich ein Design System für eine Bank aufgebaut, das die Entwicklungszeit um 30 % verkürzt hat. Helvetia Digital reizt mich, weil Sie Versicherungen einfacher machen – genau daran möchte ich mitarbeiten.",
                                                                nextQuestion: nil, done: false, finalSummary: nil, overallScore: nil, questionNumber: 2, totalQuestions: 6)),
                        Entry(message: .init(role: "interviewer", content: "Wie gehen Sie vor, wenn Nutzerfeedback und Business-Ziele sich widersprechen?")),
                    ]
                }
                #endif
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) { dismiss() }
                }
                if language != nil && finished == nil {
                    ToolbarItem(placement: .principal) {
                        Text("career.interview.progress".localized(with: progress.current, progress.total))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(JourneyVisual.secondaryText)
                            .contentTransition(.numericText())
                    }
                }
            }
            .fullScreenCover(isPresented: $showPaywall) { SubscriptionView(source: .cv) }
        }
    }

    private var start: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle().fill(JourneyVisual.lime.opacity(0.25)).frame(width: 150, height: 150).blur(radius: 20)
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundColor(JourneyVisual.accentStrong)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                Text("career.interview.title".localized)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(JourneyVisual.primaryText)
                Text("career.interview.subtitle".localized(with: job.title))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("career.interview.language".localized.uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(0.8)
                    .foregroundColor(JourneyVisual.secondaryText)
                    .padding(.top, 6)
                ForEach(letterLanguages + [("uk", "Українська")], id: \.code) { item in
                    Button { begin(in: item.code) } label: {
                        HStack {
                            Text(item.title)
                                .font(.system(size: 17, weight: .bold))
                            Spacer()
                            if item.code == preferredLanguage {
                                Text("career.interview.recommended".localized)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8).frame(height: 22)
                                    .background(JourneyVisual.lime, in: Capsule())
                            }
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(JourneyVisual.primaryText)
                        .padding(.horizontal, 18)
                        .frame(height: 56)
                        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
                }
                Label("career.interview.tip".localized, systemImage: "mic.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(entries) { entry in
                            bubble(entry).id(entry.id)
                            if let feedback = entry.feedback, feedback.feedback != nil {
                                FeedbackCard(turn: feedback).id("\(entry.id)-feedback")
                            }
                        }
                        if isWaiting { TypingBubble().id("typing") }
                        if let finished { FinalCard(turn: finished, onRestart: restart).id("final") }
                        if let errorMessage { CareerNotice(icon: "exclamationmark.triangle.fill", text: errorMessage, warning: true) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: entries.count) { _, _ in scrollToEnd(proxy) }
                .onChange(of: isWaiting) { _, _ in scrollToEnd(proxy) }
                .onChange(of: finished) { _, _ in scrollToEnd(proxy) }
            }
            if finished == nil { inputBar }
        }
    }

    private func bubble(_ entry: Entry) -> some View {
        let mine = entry.message.role == "candidate"
        return HStack {
            if mine { Spacer(minLength: 40) }
            Text(entry.message.content)
                .font(.system(size: 16, weight: mine ? .medium : .semibold))
                .foregroundColor(mine ? .black : JourneyVisual.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(mine ? JourneyVisual.lime : Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(mine ? .clear : JourneyVisual.softBorder))
                .fixedSize(horizontal: false, vertical: true)
                .transition(.move(edge: mine ? .trailing : .leading).combined(with: .opacity))
            if !mine { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("career.interview.answer_placeholder".localized, text: $draft, axis: .vertical)
                .focused($inputFocused)
                .lineLimit(1...6)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder))
            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.black)
                    .frame(width: 46, height: 46)
                    .background(JourneyVisual.lime, in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWaiting)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .accessibilityLabel("career.interview.send".localized)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(JourneyVisual.pageBackground.ignoresSafeArea(edges: .bottom))
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if finished != nil { proxy.scrollTo("final", anchor: .bottom) }
            else if isWaiting { proxy.scrollTo("typing", anchor: .bottom) }
            else if let last = entries.last { proxy.scrollTo(last.feedback?.feedback != nil ? "\(last.id)-feedback" : last.id as AnyHashable, anchor: .bottom) }
        }
    }

    private func begin(in code: String) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { language = code }
        appContainer.telemetry.info("interview_started", source: "jobs", meta: ["lang": code])
        Task { await advance() }
    }

    private func restart() {
        entries = []
        finished = nil
        errorMessage = nil
        withAnimation { language = nil }
    }

    private func send() async {
        let answer = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        draft = ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            entries.append(Entry(message: .init(role: "candidate", content: answer)))
        }
        await advance()
    }

    private func advance() async {
        guard let language else { return }
        errorMessage = nil
        withAnimation { isWaiting = true }
        defer { withAnimation { isWaiting = false } }
        do {
            let turn = try await CareerAPI.interviewTurn(
                job: job, cvSummary: cvSummary, interviewLanguage: language,
                history: entries.map(\.message), totalQuestions: progress.total
            )
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                if turn.feedback != nil, let index = entries.lastIndex(where: { $0.message.role == "candidate" }) {
                    entries[index].feedback = turn
                }
                progress = (min(turn.questionNumber, turn.totalQuestions), turn.totalQuestions)
                if let question = turn.nextQuestion {
                    entries.append(Entry(message: .init(role: "interviewer", content: question)))
                }
                if turn.done {
                    finished = turn
                    inputFocused = false
                }
            }
            if turn.done {
                appContainer.telemetry.info("interview_finished", source: "jobs", meta: ["score": String(turn.overallScore ?? 0)])
                if (turn.overallScore ?? 0) >= 60 { Celebration.fire() }
            }
        } catch {
            if (error as NSError).code == 402 { showPaywall = true } else { errorMessage = error.localizedDescription }
        }
    }

    private struct FeedbackCard: View {
        let turn: CareerAPI.InterviewTurn
        @State private var showAnswer = false

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= (turn.score ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(star <= (turn.score ?? 0) ? JourneyVisual.accentStrong : JourneyVisual.secondaryText.opacity(0.4))
                    }
                    Spacer()
                    Text("career.interview.coach".localized)
                        .font(.system(size: 11, weight: .bold)).tracking(0.6)
                        .foregroundColor(JourneyVisual.secondaryText)
                }
                if let feedback = turn.feedback {
                    Text(feedback)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(JourneyVisual.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let better = turn.betterAnswer {
                    Button { withAnimation(.easeInOut(duration: 0.25)) { showAnswer.toggle() } } label: {
                        Label(showAnswer ? "career.interview.hide_better".localized : "career.interview.show_better".localized,
                              systemImage: showAnswer ? "chevron.up" : "lightbulb.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(JourneyVisual.accentText)
                    }
                    if showAnswer {
                        Text(better)
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(JourneyVisual.primaryText)
                            .padding(12)
                            .background(JourneyVisual.lime.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(14)
            .background(JourneyVisual.softSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.leading, 30)
        }
    }

    private struct FinalCard: View {
        let turn: CareerAPI.InterviewTurn
        let onRestart: () -> Void

        var body: some View {
            VStack(spacing: 14) {
                JourneyProgressRing(done: turn.overallScore ?? 0, total: 100, size: 110, lineWidth: 11)
                Text("career.interview.done".localized)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(JourneyVisual.primaryText)
                if let summary = turn.finalSummary {
                    Text(summary)
                        .font(.system(size: 15))
                        .foregroundColor(JourneyVisual.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: onRestart) {
                    Label("career.interview.again".localized, systemImage: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(JourneyVisual.lime, in: Capsule())
                }
            }
            .padding(20)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JourneyVisual.lime.opacity(0.7), lineWidth: 1.5))
            .padding(.top, 8)
        }
    }

    private struct TypingBubble: View {
        @State private var phase = 0.0
        var body: some View {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(JourneyVisual.secondaryText)
                        .frame(width: 7, height: 7)
                        .opacity(0.3 + 0.7 * abs(sin(phase + Double(index) * 0.7)))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Theme.Colors.card, in: Capsule())
            .overlay(Capsule().stroke(JourneyVisual.softBorder))
            .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = .pi * 2 } }
        }
    }
}

// MARK: - Shared pieces

struct CareerCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold)).tracking(0.8)
                .foregroundColor(JourneyVisual.secondaryText)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder))
    }
}

private struct CareerDocumentCard: View {
    let title: String
    let text: String
    var serif = false
    let onCopy: () -> Void
    var onPDF: (() -> Void)?
    @State private var expanded = false

    var body: some View {
        CareerCard(title: title) {
            Text(text)
                .font(.system(size: 14, design: serif ? .serif : .default))
                .foregroundColor(JourneyVisual.primaryText)
                .lineLimit(expanded ? nil : 7)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            HStack(spacing: 8) {
                Button { withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() } } label: {
                    Text((expanded ? "letters.reply.less" : "letters.reply.more").localized)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(JourneyVisual.accentText)
                        .lineLimit(1)
                        .fixedSize()
                }
                Spacer(minLength: 4)
                iconButton("doc.on.doc", label: "letters.copy".localized, action: onCopy)
                if let onPDF { chip("doc.richtext", "PDF", action: onPDF) }
                ShareLink(item: text) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(JourneyVisual.primaryText)
                        .frame(width: 32, height: 32)
                        .background(JourneyVisual.softSurface, in: Circle())
                }
            }
        }
    }

    private func iconButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(JourneyVisual.primaryText)
                .frame(width: 32, height: 32)
                .background(JourneyVisual.softSurface, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func chip(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(JourneyVisual.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(JourneyVisual.softSurface, in: Capsule())
        }
    }
}

struct CareerNotice: View {
    let icon: String
    let text: String
    var warning = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundColor(warning ? Theme.Colors.warning : JourneyVisual.accentStrong)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background((warning ? Theme.Colors.warning : JourneyVisual.lime).opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Lime orb with stages ticking by while the AI works.
struct CareerThinking: View {
    let lines: [String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = 0
    @State private var spin = false

    var body: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: [JourneyVisual.lime, JourneyVisual.lime.opacity(0.1), JourneyVisual.lime], center: .center))
                    .frame(width: 110, height: 110)
                    .blur(radius: 14)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(JourneyVisual.accentStrong)
                    .symbolEffect(.pulse, options: .repeating)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, key in
                    HStack(spacing: 10) {
                        Image(systemName: index < active ? "checkmark.circle.fill" : (index == active ? "circle.dotted" : "circle"))
                            .foregroundColor(index <= active ? JourneyVisual.accentStrong : JourneyVisual.secondaryText.opacity(0.5))
                        Text(key.localized)
                            .font(.system(size: 15, weight: index == active ? .bold : .medium))
                            .foregroundColor(index <= active ? JourneyVisual.primaryText : JourneyVisual.secondaryText)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { spin = true }
        }
        .task {
            for step in 1..<lines.count {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.spring(response: 0.35)) { active = step }
            }
        }
    }
}

struct CopiedToast: View {
    let text: String?
    var body: some View {
        Group {
            if let text {
                Label(text, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(JourneyVisual.black.opacity(0.88), in: Capsule())
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: text)
    }
}

private struct TintedIconLabel: LabelStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            configuration.icon.foregroundColor(tint).frame(width: 20)
            configuration.title.fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
func presentShare(_ items: [Any]) {
    guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
          var top = scene.keyWindow?.rootViewController else { return }
    while let presented = top.presentedViewController { top = presented }
    let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
    controller.popoverPresentationController?.sourceView = top.view
    top.present(controller, animated: true)
}

#if DEBUG
extension CareerAPI.Kit {
    static let debugSample = CareerAPI.Kit(
        fitScore: 78,
        verdict: "Сильний збіг за досвідом і навичками. Головне, що варто підтягнути, — німецька до B2.",
        strengths: ["6 років у продуктовому дизайні та власна дизайн-система", "Досвід досліджень користувачів і Figma на експертному рівні"],
        gaps: [CareerAPI.Gap(title: "Німецька B2 (у тебе B1)", advice: "Вкажи, що зараз на курсі B2, і дату іспиту — це знімає ризик для роботодавця."),
               CareerAPI.Gap(title: "Дозвіл на роботу", advice: "Статус S дає право працювати; коротко згадай це в листі.")],
        cvSummary: "Product Designer mit 6 Jahren Erfahrung in Fintech und E-Commerce. Aufbau eines Design Systems für eine Bank, starke Nutzerforschung und Figma-Expertise.",
        coverLetter: "Olena Kovalenko\nSeestrasse 5, 8002 Zürich\n\nHelvetia Digital AG\nPersonalabteilung\n8001 Zürich\n\nZürich, 23. November 2026\n\nBewerbung als UX/UI Designerin (80–100 %)\n\nSehr geehrte Damen und Herren\n\nmit grossem Interesse habe ich Ihre Ausschreibung gelesen. In den letzten sechs Jahren habe ich als Product Designerin digitale Produkte für Banken und Onlinehändler gestaltet und ein Design System aufgebaut, das die Entwicklungszeit deutlich verkürzt hat.\n\nNutzerforschung ist für mich der Ausgangspunkt jeder Lösung …\n\nFreundliche Grüsse\nOlena Kovalenko",
        emailSubject: "Bewerbung als UX/UI Designerin – Olena Kovalenko",
        emailBody: "Sehr geehrte Damen und Herren\n\nanbei sende ich Ihnen meine Bewerbungsunterlagen für die Stelle als UX/UI Designerin. Ich freue mich auf Ihre Rückmeldung.\n\nFreundliche Grüsse\nOlena Kovalenko",
        interviewQuestions: ["Erzählen Sie uns von einem Projekt, auf das Sie stolz sind.", "Wie arbeiten Sie mit Entwicklern zusammen?", "Wie testen Sie Ihre Designs mit Nutzern?", "Warum möchten Sie bei uns arbeiten?", "Wo sehen Sie sich in drei Jahren?"],
        letterLanguage: "de"
    )
}
#endif
