//
//  OfflineMapCacheService.swift
//  sweezy
//

import Foundation
import MapKit
import UIKit

@MainActor
final class OfflineMapCacheService: ObservableObject {
    private let folderName = "OfflineMap"
    private var folderURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(folderName, isDirectory: true)
    }
    private var defaultSnapshotURL: URL { folderURL.appendingPathComponent("default.png") }
    private func snapshotURL(for id: String) -> URL {
        let safe = id.replacingOccurrences(of: "/", with: "-")
        return folderURL.appendingPathComponent("\(safe).png")
    }
    
    init() {
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }
    
    func hasSnapshot() -> Bool {
        FileManager.default.fileExists(atPath: defaultSnapshotURL.path)
    }
    
    func loadSnapshot() -> UIImage? {
        guard let data = try? Data(contentsOf: defaultSnapshotURL) else { return nil }
        return UIImage(data: data)
    }

    func hasSnapshot(for id: String) -> Bool {
        FileManager.default.fileExists(atPath: snapshotURL(for: id).path)
    }

    func loadSnapshot(for id: String) -> UIImage? {
        guard let data = try? Data(contentsOf: snapshotURL(for: id)) else { return nil }
        return UIImage(data: data)
    }
    
    func saveSnapshot(
        center: CLLocationCoordinate2D,
        span: MKCoordinateSpan,
        size: CGSize = CGSize(width: 1200, height: 1200),
        scale: CGFloat = 2
    ) async {
        let region = MKCoordinateRegion(center: center, span: span)
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = scale
        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snap = try await snapshotter.start()
            if let png = snap.image.pngData() {
                try? png.write(to: defaultSnapshotURL, options: .atomic)
            }
        } catch {
            // ignore
        }
    }

    func saveSnapshot(for id: String, center: CLLocationCoordinate2D, span: MKCoordinateSpan) async throws {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: center, span: span)
        options.size = CGSize(width: 1200, height: 900)
        options.scale = min(UIScreen.main.scale, 2)
        let snapshot = try await MKMapSnapshotter(options: options).start()
        guard let data = snapshot.image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: snapshotURL(for: id), options: .atomic)
    }
}

