import SwiftUI

struct ChipView: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(_ title: String, systemImage: String? = nil, isSelected: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Theme.Colors.gradientAccent)
                    } else {
                        Capsule().fill(Theme.Colors.primaryBackground)
                    }
                }
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Theme.Colors.chipBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .themeShadow(isSelected ? Theme.Shadows.level1 : Theme.Shadows.level0)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97))
    }
}

#Preview {
    HStack {
        ChipView("All", systemImage: "square.grid.2x2", isSelected: true) {}
        ChipView("Housing", systemImage: "house") {}
        ChipView("Work", systemImage: "briefcase") {}
    }
}
