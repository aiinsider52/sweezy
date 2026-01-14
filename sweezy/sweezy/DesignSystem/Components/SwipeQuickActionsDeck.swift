import SwiftUI

struct QuickActionCardItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: LocalizedStringKey
    let colors: [Color]
    let action: () -> Void
    // Optional status badge
    let badgeText: String?
    let badgeColor: Color?
    
    init(icon: String, title: LocalizedStringKey, colors: [Color], badgeText: String? = nil, badgeColor: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.colors = colors
        self.badgeText = badgeText
        self.badgeColor = badgeColor
        self.action = action
    }
}

struct SwipeQuickActionsDeck: View {
    let items: [QuickActionCardItem]
    
    // Tuning
    private let cardCorner: CGFloat = 20
    private let cardSide: CGFloat = 220
    private let overlap: CGFloat = 36
    private let tiltMax: CGFloat = 8
    
    var body: some View {
        GeometryReader { outer in
            let containerCenter = outer.size.width / 2
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -overlap) {
                    ForEach(items.indices, id: \.self) { i in
                        GeometryReader { geo in
                            let midX = geo.frame(in: .global).midX
                            let distance = abs(midX - containerCenter)
                            let t = min(1, distance / containerCenter)
                            let scale = 1 - t * 0.12
                            let tilt = (midX - containerCenter) / containerCenter * tiltMax
                            let z = 1 - Double(t)
                            
                            QuickActionCard(
                                item: items[i],
                                corner: cardCorner,
                                side: cardSide
                            )
                            .scaleEffect(scale)
                            .rotation3DEffect(.degrees(Double(tilt)), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                            .shadow(color: Color.black.opacity(0.2 + Double((1 - t) * 0.1)), radius: 18, x: 0, y: 10)
                            .zIndex(z)
                            .onTapGesture {
                                haptic(.soft)
                                items[i].action()
                            }
                        }
                        .frame(width: cardSide, height: cardSide)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg + overlap/2)
                .padding(.vertical, 8)
            }
        }
        .frame(height: cardSide + 24)
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}

private struct NeonBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(Theme.Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.22))
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

private struct QuickActionCard: View {
    let item: QuickActionCardItem
    let corner: CGFloat
    let side: CGFloat
    
    var body: some View {
        let accent1 = item.colors.first ?? Theme.Colors.accent
        let accent2 = item.colors.last ?? Theme.Colors.accent
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: item.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Ambient aurora glows
            Circle()
                .fill(accent1.opacity(0.35))
                .frame(width: side * 0.8, height: side * 0.8)
                .blur(radius: 50)
                .offset(x: -side * 0.25, y: -side * 0.25)
                .allowsHitTesting(false)
            Circle()
                .fill(accent2.opacity(0.28))
                .frame(width: side * 0.7, height: side * 0.7)
                .blur(radius: 45)
                .offset(x: side * 0.2, y: side * 0.25)
                .allowsHitTesting(false)
            
            // Soft highlight sweep
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.14), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                
                // Icon circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                        )
                        .shadow(color: accent1.opacity(0.35), radius: 10, x: 0, y: 4)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Title
                Text(item.title)
                    .font(Theme.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                
                Spacer()
                
                // CTA
                HStack(spacing: 6) {
                    Text("Перейти")
                        .font(Theme.Typography.caption)
                        .fontWeight(.medium)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.95))
                .padding(.bottom, 16)
            }
            .padding(.vertical, 20)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            accent1.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .shadow(color: accent1.opacity(0.35), radius: 8, x: 0, y: 0)
        )
        .overlay(alignment: .topTrailing) {
            if let text = item.badgeText {
                NeonBadge(text: text, color: item.badgeColor ?? Theme.Colors.success)
                    .padding(12)
            }
        }
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
}


