//
//  CachedAsyncImage.swift
//  sweezy
//
//  Lightweight image loader with in‑memory cache to avoid repeated downloads.
//

import SwiftUI
import UIKit

// MARK: - In-Memory Image Cache

final class ImageMemoryCache {
    static let shared = ImageMemoryCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        cache.countLimit = 200          // up to ~200 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func insert(_ image: UIImage, for url: URL) {
        let pixels = image.size.width * image.size.height
        let cost = Int(pixels)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

// MARK: - Loader

final class CachedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading: Bool = false
    
    private let url: URL?
    private var task: Task<Void, Never>?
    
    init(url: URL?) {
        self.url = url
    }
    
    deinit {
        task?.cancel()
    }
    
    func load() {
        guard !isLoading, image == nil, let url else { return }
        
        // Try memory cache first on the main thread
        if let cached = ImageMemoryCache.shared.image(for: url) {
            image = cached
            return
        }
        
        isLoading = true
        task = Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                if let img = UIImage(data: data) {
                    ImageMemoryCache.shared.insert(img, for: url)
                    await MainActor.run {
                        self.image = img
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - SwiftUI Wrapper

struct CachedAsyncImage<Placeholder: View>: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let placeholder: () -> Placeholder
    
    @StateObject private var loader: CachedImageLoader
    
    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
        _loader = StateObject(wrappedValue: CachedImageLoader(url: url))
    }
    
    var body: some View {
        Group {
            if let uiImage = loader.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load()
        }
    }
}


