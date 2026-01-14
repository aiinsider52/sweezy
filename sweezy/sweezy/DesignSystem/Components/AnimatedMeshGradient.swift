import SwiftUI

/// Animated mesh-like gradient using blurred radial blobs with additive blending.
struct AnimatedMeshGradient: View {
    var colors: [Color] = [
        Theme.Colors.accentTurquoise,
        Theme.Colors.primary,
        Theme.Colors.accentWarmGreen
    ]
    var speed: Double = 0.12
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Static gradient fallback for safety
                LinearGradient(
                    colors: colors.map { $0.opacity(0.6) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                TimelineView(.animation) { timeline in
                    GeometryReader { geo in
                        let t = timeline.date.timeIntervalSinceReferenceDate * speed
                        ZStack {
                            ForEach(colors.indices, id: \.self) { i in
                                let phase = t + Double(i) * 1.27
                                let w = geo.size.width
                                let h = geo.size.height
                                Circle()
                                    .fill(colors[i])
                                    .frame(width: max(w, h) * 0.9, height: max(w, h) * 0.9)
                                    .blur(radius: 120)
                                    .offset(
                                        x: cos(phase * 1.15) * w * 0.25,
                                        y: sin(phase * 0.9) * h * 0.25
                                    )
                                    .blendMode(.plusLighter)
                            }
                        }
                        .background(Theme.Colors.primaryBackground.opacity(0.0))
                    }
                }
                .compositingGroup()
                .clipped()
            }
        }
    }
}


