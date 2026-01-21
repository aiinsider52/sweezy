import SwiftUI

// MARK: - Lightweight Aurora Background
struct AuroraBackground: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base dark gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.06, blue: 0.1),
                        Color(red: 0.03, green: 0.1, blue: 0.15),
                        Color(red: 0.04, green: 0.12, blue: 0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Aurora wave 1 - Teal
                AuroraWave(
                    color: Color(red: 0.1, green: 0.8, blue: 0.7),
                    phase: phase,
                    amplitude: 30,
                    yOffset: geo.size.height * 0.3
                )
                .opacity(0.4)
                
                // Aurora wave 2 - Green
                AuroraWave(
                    color: Color(red: 0.2, green: 0.9, blue: 0.5),
                    phase: phase + 0.5,
                    amplitude: 25,
                    yOffset: geo.size.height * 0.35
                )
                .opacity(0.3)
                
                // Aurora wave 3 - Purple accent
                AuroraWave(
                    color: Color(red: 0.5, green: 0.3, blue: 0.9),
                    phase: phase + 1.0,
                    amplitude: 20,
                    yOffset: geo.size.height * 0.25
                )
                .opacity(0.2)
                
                // Subtle stars
                AuroraStars()
                    .opacity(0.6)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// Single aurora wave - very lightweight
struct AuroraWave: View {
    let color: Color
    let phase: CGFloat
    let amplitude: CGFloat
    let yOffset: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: yOffset))
                
                for x in stride(from: 0, through: geo.size.width, by: 4) {
                    let relativeX = x / geo.size.width
                    let sine = sin(relativeX * .pi * 2 + phase)
                    let y = yOffset + sine * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.8), color.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blur(radius: 20)
        }
    }
}

// Lightweight stars (static) - for Aurora Hero
private struct AuroraStars: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: CGFloat.random(in: 1...2), height: CGFloat.random(in: 1...2))
                    .position(
                        x: CGFloat(((i * 47) % 100)) / 100 * geo.size.width,
                        y: CGFloat(((i * 31) % 100)) / 100 * geo.size.height * 0.6
                    )
            }
        }
    }
}

// MARK: - Full Bleed Aurora Hero
struct FullBleedAuroraHero: View {
    let greeting: String
    let userName: String
    let xp: Int
    let level: Int
    let streak: Int
    let integrationPercent: Int
    /// Top safe-area inset (status bar / dynamic island). Used to keep content below the notch while allowing full-bleed background.
    let topInset: CGFloat
    let onAvatarTap: () -> Void
    let onProgressTap: () -> Void
    
    @State private var glowPulse = false
    
    private var accentColor: Color {
        Color(red: 0.2, green: 0.9, blue: 0.7)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Winter Night Background (conditional based on season)
            if WinterTheme.isActive {
                // Full winter scene with trees, snow, gifts, santa
                WinterSceneBackground()
            } else {
                // Regular Aurora background
                AuroraBackground()
            }
            
            // Content
            VStack(spacing: 0) {
                // Top spacing (avatar удалён по запросу)
                HStack {
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8 + topInset)
                
                // Main greeting
                VStack(alignment: .leading, spacing: 12) {
                    Text(greeting)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: accentColor.opacity(0.6), radius: 30, x: 0, y: 0)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: accentColor, radius: 4, x: 0, y: 0)
                        
                        Text("Привіт, \(userName)!")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Stats row
                HStack(spacing: 12) {
                    AuroraStatPill(icon: "flame.fill", value: "\(streak)", label: "днів", color: Color.orange)
                    AuroraStatPill(icon: "star.fill", value: "\(xp)", label: "XP", color: Color.yellow)
                    AuroraStatPill(icon: "trophy.fill", value: "Рів. \(level)", label: "", color: accentColor)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer(minLength: 16)
                
                // Progress card
                Button(action: onProgressTap) {
                    HStack(spacing: 14) {
                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 4)
                                .frame(width: 52, height: 52)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(integrationPercent) / 100)
                                .stroke(
                                    LinearGradient(
                                        colors: [accentColor, Color(red: 0.3, green: 0.95, blue: 0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 52, height: 52)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(integrationPercent)%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Прогрес інтеграції")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(progressMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial.opacity(0.3))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(height: 340 + topInset)
        .clipShape(
            RoundedCornerShape(corners: [.bottomLeft, .bottomRight], radius: 32)
        )
    }
    
    private var progressMessage: String {
        switch integrationPercent {
        case 0..<25: return "Починайте — все вийде! 💪"
        case 25..<50: return "Гарний старт! 🔥"
        case 50..<75: return "Половина шляху! ⚡️"
        case 75..<100: return "Майже готово! 🎯"
        default: return "Вітаємо! 🏆"
        }
    }
}

// Stat pill component for Aurora Hero
private struct AuroraStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// Helper shape for bottom rounded corners
struct RoundedCornerShape: Shape {
    let corners: UIRectCorner
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Legacy HeroSplitView (keeping for compatibility)
struct HeroSplitView<Right: View, Bottom: View>: View {
    let title: String
    let subtitle: String
    let ctaTitle: String?
    let onTap: (() -> Void)?
    let rightContent: Right
    let bottomContent: Bottom
    let height: CGFloat
    let buttonStyle: PrimaryButton.ButtonStyle
    let useTypewriter: Bool
    
    @State private var shimmerOffset: CGFloat = -1
    @State private var glowPulse: Bool = false
    
    init(
        title: String,
        subtitle: String,
        ctaTitle: String? = nil,
        height: CGFloat = 240,
        @ViewBuilder right: () -> Right,
        @ViewBuilder bottom: () -> Bottom = { EmptyView() },
        onTap: (() -> Void)? = nil,
        buttonStyle: PrimaryButton.ButtonStyle = .coral,
        useTypewriter: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.ctaTitle = ctaTitle
        self.onTap = onTap
        self.rightContent = right()
        self.bottomContent = bottom()
        self.height = height
        self.buttonStyle = buttonStyle
        self.useTypewriter = useTypewriter
    }
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.05, green: 0.15, blue: 0.18), location: 0),
                    .init(color: Color(red: 0.08, green: 0.25, blue: 0.28), location: 0.5),
                    .init(color: Color(red: 0.1, green: 0.35, blue: 0.35), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            
            // Content
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Group {
                            if useTypewriter {
                                TypewriterText(text: title, font: .system(size: 32, weight: .bold, design: .rounded), color: .white)
                            } else {
                                Text(title)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        
                        Text(subtitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        if let ctaTitle = ctaTitle, let onTap = onTap {
                            Button(action: onTap) {
                                Text(ctaTitle)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(red: 0.05, green: 0.15, blue: 0.18))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(Color(red: 0.2, green: 0.95, blue: 0.7)))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    rightContent
                        .frame(width: 68, height: 68)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer(minLength: 12)
                
                bottomContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    HeroSplitView(
        title: "Welcome to Switzerland",
        subtitle: "We help you navigate your new life",
        ctaTitle: "Get started",
        right: {
            VStack {
                PixelBadgeIcon("sparkles", tint: .white)
            }
        },
        onTap: {},
        buttonStyle: .primary
    )
    .padding()
}
