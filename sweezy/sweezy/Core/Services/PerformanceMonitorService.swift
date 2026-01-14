//
//  PerformanceMonitorService.swift
//  sweezy
//
//  Simple FPS/hitch observer with periodic telemetry flush.
//

import Foundation
import UIKit

@MainActor
final class PerformanceMonitorService {
    private weak var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCountInWindow: Int = 0
    private var windowStart: CFTimeInterval = 0
    private var worstFrameMs: Double = 0
    private var hitchCount: Int = 0
    
    private let telemetry: TelemetryService
    private let windowDuration: CFTimeInterval = 10 // seconds
    private let hitchThreshold: CFTimeInterval = 0.12 // 120ms
    
    init(telemetry: TelemetryService) {
        self.telemetry = telemetry
    }
    
    func start() {
        stop()
        windowStart = CACurrentMediaTime()
        worstFrameMs = 0
        hitchCount = 0
        frameCountInWindow = 0
        let link = CADisplayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.onTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    func stop() {
        displayLink?.invalidate()
    }
    
    fileprivate func onFrame(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard lastTimestamp > 0 else { return }
        frameCountInWindow += 1
        let dt = link.timestamp - lastTimestamp
        worstFrameMs = max(worstFrameMs, Double(dt * 1000))
        if dt > hitchThreshold { hitchCount += 1 }
        
        let now = CACurrentMediaTime()
        if now - windowStart >= windowDuration {
            let fps = Double(frameCountInWindow) / (now - windowStart)
            telemetry.info("perf_window", source: "ui", message: nil, meta: [
                "fps": String(format: "%.1f", fps),
                "hitches": "\(hitchCount)",
                "worst_ms": String(format: "%.1f", worstFrameMs)
            ])
            // reset window
            windowStart = now
            frameCountInWindow = 0
            worstFrameMs = 0
            hitchCount = 0
        }
    }
}

// MARK: - CADisplayLink target proxy to avoid retain cycles
private class DisplayLinkProxy: NSObject {
    private weak var owner: PerformanceMonitorService?
    init(_ owner: PerformanceMonitorService) { self.owner = owner }
    @MainActor @objc func onTick(_ link: CADisplayLink) { owner?.onFrame(link) }
}


