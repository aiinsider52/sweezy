//
//  CoachMarks.swift
//  sweezy
//
//  Lightweight, reusable page tours ("coach marks") for feature discovery.
//

import SwiftUI

/// A single step in a page tour.
struct CoachMarkStep: Identifiable {
    let id: String
    let title: String
    let message: String
    let targetId: String?
    let onAppear: (() -> Void)?
    
    init(
        id: String,
        title: String,
        message: String,
        targetId: String? = nil,
        onAppear: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.targetId = targetId
        self.onAppear = onAppear
    }
}

private struct CoachMarkTargetsPreferenceKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, rhs in rhs })
    }
}

extension View {
    /// Marks this view as a target that can be highlighted by a coach mark step.
    func coachMarkTarget(_ id: String) -> some View {
        anchorPreference(key: CoachMarkTargetsPreferenceKey.self, value: .bounds) { [id: $0] }
    }
    
    /// Presents a coach-marks overlay for the provided steps.
    func coachMarks(
        steps: [CoachMarkStep],
        isPresented: Binding<Bool>,
        onFinish: (() -> Void)? = nil
    ) -> some View {
        modifier(CoachMarksModifier(steps: steps, isPresented: isPresented, onFinish: onFinish))
    }
}

private struct CoachMarksModifier: ViewModifier {
    let steps: [CoachMarkStep]
    @Binding var isPresented: Bool
    let onFinish: (() -> Void)?
    
    @State private var stepIndex: Int = 0
    
    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(CoachMarkTargetsPreferenceKey.self) { anchors in
                if isPresented, !steps.isEmpty {
                    CoachMarksOverlay(
                        steps: steps,
                        anchors: anchors,
                        stepIndex: $stepIndex,
                        isPresented: $isPresented,
                        onFinish: onFinish
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    stepIndex = 0
                }
            }
    }
}

private struct CoachMarksOverlay: View {
    let steps: [CoachMarkStep]
    let anchors: [String: Anchor<CGRect>]
    @Binding var stepIndex: Int
    @Binding var isPresented: Bool
    let onFinish: (() -> Void)?
    
    @State private var lastStepId: String?
    @State private var animateIn: Bool = false
    
    private var currentStep: CoachMarkStep {
        steps[min(max(stepIndex, 0), steps.count - 1)]
    }
    
    // Tab bar height + safe area
    private let bottomInset: CGFloat = 100
    private let topInset: CGFloat = 60
    
    var body: some View {
        GeometryReader { proxy in
            let highlightRect: CGRect? = {
                guard let targetId = currentStep.targetId,
                      let anchor = anchors[targetId]
                else { return nil }
                return proxy[anchor].insetBy(dx: -8, dy: -8)
            }()
            
            let screenHeight = proxy.size.height
            let screenWidth = proxy.size.width
            
            // Determine if tooltip should be above or below the highlight
            let shouldShowAbove: Bool = {
                guard let rect = highlightRect else { return false }
                // If highlight is in bottom half, show tooltip above
                return rect.midY > screenHeight * 0.45
            }()
            
            ZStack {
                // Dimmed background with cutout
                CoachMarksDimmedMask(highlightRect: highlightRect)
                    .contentShape(Rectangle())
                    .onTapGesture { /* swallow taps */ }
                
                // Highlight border with glow
                if let rect = highlightRect {
                    ZStack {
                        // Outer glow
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 4)
                            .frame(width: rect.width + 4, height: rect.height + 4)
                            .blur(radius: 8)
                        
                        // Main border
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan, Color.cyan.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: rect.width, height: rect.height)
                        
                        // Pulsing animation
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(animateIn ? 0.3 : 0), lineWidth: 1)
                            .frame(width: rect.width + 8, height: rect.height + 8)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animateIn)
                    }
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
                }
                
                // Tooltip card with smart positioning
                VStack(spacing: 0) {
                    if shouldShowAbove {
                        Spacer()
                    }
                    
                    VStack(spacing: 0) {
                        if !shouldShowAbove, let rect = highlightRect {
                            // Arrow pointing up to the highlight
                            CoachMarkArrow(pointsUp: false)
                                .offset(x: calculateArrowOffset(for: rect, screenWidth: screenWidth))
                        }
                        
                        coachMarkCard
                        
                        if shouldShowAbove, let rect = highlightRect {
                            // Arrow pointing down to the highlight
                            CoachMarkArrow(pointsUp: true)
                                .offset(x: calculateArrowOffset(for: rect, screenWidth: screenWidth))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, shouldShowAbove ? 0 : (highlightRect.map { $0.maxY + 16 } ?? topInset))
                    .padding(.bottom, shouldShowAbove ? (highlightRect.map { screenHeight - $0.minY + 16 } ?? bottomInset) : bottomInset)
                    
                    if !shouldShowAbove {
                        Spacer()
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                runStepAppearIfNeeded()
                withAnimation(.easeOut(duration: 0.3)) {
                    animateIn = true
                }
            }
            .onChange(of: stepIndex) { _, _ in runStepAppearIfNeeded() }
        }
        .accessibilityAddTraits(.isModal)
    }
    
    private func calculateArrowOffset(for rect: CGRect, screenWidth: CGFloat) -> CGFloat {
        let cardCenter = screenWidth / 2
        let targetCenter = rect.midX
        let maxOffset: CGFloat = 100
        return min(max(targetCenter - cardCenter, -maxOffset), maxOffset)
    }
    
    private var coachMarkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with step counter
            HStack(alignment: .center, spacing: 8) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                
                Text(currentStep.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Step indicator pills
                HStack(spacing: 4) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == stepIndex ? Color.cyan : Color.white.opacity(0.3))
                            .frame(width: index == stepIndex ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: stepIndex)
                    }
                }
            }
            
            // Message
            Text(currentStep.message)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // Buttons
            HStack(spacing: 12) {
                Button {
                    finish()
                } label: {
                    Text("onboarding.skip".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if stepIndex > 0 {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            stepIndex -= 1
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("common.back".localized)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    if stepIndex == steps.count - 1 {
                        finish()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            stepIndex += 1
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(stepIndex == steps.count - 1 ? "common.done".localized : "common.next".localized)
                            .font(.system(size: 14, weight: .semibold))
                        if stepIndex < steps.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.cyan.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.cyan.opacity(0.4), radius: 12, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            ZStack {
                // Glassmorphism background
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                
                // Gradient overlay
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.1, green: 0.15, blue: 0.25).opacity(0.7),
                                Color(red: 0.05, green: 0.1, blue: 0.2).opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Border gradient
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.5),
                                Color.white.opacity(0.15),
                                Color.cyan.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
        .shadow(color: Color.cyan.opacity(0.15), radius: 20, x: 0, y: 5)
    }
    
    private func finish() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
        onFinish?()
    }
    
    private func runStepAppearIfNeeded() {
        let step = currentStep
        guard step.id != lastStepId else { return }
        lastStepId = step.id
        step.onAppear?()
    }
}

// MARK: - Arrow pointing to highlight

private struct CoachMarkArrow: View {
    let pointsUp: Bool
    
    var body: some View {
        Triangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.15, blue: 0.25).opacity(0.9),
                        Color(red: 0.05, green: 0.1, blue: 0.2).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 20, height: 10)
            .rotationEffect(.degrees(pointsUp ? 180 : 0))
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: pointsUp ? -2 : 2)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dimmed Mask

private struct CoachMarksDimmedMask: View {
    let highlightRect: CGRect?
    
    var body: some View {
        GeometryReader { proxy in
            let full = proxy.frame(in: .local)
            
            Path { path in
                path.addRect(full)
                if let highlightRect {
                    path.addRoundedRect(in: highlightRect, cornerSize: CGSize(width: 16, height: 16))
                }
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true, antialiased: true))
        }
    }
}
