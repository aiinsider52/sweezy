import SwiftUI
import UIKit

extension Notification.Name {
    /// A small win the user just made (a plan step done, a deadline saved); the tab shell answers with confetti.
    static let celebrate = Notification.Name("celebrate")
}

/// Brand confetti and a success tap for small wins. Safe to call from any service; Reduce Motion
/// keeps the haptic and skips the burst (ConfettiBurst checks it).
enum Celebration {
    static func fire() {
        Task { @MainActor in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            NotificationCenter.default.post(name: .celebrate, object: nil)
        }
    }
}

// MARK: - Tab transition

private struct TabSlideModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
    }
}

extension AnyTransition {
    /// The new tab slides in a short way from the side it lies on in the dock while the old one drifts out.
    static func tabSlide(forward: Bool) -> AnyTransition {
        let distance: CGFloat = 44
        return .asymmetric(
            insertion: .modifier(
                active: TabSlideModifier(offset: forward ? distance : -distance, opacity: 0),
                identity: TabSlideModifier(offset: 0, opacity: 1)
            ),
            removal: .modifier(
                active: TabSlideModifier(offset: forward ? -distance * 0.6 : distance * 0.6, opacity: 0),
                identity: TabSlideModifier(offset: 0, opacity: 1)
            )
        )
    }
}

// MARK: - Progress ring

/// Lime ring that fills as steps get done, with the count in the middle. Fills with a spring
/// and gives a soft glow once everything is complete.
struct JourneyProgressRing: View {
    let done: Int
    let total: Int
    var size: CGFloat = 54
    var lineWidth: CGFloat = 7
    /// Show "85%" instead of "85/100".
    var showsPercent = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    private var fraction: Double { total == 0 ? 0 : min(1, Double(done) / Double(total)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(JourneyVisual.primaryText.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, shown))
                .stroke(
                    AngularGradient(
                        colors: [Color(red: 0.36, green: 0.58, blue: 0.02), JourneyVisual.lime, JourneyVisual.lime],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(shown, 0.01))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: JourneyVisual.lime.opacity(fraction >= 1 ? 0.7 : 0.25), radius: fraction >= 1 ? 8 : 3)
            if showsPercent {
                Text("\(Int(fraction * 100))%")
                    .font(.system(size: size * 0.27, weight: .heavy).monospacedDigit())
                    .foregroundColor(JourneyVisual.primaryText)
                    .contentTransition(.numericText(value: fraction))
            } else {
                VStack(spacing: -2) {
                    Text("\(done)")
                        .font(.system(size: size * 0.32, weight: .heavy).monospacedDigit())
                        .foregroundColor(JourneyVisual.primaryText)
                        .contentTransition(.numericText(value: Double(done)))
                    Text("/\(total)")
                        .font(.system(size: size * 0.18, weight: .bold).monospacedDigit())
                        .foregroundColor(JourneyVisual.secondaryText)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear { animate(to: fraction, delay: 0.25) }
        .onChange(of: fraction) { _, value in animate(to: value, delay: 0) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done)/\(total)")
        .accessibilityValue("\(Int(fraction * 100))%")
    }

    private func animate(to value: Double, delay: Double) {
        guard !reduceMotion else { shown = value; return }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.78).delay(delay)) { shown = value }
    }
}

// MARK: - Drifting clouds

/// Soft clouds that slowly cross the sky of an illustration, each layer at its own speed for depth.
/// Rendered in a Canvas, so it costs one draw per frame; with Reduce Motion they stand still.
struct DriftingClouds: View {
    /// How far the page has scrolled; nearer clouds move a bit more for parallax.
    var scrollOffset: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Cloud {
        let y: CGFloat        // share of the height
        let scale: CGFloat
        let speed: CGFloat    // points per second
        let phase: CGFloat    // share of the travel already done
        let opacity: Double
        let depth: CGFloat    // parallax factor
    }

    private let clouds: [Cloud] = [
        Cloud(y: 0.10, scale: 1.25, speed: 7, phase: 0.05, opacity: 0.85, depth: 0.10),
        Cloud(y: 0.20, scale: 0.75, speed: 11, phase: 0.55, opacity: 0.70, depth: 0.18),
        Cloud(y: 0.06, scale: 0.55, speed: 15, phase: 0.80, opacity: 0.55, depth: 0.24),
        Cloud(y: 0.28, scale: 1.0, speed: 9, phase: 0.30, opacity: 0.6, depth: 0.14),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
                context.addFilter(.blur(radius: 3))
                for cloud in clouds {
                    let width = 150 * cloud.scale
                    let travel = size.width + width * 2
                    let progress = (cloud.phase * travel + (reduceMotion ? 0 : time * cloud.speed)).truncatingRemainder(dividingBy: travel)
                    let x = progress - width
                    let y = cloud.y * size.height - scrollOffset * cloud.depth
                    var layer = context
                    layer.opacity = cloud.opacity
                    layer.fill(cloudPath(at: CGPoint(x: x, y: y), width: width), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A cumulus made of overlapping puffs on a flat base.
    private func cloudPath(at origin: CGPoint, width: CGFloat) -> Path {
        let h = width * 0.42
        var path = Path()
        path.addRoundedRect(in: CGRect(x: origin.x, y: origin.y + h * 0.45, width: width, height: h * 0.5), cornerSize: CGSize(width: h * 0.25, height: h * 0.25))
        path.addEllipse(in: CGRect(x: origin.x + width * 0.08, y: origin.y + h * 0.25, width: width * 0.38, height: h * 0.62))
        path.addEllipse(in: CGRect(x: origin.x + width * 0.30, y: origin.y, width: width * 0.42, height: h * 0.8))
        path.addEllipse(in: CGRect(x: origin.x + width * 0.56, y: origin.y + h * 0.2, width: width * 0.34, height: h * 0.62))
        return path
    }
}
