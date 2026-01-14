import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0...1
    let lineWidth: CGFloat
    let gradient: LinearGradient?
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    gradient ?? LinearGradient(colors: [Theme.Colors.accentTurquoise, Theme.Colors.primary],
                                   startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
    }
}

struct IntegrationProgressCard: View {
    let title: LocalizedStringKey
    let done: Int
    let total: Int
    let onTap: () -> Void
    var inHero: Bool = false
    
    @State private var isPressed = false
    @State private var ringPulse = false
    
    private var percent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(done) / Double(total)) * 100.0 + 0.5)
    }
    
    private var accentColor: Color {
        Color(red: 0.2, green: 0.9, blue: 0.7)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Left: Animated progress ring with icon
                ZStack {
                    // Background glow
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .scaleEffect(ringPulse ? 1.1 : 1.0)
                    
                    // Track
                    Circle()
                        .stroke(
                            inHero ? Color.white.opacity(0.15) : Color.gray.opacity(0.2),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                    
                    // Progress arc
                    Circle()
                        .trim(from: 0, to: CGFloat(done) / CGFloat(max(1, total)))
                        .stroke(
                            LinearGradient(
                                colors: inHero
                                    ? [.white, accentColor]
                                    : [accentColor, Color(red: 0.3, green: 0.85, blue: 0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: accentColor.opacity(0.5), radius: 4, x: 0, y: 0)
                    
                    // Center icon
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: inHero ? [.white, .white.opacity(0.8)] : [accentColor, Color(red: 0.95, green: 0.7, blue: 0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Center: Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(inHero ? .white : Theme.Colors.primaryText)
                        .lineLimit(1)
                    
                    Text(subtitleText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(inHero ? .white.opacity(0.75) : Theme.Colors.secondaryText)
                        .lineLimit(1)
                    
                    // Mini progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(inHero ? Color.white.opacity(0.15) : Color.gray.opacity(0.15))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor, Color(red: 0.95, green: 0.75, blue: 0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(done) / CGFloat(max(1, total)), height: 4)
                                .shadow(color: accentColor.opacity(0.5), radius: 2, x: 0, y: 0)
                        }
                    }
                    .frame(height: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right: Percent badge with glow
                ZStack {
                    // Glow background
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentColor.opacity(inHero ? 0.2 : 0.15))
                        .frame(width: 52, height: 36)
                    
                    Text("\(percent)%")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(inHero ? .white : accentColor)
                }
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(inHero ? .white.opacity(0.5) : Theme.Colors.secondaryText.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                ZStack {
                    if inHero {
                        // Glassmorphism for hero
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        
                        // Inner highlight
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    } else {
                        // Card background for standalone
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: inHero
                                ? [Color.white.opacity(0.3), Color.white.opacity(0.1)]
                                : [accentColor.opacity(0.3), Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                ringPulse = true
            }
        }
    }
    
    private var subtitleText: String {
        switch percent {
        case 0..<25: return "Починайте — все вийде! 💪"
        case 25..<60: return "Гарний прогрес! 🔥"
        case 60..<90: return "Майже готово! ⚡️"
        default: return "Фінішна пряма! 🏆"
        }
    }
}


