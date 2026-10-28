import MapKit
import SwiftUI
import UIKit

/// Real imagery of a place from Apple Maps: the Look Around street view where Apple has driven,
/// otherwise a 3D satellite view of the building. Snapshots are cached on disk, so each place
/// is fetched once and keeps working offline.
@MainActor
final class PlacePhotoService {
    static let shared = PlacePhotoService()

    enum Kind: String { case street, aerial }
    struct Photo { let image: UIImage; let kind: Kind }

    private let memory = NSCache<NSString, UIImage>()
    private var kinds: [String: Kind] = [:]
    private var inFlight: [String: Task<Photo?, Never>] = [:]
    /// MapKit throttles bursts of snapshot requests; a scrolling list would otherwise fire dozens at once.
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private let maxConcurrent = 3

    private let folder: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("PlacePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    func cached(for place: Place) -> Photo? {
        let key = place.id.uuidString
        if let image = memory.object(forKey: key as NSString), let kind = kinds[key] {
            return Photo(image: image, kind: kind)
        }
        for kind in [Kind.street, .aerial] {
            if let data = try? Data(contentsOf: fileURL(key, kind)), let image = UIImage(data: data) {
                remember(image, kind: kind, key: key)
                return Photo(image: image, kind: kind)
            }
        }
        return nil
    }

    func photo(for place: Place) async -> Photo? {
        if let cached = cached(for: place) { return cached }
        let key = place.id.uuidString
        if let task = inFlight[key] { return await task.value }
        let coordinate = place.coordinate.clLocationCoordinate
        let task = Task<Photo?, Never> { [weak self] in
            guard let self else { return nil }
            await self.acquire()
            defer { self.release() }
            return await self.render(coordinate: coordinate, key: key)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    private func render(coordinate: CLLocationCoordinate2D, key: String) async -> Photo? {
        let size = CGSize(width: 360, height: 300)
        if let scene = try? await MKLookAroundSceneRequest(coordinate: coordinate).scene {
            let options = MKLookAroundSnapshotter.Options()
            options.size = size
            if let snapshot = try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot {
                return store(snapshot.image, kind: .street, key: key)
            }
        }
        let options = MKMapSnapshotter.Options()
        options.camera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: 650, pitch: 45, heading: 20)
        options.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
        options.size = size
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        return store(markCenter(of: snapshot.image), kind: .aerial, key: key)
    }

    /// A lime dot on the building, so an aerial view reads as "this one" rather than a random roof.
    private func markCenter(of image: UIImage) -> UIImage {
        UIGraphicsImageRenderer(size: image.size, format: image.imageRendererFormat).image { _ in
            image.draw(at: .zero)
            let center = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
            let outer = UIBezierPath(arcCenter: center, radius: 9, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor.white.setFill()
            outer.fill()
            let inner = UIBezierPath(arcCenter: center, radius: 6, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor(red: 0.8, green: 1, blue: 0, alpha: 1).setFill()
            inner.fill()
        }
    }

    private func store(_ image: UIImage, kind: Kind, key: String) -> Photo {
        if let data = image.jpegData(compressionQuality: 0.82) {
            try? data.write(to: fileURL(key, kind), options: .atomic)
        }
        remember(image, kind: kind, key: key)
        return Photo(image: image, kind: kind)
    }

    private func remember(_ image: UIImage, kind: Kind, key: String) {
        memory.setObject(image, forKey: key as NSString)
        kinds[key] = kind
    }

    private func fileURL(_ key: String, _ kind: Kind) -> URL {
        folder.appendingPathComponent("\(key)-\(kind.rawValue).jpg")
    }

    private func acquire() async {
        if running < maxConcurrent { running += 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty { running -= 1 } else { waiters.removeFirst().resume() }
    }
}

/// Shows the real photo of a place, with the category illustration as placeholder while it loads
/// or when Apple has no imagery for that spot.
struct PlacePhotoView: View {
    let place: Place
    let fallbackAsset: String

    @State private var photo: PlacePhotoService.Photo?

    var body: some View {
        // Sized from the caller's frame and cropped to it, so a photo never drifts off-centre
        // or spills past the card edge whatever its aspect ratio.
        GeometryReader { proxy in
            ZStack {
                if let photo {
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Image(fallbackAsset)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .overlay(alignment: .topTrailing) {
            // Look Around snapshots carry Apple's own mark; aerial map snapshots do not.
            if photo?.kind == .aerial {
                Text("\u{F8FF}Maps")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.35), in: Capsule())
                    .padding(5)
            }
        }
        .onAppear { photo = PlacePhotoService.shared.cached(for: place) }
        .task(id: place.id) {
            guard photo == nil else { return }
            let loaded = await PlacePhotoService.shared.photo(for: place)
            withAnimation(.easeOut(duration: 0.25)) { photo = loaded }
        }
    }
}
