import SwiftUI

// MARK: - Mascot guide

/// Sweezy walks the user through the spacious onboarding steps.
/// Decorative only: VoiceOver and hit testing skip it, and Reduce Motion keeps it still.
struct OnboardingMascotStage: View {
    let page: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Form-heavy steps and the final page stage their own content, so the mascot steps aside there.
    private var pose: SweezyCompanionPose? {
        switch page {
        case 0: return .welcome
        case 1, 5: return .guide
        case 2: return .documents
        default: return nil
        }
    }

    private func size(for height: CGFloat) -> CGFloat {
        // The theme step has taller controls, so its mascot is smaller.
        let factor: CGFloat = page == 5 ? 0.16 : 0.23
        return min(210, height * factor)
    }

    var body: some View {
        GeometryReader { geometry in
            // Short phones keep the full content; the mascot would collide with it.
            let fits = geometry.size.height >= 720
            let side = size(for: geometry.size.height)

            ZStack {
                if let pose, fits {
                    ZStack {
                        Circle()
                            .fill(JourneyVisual.lime.opacity(0.24))
                            .frame(width: side * 0.86, height: side * 0.86)
                            .blur(radius: 30)
                        Image(pose.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: side, height: side)
                    }
                    .idleFloat(enabled: !reduceMotion)
                    .id(pose)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .scale(scale: 0.72, anchor: .bottom).combined(with: .opacity),
                                removal: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity)
                            )
                    )
                }
            }
            .frame(width: geometry.size.width)
            .padding(.top, 78)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.7), value: pose)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct IdleFloatModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.phaseAnimator([false, true]) { view, lifted in
                view
                    .offset(y: lifted ? -6 : 0)
                    .scaleEffect(lifted ? 1.02 : 1, anchor: .bottom)
            } animation: { _ in
                .easeInOut(duration: 1.9)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Slow breathing motion for decorative characters.
    func idleFloat(enabled: Bool) -> some View {
        modifier(IdleFloatModifier(enabled: enabled))
    }
}

// MARK: - Progress

struct OnboardingStepProgress: View {
    let current: Int
    let total: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Text("\(current + 1)/\(total)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(JourneyVisual.secondaryText)
                .contentTransition(.numericText(value: Double(current)))

            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index <= current ? JourneyVisual.accentStrong : JourneyVisual.softBorder)
                        .frame(height: index == current ? 6 : 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 6)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78), value: current)
    }
}

// MARK: - Staggered reveal

private struct OnboardingRevealModifier: ViewModifier {
    let visible: Bool
    let order: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 18)
            .blur(radius: visible || reduceMotion ? 0 : 5)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .spring(response: 0.55, dampingFraction: 0.84).delay(0.07 * Double(order)),
                value: visible
            )
    }
}

extension View {
    /// Fades and lifts a block into place; `order` staggers siblings on the same page.
    func onboardingReveal(_ visible: Bool, order: Int) -> some View {
        modifier(OnboardingRevealModifier(visible: visible, order: order))
    }
}

// MARK: - Confetti

/// One-shot brand-colored confetti. Nothing renders until `trigger` changes; Reduce Motion skips it.
struct ConfettiBurst: View {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate: Date?
    @State private var pieces: [Piece] = ConfettiBurst.makePieces()

    private static let duration: TimeInterval = 2.2
    private static let gravity: Double = 950
    private static let palette: [Color] = [
        JourneyVisual.lime,
        Color(red: 0.36, green: 0.58, blue: 0.02),
        Color(red: 0.20, green: 0.74, blue: 0.68),
        JourneyVisual.coral,
        Color(red: 1.0, green: 0.82, blue: 0.28)
    ]

    struct Piece {
        let angle: Double
        let speed: Double
        let spin: Double
        let size: Double
        let delay: Double
        let color: Int
        let isRound: Bool
    }

    private static func makePieces() -> [Piece] {
        (0..<90).map { _ in
            Piece(
                angle: Double.random(in: (-Double.pi * 0.92)...(-Double.pi * 0.08)),
                speed: Double.random(in: 380...820),
                spin: Double.random(in: -9...9),
                size: Double.random(in: 7...13),
                delay: Double.random(in: 0...0.12),
                color: Int.random(in: 0..<palette.count),
                isRound: Bool.random()
            )
        }
    }

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { timeline in
            Canvas { context, size in
                guard let startDate else { return }
                let elapsed = timeline.date.timeIntervalSince(startDate)
                guard elapsed < Self.duration else { return }
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.3)

                for piece in pieces {
                    let t = max(0, elapsed - piece.delay)
                    let x = origin.x + cos(piece.angle) * piece.speed * t
                    let y = origin.y + sin(piece.angle) * piece.speed * t + 0.5 * Self.gravity * t * t
                    var layer = context
                    layer.opacity = max(0, 1 - t / (Self.duration - 0.2))
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(piece.spin * t))
                    let shape = piece.isRound
                        ? Path(ellipseIn: CGRect(x: -piece.size / 3, y: -piece.size / 3, width: piece.size * 0.66, height: piece.size * 0.66))
                        : Path(roundedRect: CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2), cornerRadius: 1.5)
                    layer.fill(shape, with: .color(Self.palette[piece.color]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: trigger) {
            guard trigger > 0, !reduceMotion else { return }
            pieces = Self.makePieces()
            startDate = Date()
            try? await Task.sleep(for: .seconds(Self.duration))
            startDate = nil
        }
    }
}

// MARK: - Compact summary row

/// One tappable line inside a settings-style card: icon, label, current value.
/// Keeps long option lists (cantons, residence statuses) out of the page itself.
struct OnboardingSummaryRow: View {
    let icon: String
    let label: String
    let value: String
    var detail: String?

    var body: some View {
        HStack(spacing: 12) {
            OnboardingRowIcon(icon: icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(JourneyVisual.secondaryText)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(JourneyVisual.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(minHeight: Theme.Layout.minimumTouchTarget)
        .contentShape(Rectangle())
    }
}

struct OnboardingRowIcon: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(JourneyVisual.accentStrong)
            .frame(width: 32, height: 32)
            .background(JourneyVisual.softSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
