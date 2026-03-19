import SwiftUI

// MARK: - Adaptive Page Background (replaces hardcoded dark gradients)

/// Adaptive page background — spring/summer 2025 palette.
/// Dark mode → deep forest night. Light mode → fresh alpine meadow.
struct AdaptivePageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.11, blue: 0.07),  // #141C12
                        Color(red: 0.10, green: 0.14, blue: 0.09),  // #1A2417
                        Color(red: 0.08, green: 0.12, blue: 0.07)   // #141F12
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.99, blue: 0.97),  // #FAFDF7
                        Color(red: 0.95, green: 0.97, blue: 0.91),  // #F1F8E9
                        Color(red: 0.96, green: 0.98, blue: 0.93)   // #F5FAF0
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                RadialGradient(
                    colors: [Color(red: 0.400, green: 0.733, blue: 0.416).opacity(0.08), Color.clear],
                    center: .init(x: 0.3, y: 0.2),
                    startRadius: 20,
                    endRadius: 280
                )
                .ignoresSafeArea()
            }
        }
    }
}

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
                    Color(red: 0.06, green: 0.08, blue: 0.05),  // deep forest
                    Color(red: 0.08, green: 0.11, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled {
                AnimatedMeshGradient(
                    colors: [
                        Color(red: 0.40, green: 0.73, blue: 0.42),  // #66BB6A
                        Color(red: 0.98, green: 0.66, blue: 0.15),  // #F9A825
                        Color(red: 0.18, green: 0.49, blue: 0.20)   // #2E7D32
                    ],
                    speed: 0.12
                )
                .opacity(0.35)
                .blendMode(.screen)
                .ignoresSafeArea()
                
                ConstellationOverlay()
                    .opacity(0.25)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                
                SubtleParticlesOverlay(count: 24, opacity: 0.06)
                    .ignoresSafeArea()
            }
            
            RadialGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.30)],
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
                    Color(red: 0.98, green: 0.99, blue: 0.97),  // #FAFDF7
                    Color(red: 0.95, green: 0.97, blue: 0.91)   // #F1F8E9
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled {
                AnimatedMeshGradient(
                    colors: [
                        Color(red: 0.65, green: 0.84, blue: 0.65),  // #A5D6A7
                        Color(red: 1.0, green: 0.95, blue: 0.46),   // #FFF176
                        Color(red: 0.78, green: 0.90, blue: 0.79)   // #C8E6C9
                    ],
                    speed: 0.10
                )
                .opacity(0.20)
                .ignoresSafeArea()
                
                NoiseOverlay(intensity: 0.14)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            LinearGradient(
                colors: [Color.black.opacity(0.03), Color.clear, Color.black.opacity(0.03)],
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

