import SwiftUI

/// Global animated background with neon depth for dark mode and pastel calm for light mode.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        // IMPORTANT: Avoid heavy GPU work on launch to prevent blank screen on some devices.
        // We intentionally skip advanced effects when Reduce Motion or Low Power Mode is enabled.
        Group {
            if colorScheme == .dark {
                darkLayer
            } else {
                lightLayer
            }
        }
        // drawingGroup can trigger expensive offscreen rendering; avoid at app root to prevent a white screen
        .compositingGroup()
    }
    
    private var darkLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.02, blue: 0.05),
                    Color(red: 0.05, green: 0.07, blue: 0.11)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Mesh gradient and overlays are guarded to avoid Timeline/Canvas on constrained devices
            if !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled {
                AnimatedMeshGradient(
                    colors: [
                        Color(red: 0.12, green: 0.89, blue: 1.00),
                        Color(red: 0.68, green: 0.32, blue: 1.00),
                        Color(red: 0.04, green: 1.00, blue: 0.72)
                    ],
                    speed: 0.12
                )
                .opacity(0.45)
                .blendMode(.screen)
                .ignoresSafeArea()
                
                ConstellationOverlay()
                    .opacity(0.35)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                
                SubtleParticlesOverlay(count: 24, opacity: 0.08)
                    .ignoresSafeArea()
            }
            
            RadialGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                center: .center,
                startRadius: 120,
                endRadius: 900
            )
            .blendMode(.multiply)
            .ignoresSafeArea()
        }
    }
    
    private var lightLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.99, blue: 1.00),
                    Color(red: 0.97, green: 1.00, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled {
                AnimatedMeshGradient(
                    colors: [
                        Color(red: 0.73, green: 0.89, blue: 1.00),
                        Color(red: 0.92, green: 0.74, blue: 1.00),
                        Color(red: 0.82, green: 0.95, blue: 0.86)
                    ],
                    speed: 0.10
                )
                .opacity(0.25)
                .ignoresSafeArea()
                
                NoiseOverlay(intensity: 0.18)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.clear, Color.black.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.multiply)
            .ignoresSafeArea()
        }
    }
}

// MARK: - Overlays

private struct ConstellationOverlay: View {
    let stars: [CGPoint] = (0..<60).map { _ in
        CGPoint(x: Double.random(in: 0...1), y: Double.random(in: 0...1))
    }
    
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                for point in stars {
                    let position = CGPoint(x: point.x * size.width, y: point.y * size.height)
                    var circle = Path()
                    circle.addEllipse(in: CGRect(x: position.x, y: position.y, width: 2, height: 2))
                    context.fill(circle, with: .color(Color.white.opacity(0.35)))
                }
            }
            .blendMode(.plusLighter)
        }
    }
}

private struct NoiseOverlay: View {
    let intensity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled {
                TimelineView(.animation) { _ in
                    Canvas { context, size in
                        let points = Int(size.width * size.height / 1200)
                        for _ in 0..<points {
                            let x = Double.random(in: 0...size.width)
                            let y = Double.random(in: 0...size.height)
                            var rect = Path()
                            rect.addRect(CGRect(x: x, y: y, width: 1, height: 1))
                            context.fill(rect, with: .color(Color.white.opacity(intensity)))
                        }
                    }
                    .blendMode(.overlay)
                }
            }
        }
    }
}

