//
//  News.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation

struct NewsItem: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let summary: String
    let content: String?
    let url: String
    let source: String
    let language: String // uk, ru, en, de
    let publishedAt: Date
    let tags: [String]
    let imageURL: String?
    
    init(
        title: String,
        summary: String,
        url: String,
        content: String? = nil,
        source: String,
        language: String,
        publishedAt: Date,
        tags: [String] = [],
        imageURL: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.summary = summary
        self.content = content
        self.url = url
        self.source = source
        self.language = language
        self.publishedAt = publishedAt
        self.tags = tags
        self.imageURL = imageURL
    }
    
    // Tolerant decoding for invalid UUIDs and missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Tolerant UUID decoding
        if let idString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled"
        self.summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
        self.content = try? container.decodeIfPresent(String.self, forKey: .content)
        self.url = (try? container.decode(String.self, forKey: .url)) ?? ""
        self.source = (try? container.decode(String.self, forKey: .source)) ?? "Unknown"
        self.language = (try? container.decode(String.self, forKey: .language)) ?? "uk"
        self.publishedAt = (try? container.decode(Date.self, forKey: .publishedAt)) ?? Date()
        self.tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        self.imageURL = try? container.decodeIfPresent(String.self, forKey: .imageURL)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, summary, content, url, source, language, publishedAt, tags, imageURL
    }
}
