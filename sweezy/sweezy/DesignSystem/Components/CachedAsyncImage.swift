//
//  CachedAsyncImage.swift
//  sweezy
//
//  Lightweight image loader with in‑memory cache to avoid repeated downloads.
//

import SwiftUI
import UIKit
import ImageIO

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
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        let cost = Int(pixels * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

// MARK: - Loader

final class CachedImageLoader: ObservableObject {
    private static let maximumDownloadBytes = 12 * 1024 * 1024
    private static let maximumPixelDimension: CGFloat = 8_192
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
                let (bytes, response) = try await URLSession.shared.bytes(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                guard http.expectedContentLength <= 0 || http.expectedContentLength <= Int64(Self.maximumDownloadBytes) else {
                    await MainActor.run { self.isLoading = false }
                    return
                }

                var data = Data()
                if http.expectedContentLength > 0 {
                    data.reserveCapacity(Int(http.expectedContentLength))
                }
                for try await byte in bytes {
                    try Task.checkCancellation()
                    guard data.count < Self.maximumDownloadBytes else {
                        await MainActor.run { self.isLoading = false }
                        return
                    }
                    data.append(byte)
                }

                guard
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                      let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
                      let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
                      width <= Self.maximumPixelDimension,
                      height <= Self.maximumPixelDimension,
                      let img = UIImage(data: data) else {
                    await MainActor.run { self.isLoading = false }
                    return
                }
                if !Task.isCancelled {
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
