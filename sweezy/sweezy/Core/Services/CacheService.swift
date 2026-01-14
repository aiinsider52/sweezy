//
//  CacheService.swift
//  sweezy
//
//  Created by AI Assistant on 16.10.2025.
//

import Foundation

/// Cache service for persistent storage of parsed content
actor CacheService {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Cache version - increment when format changes
    private let cacheVersion = "v1"
    
    init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheDirectory = urls[0].appendingPathComponent("SweezyCache")
        
        // Inline decoder/encoder setup (actor initializer is nonisolated in Swift 6)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        // Create cache directory
        try? fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }
    
    private func setupDecoder() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
    }
    
    private func createCacheDirectoryIfNeeded() {
        try? fileManager.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - Cache Operations
    
    /// Save object to cache
    func save<T: Codable>(_ object: T, key: String, language: String) async throws {
        let cacheKey = makeCacheKey(key: key, language: language)
        let url = cacheDirectory.appendingPathComponent(cacheKey)
        
        let data = try encoder.encode(object)
        try data.write(to: url, options: .atomic)
        
        // Save metadata
        let metadata = CacheMetadata(
            version: cacheVersion,
            language: language,
            createdAt: Date()
        )
        let metadataURL = url.appendingPathExtension("meta")
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL, options: .atomic)
    }
    
    /// Load object from cache
    func load<T: Codable>(_ type: T.Type, key: String, language: String) async throws -> T? {
        let cacheKey = makeCacheKey(key: key, language: language)
        let url = cacheDirectory.appendingPathComponent(cacheKey)
        
        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        // Validate metadata
        let metadataURL = url.appendingPathExtension("meta")
        if let metadataData = try? Data(contentsOf: metadataURL),
           let metadata = try? decoder.decode(CacheMetadata.self, from: metadataData) {
            // Invalidate cache if version mismatch
            if metadata.version != cacheVersion {
                try? fileManager.removeItem(at: url)
                try? fileManager.removeItem(at: metadataURL)
                return nil
            }
            
            // Invalidate cache if too old (7 days)
            if Date().timeIntervalSince(metadata.createdAt) > 7 * 24 * 60 * 60 {
                try? fileManager.removeItem(at: url)
                try? fileManager.removeItem(at: metadataURL)
                return nil
            }
        }
        
        // Load and decode
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }
    
    /// Clear all cache
    func clearAll() async throws {
        try fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
    }
    
    /// Clear cache for specific language
    func clearLanguage(_ language: String) async throws {
        let contents = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )
        
        for url in contents {
            if url.lastPathComponent.contains("_\(language).") {
                try fileManager.removeItem(at: url)
            }
        }
    }
    
    /// Get cache size in bytes
    func getCacheSize() async -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for url in contents {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
    
    // MARK: - Private Helpers
    
    private func makeCacheKey(key: String, language: String) -> String {
        return "\(key)_\(language).json"
    }
}

// MARK: - Cache Metadata

private struct CacheMetadata: Codable {
    let version: String
    let language: String
    let createdAt: Date
}

// MARK: - Cache Statistics

struct CacheStats {
    let sizeInBytes: Int64
    let numberOfFiles: Int
    
    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
}



