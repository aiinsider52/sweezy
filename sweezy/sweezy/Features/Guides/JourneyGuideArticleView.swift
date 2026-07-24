import SwiftUI

struct JourneyGuideArticleView: View {
    let guide: Guide

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scrollOffset: CGFloat = 0
    @State private var readingSeconds = 0
    @State private var didMarkRead = false

    private var sourceURL: URL? {
        guard let source = guide.source else { return nil }
        return URL(string: source)
    }

    private var relatedChecklist: Checklist? {
        if let raw = guide.relatedChecklistId, let id = UUID(uuidString: raw),
           let checklist = appContainer.contentService.getChecklist(by: id) {
            return checklist
        }

        let mapping: ChecklistCategory?
        switch guide.category {
        case .housing: mapping = .housing
        case .healthcare: mapping = .healthcare
        case .insurance: mapping = .insurance
        case .work: mapping = .work
        case .finance, .banking: mapping = .finance
        case .education: mapping = .education
        case .legal, .documents: mapping = .legal
        case .integration: mapping = .integration
        default: mapping = nil
        }
        return appContainer.contentService.checklists.first { $0.category == mapping }
    }

    var body: some View {
        ZStack(alignment: .top) {
            JourneyVisual.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero

                    VStack(alignment: .leading, spacing: 22) {
                        officialSourceCard

                        if let summary = guide.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            summaryCard(summary)
                        }

                        JourneyArticleMarkdown(markdown: guide.bodyMarkdown)

                        if !guide.links.isEmpty {
                            usefulLinks
                        }

                        if let relatedChecklist {
                            nextStepCard(relatedChecklist)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 72)
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: JourneyArticleOffsetKey.self,
                            value: -geometry.frame(in: .named("journeyArticleScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "journeyArticleScroll")
            .onPreferenceChange(JourneyArticleOffsetKey.self) { scrollOffset = max(0, $0) }

            readingProgress
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            NotificationCenter.default.post(name: .setJourneyBottomBarHidden, object: true)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .setJourneyBottomBarHidden, object: false)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard !didMarkRead else { return }
            readingSeconds += 1
            guard readingSeconds >= 20, scrollOffset > 260 else { return }
            didMarkRead = true
            if !appContainer.userStats.isGuideRead(id: guide.id) {
                appContainer.userStats.markGuideRead(id: guide.id)
                AppReviewManager.recordGuideRead()
                appContainer.analytics.track(
                    "guide_read",
                    properties: ["guide_id": guide.id, "category": guide.category.rawValue]
                )
            }
        }
    }

    private var hero: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                JourneyGuideHeroImage(guide: guide)
                    .frame(width: geometry.size.width, height: 408)
                    .clipped()

            LinearGradient(
                colors: [.black.opacity(0.12), .black.opacity(0.12), JourneyVisual.black],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Label(guide.category.localizedName, systemImage: guide.category.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))

                    if guide.isNew {
                        Text("NEW")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(JourneyVisual.lime)
                            .clipShape(Capsule())
                    }
                }

                Text(guide.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.48), radius: 12, y: 4)

                HStack(spacing: 16) {
                    Label("guides.reading_time".localized(with: guide.estimatedReadingTime), systemImage: "clock")
                    if let verifiedAt = guide.verifiedAt {
                        Label(verifiedAt.formatted(date: .abbreviated, time: .omitted), systemImage: "checkmark.seal.fill")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.74))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                    }
                    .accessibilityLabel("common.back".localized)

                    Spacer()

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(JourneyVisual.lime)
                            .frame(width: 42, height: 42)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                    }
                    .accessibilityLabel("common.share".localized)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(width: geometry.size.width, height: 408)
        }
        .frame(height: 408)
    }

    @ViewBuilder
    private var officialSourceCard: some View {
        if let sourceURL {
            Link(destination: sourceURL) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(JourneyVisual.lime)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("journey.guide.official_source".localized)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(JourneyVisual.lime)
                        Text(guide.sourceTitle ?? sourceURL.host() ?? "journey.guide.official_portal".localized)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        if let date = guide.verifiedAt {
                            Text("journey.guide.verified".localized(with: date.formatted(date: .long, time: .omitted)))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.48))
                        }
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 34, height: 34)
                        .background(JourneyVisual.lime)
                        .clipShape(Circle())
                }
                .padding(14)
                .background(Color.white.opacity(0.065))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.orange)
                Text("journey.guide.source_pending".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.68))
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func summaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("journey.guide.summary".localized)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.black)
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(JourneyVisual.lime)
                .clipShape(Capsule())

            Text(summary)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineSpacing(4)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private var usefulLinks: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("journey.guide.useful_links".localized)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            ForEach(guide.links) { link in
                if let url = URL(string: link.url) {
                    Link(destination: url) {
                        HStack(spacing: 11) {
                            Image(systemName: "link")
                                .foregroundColor(JourneyVisual.lime)
                            Text(link.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.white.opacity(0.46))
                        }
                        .padding(13)
                        .background(Color.white.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                }
            }
        }
    }

    private func nextStepCard(_ checklist: Checklist) -> some View {
        NavigationLink(destination: ChecklistDetailView(checklist: checklist)) {
            HStack(spacing: 13) {
                Image(systemName: "checklist.checked")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 48, height: 48)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("journey.guide.take_action".localized)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(JourneyVisual.lime)
                    Text(checklist.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }

                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundColor(.white)
            }
            .padding(14)
            .background(Color.white.opacity(0.065))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.lime.opacity(0.42), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var readingProgress: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(JourneyVisual.lime)
                .frame(width: geometry.size.width * min(1, scrollOffset / 1_400), height: 3)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: scrollOffset)
        }
        .frame(height: 3)
    }

    private var shareText: String {
        [guide.title, guide.summary, guide.source].compactMap { $0 }.joined(separator: "\n\n")
    }
}

private struct JourneyGuideHeroImage: View {
    let guide: Guide

    var body: some View {
        Group {
            if let path = guide.heroImage, let url = URL(string: path), url.scheme != nil {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else if let name = guide.heroImage, UIImage(named: name) != nil {
                Image(name).resizable().scaledToFill()
            } else {
                fallback
            }
        }
    }

    private var fallback: some View {
        Image(fallbackName)
            .resizable()
            .scaledToFill()
    }

    private var fallbackName: String {
        switch guide.category {
        case .housing, .documents: return "cityhub-zurich-oldtown"
        case .work: return "cityhub-zurich-viadukt"
        case .healthcare, .insurance: return "swiss-moment-luzern"
        default: return "swiss-moment-grindelwald"
        }
    }
}

private struct JourneyArticleMarkdown: View {
    let markdown: String

    private var lines: [String] {
        markdown.components(separatedBy: .newlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.isEmpty {
                    Color.clear.frame(height: 2)
                } else if line.hasPrefix("### ") {
                    heading(String(line.dropFirst(4)), size: 19)
                } else if line.hasPrefix("## ") {
                    heading(String(line.dropFirst(3)), size: 24)
                } else if line.hasPrefix("# ") {
                    heading(String(line.dropFirst(2)), size: 29)
                } else if line.hasPrefix("> ") {
                    callout(String(line.dropFirst(2)))
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    bullet(String(line.dropFirst(2)))
                } else {
                    paragraph(line)
                }
            }
        }
    }

    private func heading(_ text: String, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineSpacing(-1)
            Capsule()
                .fill(JourneyVisual.lime)
                .frame(width: 44, height: 4)
        }
        .padding(.top, 10)
    }

    private func paragraph(_ text: String) -> some View {
        Text(attributed(text))
            .font(.system(size: 17, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.84))
            .lineSpacing(7)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(JourneyVisual.lime)
                .frame(width: 6, height: 6)
                .padding(.top, 8)
            paragraph(text)
        }
    }

    private func callout(_ text: String) -> some View {
        Text(attributed(text))
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .lineSpacing(5)
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(JourneyVisual.lime.opacity(0.09))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(JourneyVisual.lime)
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func attributed(_ value: String) -> AttributedString {
        (try? AttributedString(markdown: value)) ?? AttributedString(value)
    }
}

private struct JourneyArticleOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
