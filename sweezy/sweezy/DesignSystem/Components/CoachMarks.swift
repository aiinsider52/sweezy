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
                    .transition(.opacity)
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
    
    private var currentStep: CoachMarkStep {
        steps[min(max(stepIndex, 0), steps.count - 1)]
    }
    
    var body: some View {
        GeometryReader { proxy in
            let highlightRect: CGRect? = {
                guard let targetId = currentStep.targetId,
                      let anchor = anchors[targetId]
                else { return nil }
                return proxy[anchor].insetBy(dx: -10, dy: -10)
            }()
            
            ZStack(alignment: .bottom) {
                CoachMarksDimmedMask(highlightRect: highlightRect)
                    .contentShape(Rectangle())
                    .onTapGesture { /* swallow taps */ }
                
                if let rect = highlightRect {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .shadow(color: Color.cyan.opacity(0.25), radius: 14, x: 0, y: 6)
                        .allowsHitTesting(false)
                }
                
                coachMarkCard
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.lg)
            }
            .ignoresSafeArea()
            .onAppear { runStepAppearIfNeeded() }
            .onChange(of: stepIndex) { _, _ in runStepAppearIfNeeded() }
        }
        .accessibilityAddTraits(.isModal)
    }
    
    private var coachMarkCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(currentStep.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(stepIndex + 1)/\(steps.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text(currentStep.message)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: Theme.Spacing.sm) {
                Button("onboarding.skip".localized) { finish() }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                if stepIndex > 0 {
                    Button("common.back".localized) {
                        withAnimation(Theme.Animation.quick) {
                            stepIndex -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.9))
                }
                
                Button(stepIndex == steps.count - 1 ? "common.done".localized : "common.next".localized) {
                    if stepIndex == steps.count - 1 {
                        finish()
                    } else {
                        withAnimation(Theme.Animation.quick) {
                            stepIndex += 1
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.cyan)
                        .shadow(color: Color.cyan.opacity(0.25), radius: 10, x: 0, y: 6)
                )
                .foregroundColor(Color.black.opacity(0.85))
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xxl, style: .continuous)
                .fill(Color.black.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.xxl, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 26, x: 0, y: 12)
    }
    
    private func finish() {
        withAnimation(Theme.Animation.micro) {
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
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true, antialiased: true))
        }
    }
}

