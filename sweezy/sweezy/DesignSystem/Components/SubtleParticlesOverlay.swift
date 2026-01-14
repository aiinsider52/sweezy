import SwiftUI

/// Small floating particles for gentle motion and depth in hero sections.
struct SubtleParticlesOverlay: View {
    var count: Int = 10
    var opacity: Double = 0.1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled {
                Color.clear
            } else {
                TimelineView(.animation) { timeline in
                    GeometryReader { geo in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        ZStack {
                            ForEach(0..<count, id: \.self) { i in
                                let phase = t * 0.2 + Double(i) * 0.35
                                let w = geo.size.width
                                let h = geo.size.height
                                Circle()
                                    .fill(Color.white.opacity(opacity))
                                    .frame(width: 3, height: 3)
                                    .blur(radius: 0.3)
                                    .offset(
                                        x: cos(phase * 1.1) * w * 0.45 + (Double(i).truncatingRemainder(dividingBy: 3) - 1) * 18,
                                        y: sin(phase * 1.3) * h * 0.35 + (Double(i) - Double(count)/2) * 2
                                    )
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
                .compositingGroup()
            }
        }
    }
}


