import Foundation

struct AskSweezyResult: Identifiable, Hashable {
    let guide: Guide
    let score: Double
    let excerpt: String
    let sourceTitle: String
    /// nil when the guide has no official link yet; such results rank below sourced ones.
    let sourceURL: URL?

    var id: UUID { guide.id }
}

struct AskSweezyService {
    func search(_ rawQuery: String, guides: [Guide], profile: UserProfile?) -> [AskSweezyResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }

        return guides.compactMap { guide in
            let relevance = guide.searchRelevance(for: query)
            guard relevance > 0 else { return nil }
            let source = officialSource(for: guide)
            var score = relevance
            if let canton = profile?.canton, guide.appliesTo(canton: canton) { score += 1.5 }
            if guide.verifiedAt != nil { score += 2 }
            // Guides with an official link always come first; the rest are still shown, clearly labelled,
            // instead of hiding most of the library and answering "nothing found".
            if source != nil { score += 100 }
            return AskSweezyResult(
                guide: guide,
                score: score,
                excerpt: excerpt(for: guide, query: query),
                sourceTitle: source?.title ?? "ask.source.pending".localized,
                sourceURL: source?.url
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.guide.priority > rhs.guide.priority
        }
    }

    /// Government portals in the three countries: federal and cantonal Swiss sites, German federal
    /// agencies, Austrian gv.at portals and the public employment services.
    static func isOfficialHost(_ host: String) -> Bool {
        let host = host.lowercased()
        if host.hasSuffix("admin.ch") || host == "ch.ch" || host.hasSuffix(".ch.ch") { return true }
        // Cantonal portals: zh.ch, be.ch, www.vd.ch …
        let parts = host.split(separator: ".")
        if parts.count >= 2, parts.last == "ch", parts[parts.count - 2].count == 2 { return true }
        let suffixes = ["bund.de", "bamf.de", "arbeitsagentur.de", "make-it-in-germany.com", "gv.at", "ams.at", "integrationsfonds.at"]
        return suffixes.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private func officialSource(for guide: Guide) -> (title: String, url: URL)? {
        if let source = guide.source?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: source),
           ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            return (guide.sourceTitle ?? url.host ?? "Офіційне джерело".localized, url)
        }
        if let link = guide.links.first(where: { link in
            guard let host = link.asURL?.host?.lowercased() else { return false }
            return Self.isOfficialHost(host)
        }), let url = link.asURL {
            return (link.title.isEmpty ? (url.host ?? "Офіційне джерело".localized) : link.title, url)
        }
        return nil
    }

    private func excerpt(for guide: Guide, query: String) -> String {
        if let summary = guide.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            return String(summary.prefix(220))
        }
        let sentences = Self.plainSentences(from: guide.bodyMarkdown)
        guard !sentences.isEmpty else { return guide.subtitle ?? guide.title }
        // The sentence that contains the query, else the first real sentence after the title.
        let match = sentences.first { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        let lead = sentences.first { $0.count > 40 } ?? sentences[0]
        return String((match ?? lead).prefix(220))
    }

    /// Markdown body as plain readable lines: no headings, list markers, checkboxes, emphasis,
    /// links or leading emoji, and no lines that only repeat the title.
    static func plainSentences(from markdown: String) -> [String] {
        markdown
            .components(separatedBy: .newlines)
            .map { line -> String in
                var text = line.trimmingCharacters(in: .whitespaces)
                if text.hasPrefix("#") { return "" }
                for marker in ["- [ ] ", "- [x] ", "* [ ] ", "- ", "* ", "> ", "+ "] where text.hasPrefix(marker) {
                    text = String(text.dropFirst(marker.count))
                }
                text = text.replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "__", with: "")
                    .replacingOccurrences(of: "`", with: "")
                // [label](url) -> label
                text = text.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
                // Leading emoji / symbols such as "❌ " or "✅ ".
                while let first = text.unicodeScalars.first, first.properties.isEmojiPresentation || first.properties.isEmoji && first.value > 0x2000 {
                    text = String(text.unicodeScalars.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                return text.trimmingCharacters(in: .whitespaces)
            }
            .filter { $0.count > 12 && !$0.hasSuffix(":") }
    }
}
