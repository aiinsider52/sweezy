import SwiftUI

/// "2 of 3 free left" under an AI action, so the limit is never a surprise. Hidden for Plus
/// members and until the server has reported the count.
struct FreeUsesBadge: View {
    let feature: String
    let limit: Int
    var onUpgrade: (() -> Void)?

    @StateObject private var manager = SubscriptionManager.shared

    var body: some View {
        if !manager.isPremium, let left = manager.freeUsesRemaining[feature] {
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    ForEach(0..<limit, id: \.self) { index in
                        Capsule()
                            .fill(index < left ? JourneyVisual.accentStrong : JourneyVisual.softBorder)
                            .frame(width: limit > 6 ? 6 : 14, height: 5)
                    }
                }
                .accessibilityHidden(true)
                Text(left > 0
                     ? "free_uses.left".localized(with: "\(left)", "\(limit)")
                     : "free_uses.none".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(left > 0 ? JourneyVisual.secondaryText : JourneyVisual.accentText)
                if let onUpgrade {
                    Button("Plus", action: onUpgrade)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(JourneyVisual.lime)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(JourneyVisual.black, in: Capsule())
                        .buttonStyle(.plain)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("freeUses.\(feature)")
        }
    }
}
