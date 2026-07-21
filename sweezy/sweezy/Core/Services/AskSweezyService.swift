import Foundation

struct AskSweezyResult: Identifiable, Hashable {
    let guide: Guide
    let score: Double
    let excerpt: String
    let sourceTitle: String
    let sourceURL: URL

    var id: UUID { guide.id }
}

struct AskSweezyService {
    func search(_ rawQuery: String, guides: [Guide], profile: UserProfile?) -> [AskSweezyResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }

        return guides.compactMap { guide in
            guard let source = officialSource(for: guide) else { return nil }
            var score = guide.searchRelevance(for: query)
            if let canton = profile?.canton, guide.appliesTo(canton: canton) { score += 1.5 }
            if guide.verifiedAt != nil { score += 2 }
            guard score > 0 else { return nil }
            return AskSweezyResult(
                guide: guide,
                score: score,
                excerpt: excerpt(for: guide, query: query),
                sourceTitle: source.title,
                sourceURL: source.url
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.guide.priority > rhs.guide.priority
        }
    }

    private func officialSource(for guide: Guide) -> (title: String, url: URL)? {
        if let source = guide.source?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: source),
           ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            return (guide.sourceTitle ?? url.host ?? "Офіційне джерело", url)
        }
        if let link = guide.links.first(where: { link in
            guard let host = link.asURL?.host?.lowercased() else { return false }
            return host.hasSuffix("admin.ch") || host.hasSuffix("ch.ch") || host.hasSuffix("zh.ch") || host.hasSuffix("vd.ch") || host.hasSuffix("ge.ch")
        }), let url = link.asURL {
            return (link.title.isEmpty ? (url.host ?? "Офіційне джерело") : link.title, url)
        }
        return nil
    }

    private func excerpt(for guide: Guide, query: String) -> String {
        if let summary = guide.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            return String(summary.prefix(220))
        }
        let normalized = guide.bodyMarkdown.replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return guide.subtitle ?? guide.title }
        if let range = normalized.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            let start = normalized.index(range.lowerBound, offsetBy: -80, limitedBy: normalized.startIndex) ?? normalized.startIndex
            let end = normalized.index(range.upperBound, offsetBy: 140, limitedBy: normalized.endIndex) ?? normalized.endIndex
            return String(normalized[start..<end])
        }
        return String(normalized.prefix(220))
    }
}
