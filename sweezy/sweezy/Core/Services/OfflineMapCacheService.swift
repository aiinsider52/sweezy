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
    
    func saveSnapshot(center: CLLocationCoordinate2D, span: MKCoordinateSpan, size: CGSize = CGSize(width: 1200, height: 1200)) async {
        let region = MKCoordinateRegion(center: center, span: span)
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = UIScreen.main.scale
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
}


