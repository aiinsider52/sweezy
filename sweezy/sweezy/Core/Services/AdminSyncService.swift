//
//  AdminSyncService.swift
//  sweezy
//
//  One-time helper to push local bundled content to the backend admin import endpoints.
//  Call this from a debug action after logging in (so JWT is present).
//

import Foundation

@MainActor
enum AdminSyncService {
    static func syncAll(contentService: any ContentServiceProtocol) async {
        do {
            try await syncGuides(contentService.guides)
            try await syncTemplates(contentService.templates)
            try await syncChecklists(contentService.checklists)
            try await syncNews((contentService as? ContentService)?.news ?? [])
        } catch {
            print("[AdminSyncService] sync failed: \(error)")
        }
    }

    private static func syncGuides(_ guides: [Guide]) async throws {
        let url = APIClient.url("admin/import/guides")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        APIClient.attachAuth(&req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [[String: Any]] = guides.map { g in
            [
                "title": g.title,
                "slug": slugify(g.title),
                "description": g.subtitle ?? "",
                "content": g.bodyMarkdown,
                "category": g.category.rawValue,
                "image_url": g.heroImage as Any,
                "is_published": true,
                "version": 1
            ].compactMapValues { $0 }
        }
        let body = ["items": payload]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: req)
    }

    private static func syncNews(_ news: [NewsItem]) async throws {
        let url = APIClient.url("admin/import/news")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        APIClient.attachAuth(&req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [[String: Any]] = news.map { n in
            [
                "title": n.title,
                "summary": n.summary,
                "url": n.url,
                "source": n.source,
                "language": n.language,
                "published_at": ISO8601DateFormatter().string(from: n.publishedAt),
                "image_url": n.imageURL as Any
            ].compactMapValues { $0 }
        }
        let body = ["items": payload]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: req)
    }

    private static func syncTemplates(_ templates: [DocumentTemplate]) async throws {
        let url = APIClient.url("admin/import/templates")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        APIClient.attachAuth(&req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [[String: Any]] = templates.map { t in
            [
                "name": t.title,
                "category": t.category.rawValue,
                "content": t.content
            ]
        }
        let body = ["items": payload]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: req)
    }

    private static func syncChecklists(_ checklists: [Checklist]) async throws {
        let url = APIClient.url("admin/import/checklists")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        APIClient.attachAuth(&req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [[String: Any]] = checklists.map { c in
            [
                "title": c.title,
                "description": c.description,
                "items": c.steps.map { $0.title },
                "is_published": true
            ].compactMapValues { $0 }
        }
        let body = ["items": payload]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: req)
    }

    private static func slugify(_ s: String) -> String {
        return s.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}


