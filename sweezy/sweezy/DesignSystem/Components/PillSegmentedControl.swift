//
//  PillSegmentedControl.swift
//  sweezy
//
//  Pill-shaped segmented control for ink headers (Modychat-inspired).
//  Active segment is a white pill with ink text; inactive segments are
//  translucent white labels on the dark track.
//

import SwiftUI

struct PillSegmentedControl: View {
    let items: [String]
    @Binding var selection: Int

    @Namespace private var pillNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { index in
                segment(at: index)
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.Colors.inkElevated)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.Colors.inkBorder, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private func segment(at index: Int) -> some View {
        let isSelected = selection == index
        return Button {
            guard selection != index else { return }
            if reduceMotion {
                selection = index
            } else {
                withAnimation(Theme.Animation.smooth) {
                    selection = index
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(items[index])
                .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundColor(isSelected ? Theme.Colors.ink : Color.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Color.white)
                            .matchedGeometryEffect(id: "activePill", in: pillNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(items[index])
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    ZStack {
        Theme.Colors.ink.ignoresSafeArea()

        VStack(spacing: Theme.Spacing.lg) {
            PillSegmentedControl(items: ["Focus", "Tasks", "Guides"], selection: .constant(0))
            PillSegmentedControl(items: ["Chats", "Status", "Calls"], selection: .constant(1))
        }
        .padding(Theme.Spacing.lg)
    }
}
