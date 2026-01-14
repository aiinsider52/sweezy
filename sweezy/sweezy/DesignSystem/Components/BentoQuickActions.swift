import SwiftUI

// MARK: - Bento Quick Actions Grid (Apple-style + Glassmorphism)

struct BentoQuickActionItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let accentColor: Color
    let badgeText: String?
    let isLocked: Bool
    let action: () -> Void
    
    init(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        accentColor: Color = .cyan,
        badgeText: String? = nil,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.badgeText = badgeText
        self.isLocked = isLocked
        self.action = action
    }
}

struct BentoQuickActions: View {
    let featuredItem: BentoQuickActionItem
    let items: [BentoQuickActionItem]
    
    @State private var appeared = false
    
    private let gridSpacing: CGFloat = 12
    
    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let featuredWidth = totalWidth * 0.55
            let smallWidth = totalWidth - featuredWidth - gridSpacing
            let smallHeight = (220 - gridSpacing) / 2
            
            HStack(spacing: gridSpacing) {
                // Featured large card (left)
                BentoFeaturedCard(item: featuredItem)
                    .frame(width: featuredWidth, height: 220)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0), value: appeared)
                
                // Small cards stack (right)
                VStack(spacing: gridSpacing) {
                    ForEach(Array(items.prefix(2).enumerated()), id: \.element.id) { index, item in
                        BentoCompactCard(item: item)
                            .frame(width: smallWidth, height: smallHeight)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1 + Double(index) * 0.08), value: appeared)
                    }
                }
            }
        }
        .frame(height: 220)
        .onAppear {
            if !appeared {
                appeared = true
            }
        }
    }
}

// MARK: - Featured Card (Large)

private struct BentoFeaturedCard: View {
    let item: BentoQuickActionItem
    @State private var isPressed = false
    
    var body: some View {
        Button {
            if !item.isLocked {
                haptic(.medium)
                item.action()
            } else {
                haptic(.light)
            }
        } label: {
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Accent gradient overlay
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                item.accentColor.opacity(item.isLocked ? 0.15 : 0.25),
                                item.accentColor.opacity(item.isLocked ? 0.05 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Christmas lights (winter theme only)
                if WinterTheme.isActive {
                    ChristmasLights()
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                
                // Soft glow
                Circle()
                    .fill(item.accentColor.opacity(item.isLocked ? 0.15 : 0.3))
                    .frame(width: 120, height: 120)
                    .blur(radius: 50)
                    .offset(x: -40, y: -50)
                
                // Content
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(item.accentColor.opacity(0.2))
                                .frame(width: 56, height: 56)
                            
                            Circle()
                                .stroke(item.accentColor.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: item.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [item.accentColor, item.accentColor.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .opacity(item.isLocked ? 0.5 : 1)
                        
                        Spacer()
                        
                        // Badge
                        if let badge = item.badgeText {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(
                                            item.isLocked ?
                                            LinearGradient(
                                                colors: [Color.gray, Color.gray.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ) :
                                            LinearGradient(
                                                colors: [item.accentColor, item.accentColor.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: (item.isLocked ? Color.gray : item.accentColor).opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    
                    Spacer()
                    
                    // Title
                    Text(item.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(2)
                        .opacity(item.isLocked ? 0.6 : 1)
                    
                    // Subtitle
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(2)
                            .opacity(item.isLocked ? 0.5 : 1)
                    }
                    
                    // CTA Arrow or Lock indicator
                    if item.isLocked {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Скоро")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color.gray)
                    } else {
                        HStack(spacing: 6) {
                            Text("Перейти")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(item.accentColor)
                    }
                }
                .padding(20)
                
                // Lock overlay with chain
                if item.isLocked {
                    ZStack {
                        // Dark overlay
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                        
                        // Lock icon with chain effect
                        VStack(spacing: 8) {
                            ZStack {
                                // Chain links decoration
                                HStack(spacing: 2) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.6), lineWidth: 2)
                                            .frame(width: 12, height: 8)
                                    }
                                }
                                .offset(y: -24)
                                
                                // Lock circle
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(white: 0.25), Color(white: 0.15)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
                                
                                // Lock icon
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.9), Color.white.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        }
                    }
                }
                
                // Border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(item.isLocked ? 0.2 : 0.4),
                                (item.isLocked ? Color.gray : item.accentColor).opacity(0.2),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
            .shadow(color: (item.isLocked ? Color.gray : item.accentColor).opacity(0.15), radius: 20, x: 0, y: 5)
        }
        .buttonStyle(BentoCardPressStyle())
        .allowsHitTesting(!item.isLocked)
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}

// MARK: - Compact Card (Small)

private struct BentoCompactCard: View {
    let item: BentoQuickActionItem
    
    var body: some View {
        Button {
            haptic(.light)
            item.action()
        } label: {
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Accent tint
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(item.accentColor.opacity(0.12))
                
                // Content
                HStack(spacing: 10) {
                    // Icon (smaller for more text space)
                    ZStack {
                        Circle()
                            .fill(item.accentColor.opacity(0.15))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(item.accentColor)
                    }
                    .flexibleFrame(minWidth: 38, maxWidth: 38)
                    
                    // Title - адаптивний текст
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Arrow
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))
                        .flexibleFrame(minWidth: 16, maxWidth: 16)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                
                // Border
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                item.accentColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(BentoCardPressStyle())
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}

// Helper для фіксованої ширини без впливу на layout
private extension View {
    func flexibleFrame(minWidth: CGFloat, maxWidth: CGFloat) -> some View {
        self.frame(minWidth: minWidth, maxWidth: maxWidth)
    }
}

// MARK: - Press Style

private struct BentoCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Extended Grid (for more items)

struct BentoQuickActionsExtended: View {
    let featuredItem: BentoQuickActionItem
    let primaryItems: [BentoQuickActionItem] // Top 2 on right
    let secondaryItems: [BentoQuickActionItem] // Bottom row
    
    @State private var appeared = false
    
    private let gridSpacing: CGFloat = 12
    
    var body: some View {
        VStack(spacing: gridSpacing) {
            // Top row: Featured + 2 compact
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let featuredWidth = totalWidth * 0.55
                let smallWidth = totalWidth - featuredWidth - gridSpacing
                let smallHeight = (220 - gridSpacing) / 2
                
                HStack(spacing: gridSpacing) {
                    // Featured large card
                    BentoFeaturedCard(item: featuredItem)
                        .frame(width: featuredWidth, height: 220)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0), value: appeared)
                    
                    // Small cards stack
                    VStack(spacing: gridSpacing) {
                        ForEach(Array(primaryItems.prefix(2).enumerated()), id: \.element.id) { index, item in
                            BentoCompactCard(item: item)
                                .frame(width: smallWidth, height: smallHeight)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1 + Double(index) * 0.08), value: appeared)
                        }
                    }
                }
            }
            .frame(height: 220)
            
            // Bottom row: Secondary items (scrollable, адаптивна ширина)
            if !secondaryItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: gridSpacing) {
                        ForEach(Array(secondaryItems.enumerated()), id: \.element.id) { index, item in
                            BentoCompactCard(item: item)
                                .frame(minWidth: 150, idealWidth: 170, maxWidth: 200)
                                .frame(height: 72)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 15)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25 + Double(index) * 0.05), value: appeared)
                        }
                    }
                    .padding(.horizontal, 1) // For shadow clipping
                }
            }
        }
        .onAppear {
            if !appeared {
                appeared = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Bento Quick Actions") {
    ZStack {
        Theme.Colors.primaryBackground.ignoresSafeArea()
        
        VStack(spacing: 24) {
            Text("Швидкі дії")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            BentoQuickActions(
                featuredItem: BentoQuickActionItem(
                    icon: "briefcase.fill",
                    title: "Пошук роботи",
                    subtitle: "RAV + Indeed • Фільтри",
                    accentColor: .cyan,
                    badgeText: "New"
                ) {},
                items: [
                    BentoQuickActionItem(
                        icon: "book.fill",
                        title: "Довідники",
                        accentColor: .blue
                    ) {},
                    BentoQuickActionItem(
                        icon: "checkmark.circle.fill",
                        title: "Чек-листи",
                        accentColor: .green
                    ) {}
                ]
            )
        }
        .padding()
    }
}

#Preview("Bento Extended") {
    ZStack {
        Theme.Colors.primaryBackground.ignoresSafeArea()
        
        VStack(spacing: 24) {
            Text("Швидкі дії")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            BentoQuickActionsExtended(
                featuredItem: BentoQuickActionItem(
                    icon: "briefcase.fill",
                    title: "Пошук роботи",
                    subtitle: "RAV + Indeed • Фільтри",
                    accentColor: .cyan,
                    badgeText: "New"
                ) {},
                primaryItems: [
                    BentoQuickActionItem(icon: "book.fill", title: "Довідники", accentColor: .blue) {},
                    BentoQuickActionItem(icon: "checkmark.circle.fill", title: "Чек-листи", accentColor: .green) {}
                ],
                secondaryItems: [
                    BentoQuickActionItem(icon: "function", title: "Калькулятор", accentColor: .orange) {},
                    BentoQuickActionItem(icon: "map.fill", title: "Карта", accentColor: .teal) {},
                    BentoQuickActionItem(icon: "doc.richtext", title: "CV Builder", accentColor: .purple) {},
                    BentoQuickActionItem(icon: "doc.text", title: "Шаблони", accentColor: .pink) {}
                ]
            )
        }
        .padding()
    }
}
