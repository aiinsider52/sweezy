import SwiftUI

/// First visit to a section: a short story with a living scene per slide.
struct FeatureOnboardingView: View {
    let content: FeatureOnboardingContent
    let onDismiss: () -> Void

    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLastPage: Bool {
        currentPage >= content.slides.count - 1
    }

    var body: some View {
        ZStack {
            OnboardingAmbientBackground(step: currentPage)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                TabView(selection: $currentPage) {
                    ForEach(Array(content.slides.enumerated()), id: \.element.id) { index, slide in
                        FeatureOnboardingSlideView(
                            slide: slide,
                            satellites: content.feature.satelliteSymbols(for: index),
                            isActive: currentPage == index
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
        }
        .sensoryFeedback(.selection, trigger: currentPage)
    }

    private var header: some View {
        HStack(spacing: 14) {
            // Story-style progress: one segment per slide, the current one fills in.
            HStack(spacing: 5) {
                ForEach(content.slides.indices, id: \.self) { index in
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(JourneyVisual.primaryText.opacity(0.12))
                            Capsule()
                                .fill(JourneyVisual.accentStrong)
                                .frame(width: index <= currentPage ? proxy.size.width : 0)
                        }
                    }
                    .frame(height: 5)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: currentPage)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            Button(action: finish) {
                Text("onboarding.skip".localized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Theme.Colors.card.opacity(0.85), in: Capsule())
                    .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("featureOnboarding.close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var footer: some View {
        Button(action: advance) {
            HStack(spacing: 10) {
                Text(isLastPage ? content.buttonTitle : "onboarding.next".localized)
                    .font(.system(size: 17, weight: .bold))
                    .contentTransition(.opacity)
                Image(systemName: isLastPage ? "checkmark" : "arrow.right")
                    .font(.system(size: 15, weight: .black))
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(JourneyVisual.lime, in: Capsule())
            .shadow(color: JourneyVisual.lime.opacity(0.35), radius: 18, y: 8)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: reduceMotion ? 1 : 0.97))
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .animation(.easeOut(duration: 0.2), value: isLastPage)
    }

    private func advance() {
        if isLastPage {
            finish()
        } else {
            withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
                currentPage += 1
            }
        }
    }

    private func finish() {
        FeatureOnboardingManager.shared.markAsSeen(content.feature)
        onDismiss()
    }
}

// MARK: - Slide

private struct FeatureOnboardingSlideView: View {
    let slide: OnboardingSlide
    let satellites: [String]
    let isActive: Bool

    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                FeatureOnboardingScene(icon: slide.icon, satellites: satellites, revealed: revealed)
                    .frame(height: min(340, proxy.size.height * 0.56))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 14) {
                    Text(slide.title)
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(JourneyVisual.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.8)
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 16)
                        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85).delay(0.12), value: revealed)

                    Capsule()
                        .fill(JourneyVisual.lime)
                        .frame(width: revealed ? 74 : 0, height: 7)
                        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8).delay(0.24), value: revealed)

                    Text(slide.description)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 12)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.3), value: revealed)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 8)
            }
        }
        .onAppear { if isActive { revealed = true } }
        .onChange(of: isActive) { _, active in
            if reduceMotion { revealed = active; return }
            if active {
                revealed = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { revealed = true }
            } else {
                revealed = false
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Living scene

/// Lime sticker with the section icon, orbiting helpers and a card that "does the work".
private struct FeatureOnboardingScene: View {
    let icon: String
    let satellites: [String]
    let revealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 1.2 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width / 2, y: size.height * 0.46)
                let radius = min(size.width * 0.38, size.height * 0.4)

                ZStack {
                    // Rings turn slowly in opposite directions.
                    orbitRing(diameter: radius * 2, dash: [3, 9], rotation: time * 8)
                        .position(center)
                    orbitRing(diameter: radius * 1.35, dash: [2, 7], rotation: -time * 12)
                        .position(center)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [JourneyVisual.lime.opacity(0.55), JourneyVisual.lime.opacity(0)],
                                center: .center, startRadius: 0, endRadius: radius * 0.85
                            )
                        )
                        .frame(width: radius * 1.7, height: radius * 1.7)
                        .scaleEffect(1 + 0.05 * sin(time * 1.6))
                        .position(center)

                    ForEach(Array(satellites.enumerated()), id: \.offset) { index, symbol in
                        let count = Double(max(satellites.count, 1))
                        let orbit = index.isMultiple(of: 2) ? radius : radius * 0.68
                        let angle = (Double(index) / count) * 2 * .pi + time * (index.isMultiple(of: 2) ? 0.22 : -0.3)
                        let landed = revealed ? 1.0 : 0.35
                        satellite(symbol, index: index)
                            .position(
                                x: center.x + cos(angle) * orbit * landed,
                                y: center.y + sin(angle) * orbit * 0.82 * landed
                            )
                            .opacity(revealed ? 1 : 0)
                            .scaleEffect(revealed ? 1 : 0.4)
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(0.05 * Double(index)),
                                value: revealed
                            )
                    }

                    sticker
                        .position(x: center.x, y: center.y + CGFloat(sin(time * 1.4)) * 6)
                        .rotationEffect(.degrees(sin(time * 0.9) * 2.5))

                    workCard(time: time)
                        .frame(width: min(250, size.width * 0.66))
                        .position(x: center.x, y: min(size.height - 30, center.y + radius + 48))
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 24)
                        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.8).delay(0.2), value: revealed)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var sticker: some View {
        Image(systemName: icon)
            .font(.system(size: 42, weight: .bold))
            .foregroundColor(.black)
            .symbolEffect(.bounce, value: revealed)
            .frame(width: 104, height: 104)
            .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(.white.opacity(0.7), lineWidth: 2))
            .shadow(color: JourneyVisual.lime.opacity(0.6), radius: 26, y: 10)
            .scaleEffect(revealed ? 1 : 0.6)
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: revealed)
    }

    private func satellite(_ symbol: String, index: Int) -> some View {
        let swatches = [JourneyCategoryPalette.sky, JourneyCategoryPalette.coral, JourneyCategoryPalette.teal, JourneyCategoryPalette.sand, JourneyCategoryPalette.lilac]
        return JourneyCategoryIcon(symbol: symbol, swatch: swatches[index % swatches.count], size: index.isMultiple(of: 2) ? 46 : 38)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private func orbitRing(diameter: CGFloat, dash: [CGFloat], rotation: Double) -> some View {
        Circle()
            .stroke(JourneyVisual.primaryText.opacity(0.16), style: StrokeStyle(lineWidth: 1.2, dash: dash))
            .frame(width: diameter, height: diameter * 0.82)
            .rotationEffect(.degrees(rotation))
    }

    /// Skeleton lines fill in and a tick lands: the section takes care of something for you.
    private func workCard(time: Double) -> some View {
        let cycle = reduceMotion ? 1 : (time.truncatingRemainder(dividingBy: 3.2)) / 3.2
        let fill = min(1, cycle * 1.6)
        let done = cycle > 0.62
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(JourneyVisual.accentStrong)
                .frame(width: 32, height: 32)
                .background(JourneyVisual.softSurface, in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(JourneyVisual.primaryText.opacity(0.1))
                        Capsule().fill(JourneyVisual.primaryText.opacity(0.32))
                            .frame(width: proxy.size.width * fill)
                    }
                }
                .frame(height: 7)
                Capsule().fill(JourneyVisual.primaryText.opacity(0.1)).frame(width: 70, height: 6)
            }
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(done ? JourneyVisual.accentStrong : JourneyVisual.primaryText.opacity(0.2))
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: done)
        }
        .padding(10)
        .background(Theme.Colors.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }
}

extension OnboardingFeature {
    /// Small helpers circling the section icon: what lives inside this part of the app.
    func satelliteSymbols(for slide: Int) -> [String] {
        let sets: [[String]]
        switch self {
        case .dovidnyk, .guides: sets = [["doc.text.fill", "house.fill", "briefcase.fill", "cross.case.fill", "graduationcap.fill"], ["checkmark.circle.fill", "calendar", "bell.fill", "flag.fill"]]
        case .checklists: sets = [["checkmark.circle.fill", "calendar", "doc.text.fill", "flag.fill"]]
        case .map: sets = [["building.columns.fill", "cross.fill", "tram.fill", "fork.knife", "bag.fill"]]
        case .marketplace: sets = [["tag.fill", "bag.fill", "wrench.and.screwdriver.fill", "bubble.left.fill"], ["calendar", "person.3.fill", "ticket.fill", "mappin"]]
        case .people: sets = [["heart.fill", "bubble.left.and.bubble.right.fill", "mappin", "sparkles"], ["calendar", "person.3.fill", "figure.hiking", "cup.and.saucer.fill"]]
        case .settings: sets = [["bell.fill", "globe", "lock.fill", "person.fill"]]
        case .calculator: sets = [["banknote.fill", "percent", "person.2.fill", "house.fill"]]
        case .roadmap: sets = [["flag.fill", "figure.hiking", "checkmark", "mountain.2.fill"], ["star.fill", "rosette", "bolt.fill", "flame.fill"]]
        case .jobs: sets = [["doc.text.fill", "magnifyingglass", "chart.line.uptrend.xyaxis", "person.crop.rectangle.fill"]]
        case .templates: sets = [["pencil", "envelope.fill", "signature", "printer.fill"]]
        case .appointments: sets = [["clock.fill", "bell.fill", "mappin", "person.fill"]]
        case .subscription: sets = [["sparkles", "infinity", "star.fill", "bolt.fill"]]
        case .news: sets = [["globe.europe.africa.fill", "bell.fill", "bookmark.fill", "text.alignleft"]]
        case .gamification: sets = [["star.fill", "flame.fill", "rosette", "bolt.fill"]]
        case .cvBuilder: sets = [["textformat", "person.fill", "briefcase.fill", "character.bubble.fill"]]
        }
        return sets[slide % sets.count]
    }
}

struct FeatureOnboardingModifier: ViewModifier {
    let content: FeatureOnboardingContent
    @State private var showOnboarding = false

    func body(content view: Content) -> some View {
        view
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if FeatureOnboardingManager.shared.shouldShowOnboarding(for: content.feature) {
                        showOnboarding = true
                    }
                }
            }
            .sheet(isPresented: $showOnboarding) {
                FeatureOnboardingView(content: content) {
                    showOnboarding = false
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func featureOnboarding(_ content: FeatureOnboardingContent) -> some View {
        modifier(FeatureOnboardingModifier(content: content))
    }
}

#Preview("Feature onboarding") {
    FeatureOnboardingView(content: .marketplace) {}
}
