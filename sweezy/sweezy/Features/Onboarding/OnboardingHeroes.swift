import SwiftUI

// MARK: - Layout slot

/// Reserves the hero's own band in the page layout, so artwork can never cover text.
/// The band scales with the screen and collapses on short phones, where the form needs the room.
struct OnboardingHeroSlot<Content: View>: View {
    var maxHeight: CGFloat = 176
    var share: CGFloat = 0.2
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical) { length, _ in
                length >= 720 ? min(maxHeight, length * share) : 0
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

// MARK: - Clock

/// Drives continuous hero motion; Reduce Motion shows a single composed frame.
private struct HeroClock<Content: View>: View {
    var still: Double = 1.4
    @ViewBuilder let content: (Double) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
            content(reduceMotion ? still : timeline.date.timeIntervalSinceReferenceDate)
        }
    }
}

private enum HeroInk {
    static var line: Color { JourneyVisual.primaryText }
    static var accent: Color { JourneyVisual.accentStrong }
    static var lime: Color { JourneyVisual.lime }
}

private func glow(_ context: inout GraphicsContext, center: CGPoint, radius requested: CGFloat, opacity: Double = 0.32, bounds: CGSize) {
    // Canvas clips to its frame, so the glow has to fade out before it reaches the edges.
    let radius = min(requested, center.x, center.y, bounds.width - center.x, bounds.height - center.y)
    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    context.fill(
        Path(ellipseIn: rect),
        with: .radialGradient(
            Gradient(colors: [HeroInk.lime.opacity(opacity), HeroInk.lime.opacity(0)]),
            center: center,
            startRadius: 0,
            endRadius: radius
        )
    )
}

// MARK: - Welcome: slowly turning globe joining Switzerland, Germany and Austria

struct OnboardingGlobeHero: View {
    var body: some View {
        HeroClock { time in
            Canvas { context, size in
                let r = min(size.width, size.height) * 0.4
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                glow(&context, center: c, radius: r * 1.55, bounds: size)

                // Orbit with a travelling satellite.
                let orbit = CGRect(x: c.x - r * 1.32, y: c.y - r * 0.42, width: r * 2.64, height: r * 0.84)
                context.stroke(Path(ellipseIn: orbit), with: .color(HeroInk.line.opacity(0.12)), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                let a = time * 0.55
                let sat = CGPoint(x: c.x + cos(a) * r * 1.32, y: c.y + sin(a) * r * 0.42)
                if sin(a) > -0.15 || abs(cos(a)) > 0.75 {
                    context.fill(Path(ellipseIn: CGRect(x: sat.x - 4, y: sat.y - 4, width: 8, height: 8)), with: .color(HeroInk.accent))
                }

                // Sphere.
                let sphere = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                context.fill(sphere, with: .color(Theme.Colors.card.opacity(0.85)))
                var inside = context
                inside.clip(to: sphere)
                for lat in [-60.0, -30.0, 0.0, 30.0, 60.0] {
                    let phi = lat * .pi / 180
                    let y = c.y - r * sin(phi)
                    let half = r * cos(phi)
                    let rect = CGRect(x: c.x - half, y: y - half * 0.16, width: half * 2, height: half * 0.32)
                    inside.stroke(Path(ellipseIn: rect), with: .color(HeroInk.line.opacity(0.14)), lineWidth: 1)
                }
                for k in 0..<6 {
                    let angle = time * 0.22 + Double(k) * .pi / 6
                    let half = r * abs(sin(angle))
                    let front = cos(angle) > 0
                    let rect = CGRect(x: c.x - half, y: c.y - r, width: half * 2, height: r * 2)
                    inside.stroke(Path(ellipseIn: rect), with: .color(HeroInk.line.opacity(front ? 0.28 : 0.1)), lineWidth: 1)
                }
                context.stroke(sphere, with: .color(HeroInk.line.opacity(0.85)), lineWidth: 1.6)

                // Three homes connected by a flowing route.
                let pins = [
                    CGPoint(x: c.x - r * 0.42, y: c.y + r * 0.18),
                    CGPoint(x: c.x + r * 0.05, y: c.y - r * 0.38),
                    CGPoint(x: c.x + r * 0.46, y: c.y + r * 0.1)
                ]
                var route = Path()
                route.move(to: pins[0])
                route.addQuadCurve(to: pins[1], control: CGPoint(x: pins[0].x, y: pins[1].y - r * 0.1))
                route.addQuadCurve(to: pins[2], control: CGPoint(x: pins[2].x, y: pins[1].y - r * 0.05))
                context.stroke(route, with: .color(HeroInk.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6], dashPhase: -time * 18))
                for (index, pin) in pins.enumerated() {
                    let pulse = (time * 0.6 + Double(index) * 0.33).truncatingRemainder(dividingBy: 1)
                    let ring = 6 + pulse * 16
                    context.stroke(
                        Path(ellipseIn: CGRect(x: pin.x - ring, y: pin.y - ring, width: ring * 2, height: ring * 2)),
                        with: .color(HeroInk.accent.opacity(0.5 * (1 - pulse))),
                        lineWidth: 1.4
                    )
                    context.fill(Path(ellipseIn: CGRect(x: pin.x - 6, y: pin.y - 6, width: 12, height: 12)), with: .color(HeroInk.lime))
                    context.stroke(Path(ellipseIn: CGRect(x: pin.x - 6, y: pin.y - 6, width: 12, height: 12)), with: .color(HeroInk.line), lineWidth: 1.4)
                }
            }
        }
    }
}

// MARK: - Language: greetings drifting, the chosen one comes forward

struct OnboardingGreetingsHero: View {
    let selected: String

    private let bubbles: [(code: String, text: String, x: CGFloat, y: CGFloat)] = [
        ("uk", "Привіт", -0.2, -0.12),
        ("de", "Grüezi · Hallo", 0.2, 0.2),
        ("en", "Hello", 0.24, -0.28)
    ]

    var body: some View {
        HeroClock { time in
            GeometryReader { geometry in
                let size = geometry.size
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [HeroInk.lime.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: size.height * 0.7))
                        .frame(width: size.height * 1.4, height: size.height * 1.4)
                    ForEach(Array(bubbles.enumerated()), id: \.offset) { index, bubble in
                        let isSelected = bubble.code == selected
                        let drift = sin(time * 0.9 + Double(index) * 2.1) * 5
                        GreetingBubble(text: bubble.text, highlighted: isSelected, tailOnLeft: index != 1)
                            .scaleEffect(isSelected ? 1.12 : 0.92)
                            .opacity(isSelected ? 1 : 0.72)
                            .zIndex(isSelected ? 2 : 0)
                            .offset(x: bubble.x * size.width, y: bubble.y * size.height + drift)
                            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: selected)
                    }
                }
                .frame(width: size.width, height: size.height)
            }
        }
    }
}

private struct GreetingBubble: View {
    let text: String
    let highlighted: Bool
    let tailOnLeft: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(highlighted ? Color.black : JourneyVisual.primaryText)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(highlighted ? JourneyVisual.lime : Theme.Colors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(highlighted ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
            .overlay(alignment: tailOnLeft ? .bottomLeading : .bottomTrailing) {
                BubbleTail()
                    .fill(highlighted ? JourneyVisual.lime : Theme.Colors.card)
                    .frame(width: 14, height: 10)
                    .scaleEffect(x: tailOnLeft ? 1 : -1)
                    .offset(x: tailOnLeft ? 16 : -16, y: 8)
            }
            .shadow(color: .black.opacity(highlighted ? 0.14 : 0.06), radius: highlighted ? 14 : 8, y: 6)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY + rect.height * 0.4))
        path.closeSubpath()
        return path
    }
}

// MARK: - Plan: a route draws itself through checkpoints to the goal

struct OnboardingRouteHero: View {
    private static let cycle = 5.2

    var body: some View {
        HeroClock(still: 3.8) { time in
            Canvas { context, size in
                let w = size.width, h = size.height
                let inset = min(w * 0.18, 70)
                let start = CGPoint(x: inset, y: h * 0.82)
                let end = CGPoint(x: w - inset, y: h * 0.2)
                var path = Path()
                path.move(to: start)
                path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.52), control1: CGPoint(x: w * 0.32, y: h * 0.95), control2: CGPoint(x: w * 0.3, y: h * 0.45))
                path.addCurve(to: end, control1: CGPoint(x: w * 0.7, y: h * 0.6), control2: CGPoint(x: w * 0.68, y: h * 0.12))
                glow(&context, center: CGPoint(x: w * 0.5, y: h * 0.5), radius: h * 0.75, opacity: 0.24, bounds: size)

                let phase = time.truncatingRemainder(dividingBy: Self.cycle)
                let progress = min(1, max(0, (phase - 0.3) / 3.4))
                let fade = phase > 4.6 ? max(0, 1 - (phase - 4.6) / 0.6) : 1
                context.stroke(path, with: .color(HeroInk.line.opacity(0.16)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 7]))
                context.stroke(path.trimmedPath(from: 0, to: progress), with: .color(HeroInk.accent.opacity(fade)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

                for stop in [0.22, 0.52, 0.8] {
                    guard let point = path.trimmedPath(from: 0, to: stop).currentPoint else { continue }
                    let reached = progress >= stop
                    let rect = CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)
                    context.fill(Path(ellipseIn: rect), with: .color(reached ? HeroInk.lime : Theme.Colors.card))
                    context.stroke(Path(ellipseIn: rect), with: .color(HeroInk.line.opacity(reached ? 0.9 : 0.35)), lineWidth: 1.5)
                    if reached {
                        var check = Path()
                        check.move(to: CGPoint(x: point.x - 4.5, y: point.y + 0.5))
                        check.addLine(to: CGPoint(x: point.x - 1, y: point.y + 4))
                        check.addLine(to: CGPoint(x: point.x + 5, y: point.y - 3.5))
                        context.stroke(check, with: .color(.black.opacity(fade)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                }

                // Start dot and goal flag.
                context.fill(Path(ellipseIn: CGRect(x: start.x - 5, y: start.y - 5, width: 10, height: 10)), with: .color(HeroInk.line))
                let raise = progress >= 1 ? 1.0 : 0.0
                var pole = Path()
                pole.move(to: end)
                pole.addLine(to: CGPoint(x: end.x, y: end.y - 34))
                context.stroke(pole, with: .color(HeroInk.line), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                let wave = sin(time * 4) * 2.5 * raise
                var flag = Path()
                flag.move(to: CGPoint(x: end.x, y: end.y - 34))
                flag.addQuadCurve(to: CGPoint(x: end.x + 24, y: end.y - 28 + wave), control: CGPoint(x: end.x + 12, y: end.y - 37 - wave))
                flag.addQuadCurve(to: CGPoint(x: end.x, y: end.y - 20), control: CGPoint(x: end.x + 12, y: end.y - 22 + wave))
                flag.closeSubpath()
                context.fill(flag, with: .color(raise > 0 ? HeroInk.lime : Theme.Colors.card))
                context.stroke(flag, with: .color(HeroInk.line), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - Profile: a residence card fills itself in

struct OnboardingProfileHero: View {
    var body: some View {
        HeroClock(still: 3) { time in
            let phase = time.truncatingRemainder(dividingBy: 5)
            let fill = { (delay: Double) in min(1, max(0, (phase - delay) / 0.7)) }
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [HeroInk.lime.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: 120))
                    .frame(width: 260, height: 260)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.Colors.card)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.primaryText.opacity(0.85), lineWidth: 1.5))
                    .overlay(alignment: .leading) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(JourneyVisual.softSurface)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(JourneyVisual.primaryText.opacity(0.75))
                            }
                            .frame(width: 54, height: 54)
                            VStack(alignment: .leading, spacing: 9) {
                                ForEach([0.4, 1.0, 1.6], id: \.self) { delay in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(JourneyVisual.softBorder).frame(width: 110, height: 8)
                                        Capsule().fill(JourneyVisual.primaryText.opacity(0.8)).frame(width: 110 * fill(delay), height: 8)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 18)
                    }
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(JourneyVisual.lime)
                            .overlay(Image(systemName: "checkmark").font(.system(size: 15, weight: .black)).foregroundStyle(.black))
                            .frame(width: 34, height: 34)
                            .scaleEffect(fill(2.3) < 1 ? fill(2.3) * 1.25 : 1)
                            .opacity(fill(2.3))
                            .offset(x: 10, y: -10)
                    }
                    .frame(width: 220, height: 120)
                    .rotation3DEffect(.degrees(sin(time * 0.7) * 6), axis: (x: 0.2, y: 1, z: 0), perspective: 0.6)
                    .shadow(color: .black.opacity(0.1), radius: 18, y: 10)
            }
        }
    }
}

// MARK: - Family: a small constellation of people holding together

struct OnboardingFamilyHero: View {
    var body: some View {
        HeroClock { time in
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let u = min(size.width, size.height) * 0.42
                glow(&context, center: c, radius: u * 1.6, opacity: 0.26, bounds: size)
                let nodes: [(CGPoint, CGFloat)] = [
                    (CGPoint(x: c.x - u * 0.9, y: c.y - u * 0.25), 15),
                    (CGPoint(x: c.x + u * 0.9, y: c.y - u * 0.3), 15),
                    (CGPoint(x: c.x - u * 0.45, y: c.y + u * 0.55), 10),
                    (CGPoint(x: c.x + u * 0.5, y: c.y + u * 0.6), 10),
                    (CGPoint(x: c.x, y: c.y - u * 0.75), 9)
                ]
                let links = [(0, 1), (0, 2), (1, 3), (2, 3), (0, 4), (1, 4)]
                for (index, link) in links.enumerated() {
                    let a = nodes[link.0].0, b = nodes[link.1].0
                    let reveal = min(1, max(0, (time * 0.5).truncatingRemainder(dividingBy: 4) - Double(index) * 0.18))
                    var line = Path()
                    line.move(to: a)
                    line.addLine(to: CGPoint(x: a.x + (b.x - a.x) * reveal, y: a.y + (b.y - a.y) * reveal))
                    context.stroke(line, with: .color(HeroInk.line.opacity(0.35)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                }
                for (index, node) in nodes.enumerated() {
                    let breathe = 1 + sin(time * 1.4 + Double(index)) * 0.06
                    let radius = node.1 * breathe
                    let rect = CGRect(x: node.0.x - radius, y: node.0.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(index < 2 ? HeroInk.lime : Theme.Colors.card))
                    context.stroke(Path(ellipseIn: rect), with: .color(HeroInk.line.opacity(0.9)), lineWidth: 1.5)
                }
                let beat = 1 + max(0, sin(time * 2.6)) * 0.14
                if let heart = context.resolveSymbol(id: "heart") {
                    var layer = context
                    layer.translateBy(x: c.x, y: c.y + u * 0.05)
                    layer.scaleBy(x: beat, y: beat)
                    layer.draw(heart, at: .zero)
                }
            } symbols: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(JourneyVisual.accentStrong)
                    .tag("heart")
            }
        }
    }
}

// MARK: - Theme: the sun turns into the moon

struct OnboardingThemeHero: View {
    let theme: AppTheme
    @Environment(\.colorScheme) private var colorScheme

    private var night: Double {
        switch theme {
        case .light: return 0
        case .dark: return 1
        default: return colorScheme == .dark ? 1 : 0
        }
    }

    var body: some View {
        HeroClock { time in
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [(night > 0.5 ? Color.indigo : HeroInk.lime).opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: 130))
                    .frame(width: 270, height: 270)
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(JourneyVisual.primaryText.opacity(0.8))
                        .frame(width: 3, height: 13)
                        .offset(y: -66)
                        .rotationEffect(.degrees(Double(index) * 30 + time * 8))
                        .opacity(1 - night)
                        .scaleEffect(1 - night * 0.4)
                }
                ForEach(0..<6, id: \.self) { index in
                    let twinkle = 0.4 + 0.6 * abs(sin(time * 1.3 + Double(index) * 1.7))
                    Image(systemName: "sparkle")
                        .font(.system(size: index.isMultiple(of: 2) ? 12 : 8, weight: .bold))
                        .foregroundStyle(JourneyVisual.primaryText.opacity(twinkle))
                        .offset(x: [-78, 72, -58, 90, 40, -96][index], y: [-44, -52, 50, 30, 62, 6][index])
                        .opacity(night)
                }
                Circle()
                    .fill(night > 0.5 ? Color(white: 0.93) : JourneyVisual.lime)
                    .frame(width: 92, height: 92)
                    .overlay(Circle().stroke(JourneyVisual.primaryText.opacity(0.85), lineWidth: 1.6))
                    .mask {
                        ZStack {
                            Circle().frame(width: 96, height: 96)
                            Circle()
                                .frame(width: 84, height: 84)
                                .offset(x: 30 - (1 - night) * 170, y: -22)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
                    .rotationEffect(.degrees(sin(time * 0.6) * 4))
            }
            .animation(.spring(response: 0.7, dampingFraction: 0.78), value: night)
        }
    }
}

// MARK: - Privacy: anonymous insights inside a shield

struct OnboardingPrivacyHero: View {
    var body: some View {
        HeroClock { time in
            Canvas { context, size in
                let h = min(size.height * 0.9, 160)
                let w = h * 0.82
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                glow(&context, center: c, radius: h * 0.9, opacity: 0.28, bounds: size)
                let rect = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
                var shield = Path()
                shield.move(to: CGPoint(x: rect.midX, y: rect.minY))
                shield.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.16), control: CGPoint(x: rect.midX + w * 0.3, y: rect.minY + h * 0.12))
                shield.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.62), control2: CGPoint(x: rect.midX + w * 0.2, y: rect.maxY - h * 0.08))
                shield.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.16), control1: CGPoint(x: rect.midX - w * 0.2, y: rect.maxY - h * 0.08), control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.62))
                shield.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX - w * 0.3, y: rect.minY + h * 0.12))
                shield.closeSubpath()
                context.fill(shield, with: .color(Theme.Colors.card))

                var inside = context
                inside.clip(to: shield)
                let barWidth = w * 0.11
                for index in 0..<4 {
                    let level = 0.35 + 0.45 * (0.5 + 0.5 * sin(time * 1.1 + Double(index) * 1.3))
                    let barHeight = h * 0.42 * level
                    let x = rect.minX + w * 0.24 + CGFloat(index) * barWidth * 1.55
                    let bar = Path(roundedRect: CGRect(x: x, y: rect.minY + h * 0.7 - barHeight, width: barWidth, height: barHeight), cornerRadius: barWidth / 2)
                    inside.fill(bar, with: .color(index == 2 ? HeroInk.lime : HeroInk.line.opacity(0.75)))
                }
                let sweep = (time * 0.35).truncatingRemainder(dividingBy: 1)
                let y = rect.minY + h * sweep
                inside.fill(
                    Path(CGRect(x: rect.minX, y: y - 18, width: w, height: 36)),
                    with: .linearGradient(
                        Gradient(colors: [HeroInk.lime.opacity(0), HeroInk.lime.opacity(0.35), HeroInk.lime.opacity(0)]),
                        startPoint: CGPoint(x: 0, y: y - 18),
                        endPoint: CGPoint(x: 0, y: y + 18)
                    )
                )
                context.stroke(shield, with: .color(HeroInk.line.opacity(0.9)), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            }
        }
    }
}

// MARK: - Notifications: a bell rings with soft ripples

struct OnboardingBellHero: View {
    var body: some View {
        HeroClock { time in
            let ring = time.truncatingRemainder(dividingBy: 3.2)
            let swing = ring < 0.9 ? sin(ring * 22) * (1 - ring / 0.9) * 16 : 0
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    let progress = (time * 0.42 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(JourneyVisual.accentStrong.opacity(0.45 * (1 - progress)), lineWidth: 1.4)
                        .frame(width: 80 + progress * 150, height: 80 + progress * 150)
                }
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(JourneyVisual.lime)
                    .frame(width: 86, height: 86)
                    .overlay(
                        Image(systemName: "bell.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.black)
                            .rotationEffect(.degrees(swing), anchor: .top)
                    )
                    .shadow(color: JourneyVisual.lime.opacity(0.4), radius: 22, y: 8)
                Capsule()
                    .fill(Theme.Colors.card)
                    .overlay(
                        HStack(spacing: 6) {
                            Circle().fill(JourneyVisual.accentStrong).frame(width: 8, height: 8)
                            Capsule().fill(JourneyVisual.primaryText.opacity(0.7)).frame(width: 46, height: 6)
                        }
                    )
                    .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
                    .frame(width: 90, height: 30)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    .offset(x: 92, y: -46 + (ring < 0.5 ? (0.5 - ring) * -40 : 0))
                    .opacity(ring < 2.6 ? 1 : max(0, 1 - (ring - 2.6) / 0.6))
            }
        }
    }
}

// MARK: - Success: the plan ring fills and blooms into a check

struct OnboardingBloomHero: View {
    let progress: Double
    let ready: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HeroClock { time in
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [HeroInk.lime.opacity(ready ? 0.42 : 0.24), .clear], center: .center, startRadius: 0, endRadius: 120))
                    .frame(width: 250, height: 250)
                ForEach(0..<10, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? JourneyVisual.lime : JourneyVisual.accentStrong)
                        .frame(width: 6, height: 18)
                        .offset(y: ready ? -96 : -60)
                        .rotationEffect(.degrees(Double(index) * 36 + time * 6))
                        .opacity(ready ? 1 : 0)
                        .scaleEffect(ready ? 1 : 0.4)
                }
                Circle()
                    .stroke(JourneyVisual.softBorder, lineWidth: 10)
                    .frame(width: 128, height: 128)
                Circle()
                    .trim(from: 0, to: ready ? 1 : progress)
                    .stroke(JourneyVisual.accentStrong, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 128, height: 128)
                Circle()
                    .fill(ready ? JourneyVisual.lime : Theme.Colors.card)
                    .frame(width: 104, height: 104)
                CheckmarkShape()
                    .trim(from: 0, to: ready ? 1 : 0)
                    .stroke(.black, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    .frame(width: 44, height: 34)
                if !ready {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(JourneyVisual.accentStrong)
                        .opacity(0.5 + 0.5 * sin(time * 2.4))
                }
            }
            .scaleEffect(ready && !reduceMotion ? 1 + 0.02 * sin(time * 1.6) : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.62), value: ready)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: progress)
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Ambient background

/// Paper background with slow, blurred light pools; each step gets its own arrangement.
struct OnboardingAmbientBackground: View {
    let step: Int
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var anchors: [(CGFloat, CGFloat, Color)] {
        let teal = Color(red: 0.2, green: 0.74, blue: 0.68)
        let layouts: [[(CGFloat, CGFloat, Color)]] = [
            [(0.85, 0.12, JourneyVisual.lime), (0.1, 0.55, teal), (0.7, 0.95, JourneyVisual.lime)],
            [(0.15, 0.1, teal), (0.9, 0.45, JourneyVisual.lime), (0.25, 0.95, JourneyVisual.lime)],
            [(0.5, 0.05, JourneyVisual.lime), (0.95, 0.75, teal), (0.05, 0.85, JourneyVisual.lime)]
        ]
        return layouts[step % layouts.count]
    }

    var body: some View {
        HeroClock(still: 0) { time in
            GeometryReader { geometry in
                let size = geometry.size
                ZStack {
                    JourneyVisual.pageBackground
                    ForEach(Array(anchors.enumerated()), id: \.offset) { index, anchor in
                        let drift = reduceMotion ? 0 : time * 0.08 + Double(index) * 2
                        Circle()
                            .fill(anchor.2.opacity(colorScheme == .dark ? 0.12 : 0.22))
                            .frame(width: size.width * 0.95, height: size.width * 0.95)
                            .blur(radius: 70)
                            .position(
                                x: size.width * anchor.0 + cos(drift) * 26,
                                y: size.height * anchor.1 + sin(drift * 1.3) * 22
                            )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
