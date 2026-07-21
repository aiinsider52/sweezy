import SwiftUI

struct FeatureOnboardingView: View {
    let content: FeatureOnboardingContent
    let onDismiss: () -> Void

    @State private var currentPage = 0
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLastPage: Bool {
        currentPage >= content.slides.count - 1
    }

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                header

                TabView(selection: $currentPage) {
                    ForEach(Array(content.slides.enumerated()), id: \.element.id) { index, slide in
                        slideView(slide, index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.45)) {
                    appeared = true
                }
            }
        }
    }

    private var onboardingBackground: some View {
        GeometryReader { geometry in
            Image(content.feature.onboardingImageName)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(Color.black.opacity(0.28))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.08),
                            Color.black.opacity(0.18),
                            JourneyVisual.black.opacity(0.94)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(JourneyVisual.lime)
                    .frame(width: 8, height: 8)
                Text("SWEEZY")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.4)
                Text("\(currentPage + 1)/\(max(content.slides.count, 1))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.58))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color.black.opacity(0.46))
            .background(.ultraThinMaterial.opacity(0.5))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))

            Spacer()

            Button(action: finish) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.black.opacity(0.46))
                    .background(.ultraThinMaterial.opacity(0.5))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("onboarding.skip".localized)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func slideView(_ slide: OnboardingSlide, index: Int) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Spacer(minLength: 26)

                Text(slide.title)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(-3)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.82)
                    .shadow(color: .black.opacity(0.48), radius: 14, y: 5)

                Capsule()
                    .fill(JourneyVisual.lime)
                    .frame(width: 74, height: 7)

                Text(slide.description)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.82))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                featurePreview(slide, index: index)
                    .padding(.top, 4)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (appeared ? 0 : 18))
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func featurePreview(_ slide: OnboardingSlide, index: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(content.feature.onboardingImageName)
                .resizable()
                .scaledToFill()
                .frame(height: 244)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: slide.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 54, height: 54)
                        .background(JourneyVisual.lime)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                    Spacer()

                    Label("\(index + 1)", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(.white)
                        .clipShape(Capsule())
                }

                Spacer()

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(slide.title)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Text(slide.description)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.62))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 42, height: 42)
                        .background(JourneyVisual.lime)
                        .clipShape(Circle())
                }
            }
            .padding(16)
        }
        .frame(height: 244)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.36), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, y: 14)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            if content.slides.count > 1 {
                HStack(spacing: 7) {
                    ForEach(content.slides.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? JourneyVisual.lime : .white.opacity(0.28))
                            .frame(width: index == currentPage ? 32 : 8, height: 8)
                            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.8), value: currentPage)
                    }
                }
                .accessibilityHidden(true)
            }

            Button(action: advance) {
                HStack(spacing: 10) {
                    Text(isLastPage ? content.buttonTitle : "onboarding.next".localized)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Image(systemName: isLastPage ? "checkmark" : "arrow.right")
                        .font(.system(size: 15, weight: .black))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(JourneyVisual.lime)
                .clipShape(Capsule())
                .shadow(color: JourneyVisual.lime.opacity(0.28), radius: 18, y: 8)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: reduceMotion ? 1 : 0.97))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            LinearGradient(
                colors: [.clear, JourneyVisual.black.opacity(0.9), JourneyVisual.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func advance() {
        if isLastPage {
            finish()
        } else if reduceMotion {
            currentPage += 1
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                currentPage += 1
            }
        }
    }

    private func finish() {
        FeatureOnboardingManager.shared.markAsSeen(content.feature)
        onDismiss()
    }
}

private extension OnboardingFeature {
    var onboardingImageName: String {
        switch self {
        case .dovidnyk, .checklists, .guides, .templates, .news:
            return "cityhub-zurich-landesmuseum"
        case .roadmap:
            return "swiss-moment-grindelwald"
        case .map:
            return "cityhub-zurich-lake"
        case .marketplace, .appointments:
            return "journey-market-consultant"
        case .jobs, .cvBuilder:
            return "cityhub-zurich-viadukt"
        case .calculator, .settings, .subscription:
            return "cityhub-zurich-oldtown"
        case .gamification:
            return "cityhub-zurich-uetliberg"
        }
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
            .fullScreenCover(isPresented: $showOnboarding) {
                FeatureOnboardingView(content: content) {
                    showOnboarding = false
                }
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
