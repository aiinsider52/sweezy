//
//  WinterTheme.swift
//  sweezy
//
//  Winter/New Year theme components (Dec 15 - Jan 10)
//  Optimized for performance and stability
//

import SwiftUI

// MARK: - Winter Theme Toggle

struct WinterTheme {
    static var isActive: Bool {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        
        // Active from Dec 15 to Jan 10
        if month == 12 && day >= 15 { return true }
        if month == 1 && day <= 10 { return true }
        return UserDefaults.standard.bool(forKey: "force_winter_theme")
    }

    /// Returns true only for days after New Year (Jan 1-10).
    /// In December (before New Year) this will be false.
    static var isPostNewYear: Bool {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        return month == 1 && day <= 10
    }
    
    static func forceEnable(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "force_winter_theme")
    }
}

// MARK: - Snowflake Particle (Lightweight)

struct Snowflake: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double
    var drift: CGFloat // Horizontal drift
}

// MARK: - Snowfall View (Optimized)

struct SnowfallView: View {
    let particleCount: Int
    let speed: Double
    
    @State private var snowflakes: [Snowflake] = []
    @State private var timer: Timer?
    
    init(particleCount: Int = 25, speed: Double = 1.0) {
        self.particleCount = particleCount
        self.speed = speed
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(snowflakes) { flake in
                    Circle()
                        .fill(Color.white.opacity(flake.opacity))
                        .frame(width: flake.size, height: flake.size)
                        .position(x: flake.x, y: flake.y)
                        .blur(radius: flake.size > 4 ? 1 : 0)
                }
            }
            .onAppear {
                initializeSnowflakes(in: geometry.size)
                startAnimation(in: geometry.size)
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
        .allowsHitTesting(false)
    }
    
    private func initializeSnowflakes(in size: CGSize) {
        snowflakes = (0..<particleCount).map { _ in
            Snowflake(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -100...size.height),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.3...0.8),
                speed: Double.random(in: 0.5...1.5) * speed,
                drift: CGFloat.random(in: -0.5...0.5)
            )
        }
    }
    
    private func startAnimation(in size: CGSize) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateSnowflakes(in: size)
        }
    }
    
    private func updateSnowflakes(in size: CGSize) {
        for i in 0..<snowflakes.count {
            snowflakes[i].y += CGFloat(snowflakes[i].speed)
            snowflakes[i].x += snowflakes[i].drift
            
            // Reset if off screen
            if snowflakes[i].y > size.height + 20 {
                snowflakes[i].y = -20
                snowflakes[i].x = CGFloat.random(in: 0...size.width)
            }
            
            // Keep within horizontal bounds
            if snowflakes[i].x < -20 || snowflakes[i].x > size.width + 20 {
                snowflakes[i].x = CGFloat.random(in: 0...size.width)
            }
        }
    }
}

// MARK: - Winter Moon

struct WinterMoon: View {
    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
            
            // Moon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 1.0, blue: 0.95),
                            Color(red: 0.95, green: 0.95, blue: 0.9)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: Color.white.opacity(0.5), radius: 10)
        }
    }
}

// MARK: - Winter Trees Silhouette

struct WinterTrees: View {
    /// Silhouette of trees along the bottom edge of a hero section.
    /// Designed to be placed with `.frame(height: ...)` and alignment `.bottom`.
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            HStack(alignment: .bottom, spacing: width / 10) {
                ForEach(0..<7, id: \.self) { _ in
                    let treeHeight = height * CGFloat.random(in: 0.6...1.0)
                    TreeShape(height: treeHeight)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.45),
                                    Color.black.opacity(0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: width / 12, height: treeHeight, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct TreeShape: Shape {
    let height: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let topHeight = height * 0.7
        
        // Triangle (tree top)
        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: topHeight))
        path.addLine(to: CGPoint(x: width, y: topHeight))
        path.closeSubpath()
        
        // Trunk
        let trunkWidth = width * 0.2
        path.move(to: CGPoint(x: (width - trunkWidth) / 2, y: topHeight))
        path.addLine(to: CGPoint(x: (width + trunkWidth) / 2, y: topHeight))
        path.addLine(to: CGPoint(x: (width + trunkWidth) / 2, y: height))
        path.addLine(to: CGPoint(x: (width - trunkWidth) / 2, y: height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Snow Ground (white wavy ground at bottom)

struct SnowGround: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            ZStack(alignment: .bottom) {
                // Snow hills
                SnowHillsShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color(red: 0.9, green: 0.95, blue: 1.0).opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: height)
                
                // Sparkle effect on snow
                HStack(spacing: width / 8) {
                    ForEach(0..<6, id: \.self) { _ in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 3, height: 3)
                            .blur(radius: 1)
                            .opacity(Double.random(in: 0.5...1.0))
                    }
                }
                .padding(.bottom, height * 0.3)
            }
        }
    }
}

struct SnowHillsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: height * 0.4))
        
        // Wavy snow hills
        path.addCurve(
            to: CGPoint(x: width * 0.25, y: height * 0.3),
            control1: CGPoint(x: width * 0.1, y: height * 0.45),
            control2: CGPoint(x: width * 0.15, y: height * 0.25)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.35),
            control1: CGPoint(x: width * 0.35, y: height * 0.35),
            control2: CGPoint(x: width * 0.4, y: height * 0.4)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.75, y: height * 0.25),
            control1: CGPoint(x: width * 0.6, y: height * 0.3),
            control2: CGPoint(x: width * 0.65, y: height * 0.2)
        )
        path.addCurve(
            to: CGPoint(x: width, y: height * 0.4),
            control1: CGPoint(x: width * 0.85, y: height * 0.3),
            control2: CGPoint(x: width * 0.95, y: height * 0.45)
        )
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Gift Boxes under trees

struct GiftBoxes: View {
    var body: some View {
        HStack(spacing: 30) {
            GiftBox(color: .red, ribbonColor: .yellow, size: 18)
            GiftBox(color: .blue, ribbonColor: .white, size: 14)
            GiftBox(color: .green, ribbonColor: .red, size: 16)
            GiftBox(color: .purple, ribbonColor: .yellow, size: 12)
            GiftBox(color: .orange, ribbonColor: .white, size: 15)
        }
    }
}

struct GiftBox: View {
    let color: Color
    let ribbonColor: Color
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Box
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: size, height: size * 0.8)
            
            // Ribbon vertical
            Rectangle()
                .fill(ribbonColor)
                .frame(width: size * 0.15, height: size * 0.8)
            
            // Ribbon horizontal
            Rectangle()
                .fill(ribbonColor)
                .frame(width: size, height: size * 0.12)
            
            // Bow
            Circle()
                .fill(ribbonColor)
                .frame(width: size * 0.25, height: size * 0.25)
                .offset(y: -size * 0.45)
        }
        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 1, y: 1)
    }
}

// MARK: - Santa Sleigh (animated flying across top)

struct SantaSleigh: View {
    @State private var xOffset: CGFloat = -100
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            
            ZStack {
                // Sleigh + Santa emoji representation
                HStack(spacing: 2) {
                    Text("🦌")
                        .font(.system(size: 20))
                    Text("🛷")
                        .font(.system(size: 22))
                    Text("🎅")
                        .font(.system(size: 20))
                }
                .offset(x: xOffset, y: 10)
                .onAppear {
                    // Slow flight animation
                    withAnimation(
                        .linear(duration: 15)
                        .repeatForever(autoreverses: false)
                    ) {
                        xOffset = width + 100
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Complete Winter Scene (for Hero)

struct WinterSceneBackground: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            ZStack {
                // Night sky gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.2),
                        Color(red: 0.1, green: 0.15, blue: 0.3),
                        Color(red: 0.15, green: 0.2, blue: 0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Northern lights (subtle aurora)
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.12),
                        Color.green.opacity(0.08),
                        Color.purple.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 50)
                .ignoresSafeArea()
                
                // Moon
                WinterMoon()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: -20, y: 30)
                
                // Snowfall
                SnowfallView(particleCount: 25, speed: 0.7)
                    .ignoresSafeArea()
                
                // Snow ground at bottom
                SnowGround()
                    .frame(height: height * 0.25)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                
                // Trees on top of snow
                WinterTrees()
                    .frame(height: height * 0.35)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: -height * 0.08)
                
                // Gift boxes
                GiftBoxes()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, height * 0.05)
            }
        }
    }
}

// MARK: - Lighter Winter Scene (for other pages)

struct WinterSceneLite: View {
    let intensity: WinterSceneLiteIntensity
    
    enum WinterSceneLiteIntensity {
        case minimal   // Just snowflakes
        case light     // Snowflakes + subtle tint
        case medium    // Snowflakes + tint + bottom snow hint
    }
    
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            
            ZStack {
                switch intensity {
                case .minimal:
                    SnowfallView(particleCount: 12, speed: 0.5)
                        .ignoresSafeArea()
                    
                case .light:
                    // Subtle winter tint
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.03),
                            Color.clear,
                            Color.blue.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    SnowfallView(particleCount: 15, speed: 0.5)
                        .ignoresSafeArea()
                    
                case .medium:
                    // Winter tint
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.04),
                            Color.clear,
                            Color.blue.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    SnowfallView(particleCount: 18, speed: 0.6)
                        .ignoresSafeArea()
                    
                    // Subtle snow hint at very bottom
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: height * 0.1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Frost Frame Modifier

struct FrostFrame: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.7, green: 0.9, blue: 1.0).opacity(0.6),
                                Color(red: 0.8, green: 0.95, blue: 1.0).opacity(0.3),
                                Color.white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
                    .shadow(color: Color.cyan.opacity(0.3), radius: 4, x: 0, y: 0)
            )
    }
}

extension View {
    func frostFrame(cornerRadius: CGFloat = 16, lineWidth: CGFloat = 2) -> some View {
        modifier(FrostFrame(cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
    
    // Conditional modifier helper
    @ViewBuilder
    func apply<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }
    
    // Universal winter theme background wrapper
    func winterThemedBackground(intensity: WinterBackgroundIntensity = .subtle) -> some View {
        modifier(WinterThemedBackground(intensity: intensity))
    }
}

// MARK: - Winter Background Intensity

enum WinterBackgroundIntensity {
    case none      // No winter effects
    case subtle    // Just a few snowflakes
    case medium    // Snowflakes + subtle gradient
    case full      // Full winter night (for hero sections)
}

// MARK: - Universal Winter Background Modifier

struct WinterThemedBackground: ViewModifier {
    let intensity: WinterBackgroundIntensity
    
    func body(content: Content) -> some View {
        ZStack {
            // Base content
            content
            
            // Winter overlay (only if active)
            if WinterTheme.isActive {
                winterOverlay
                    .allowsHitTesting(false)
            }
        }
    }
    
    @ViewBuilder
    private var winterOverlay: some View {
        switch intensity {
        case .none:
            EmptyView()
            
        case .subtle:
            // Just a few snowflakes
            SnowfallView(particleCount: 15, speed: 0.6)
                .ignoresSafeArea()
            
        case .medium:
            // Snowflakes + light tint
            ZStack {
                // Subtle winter tint
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.02),
                        Color.clear,
                        Color.blue.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // More snowflakes
                SnowfallView(particleCount: 20, speed: 0.7)
                    .ignoresSafeArea()
            }
            
        case .full:
            // Full winter night (for special screens)
            ZStack {
                // Night gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.25).opacity(0.3),
                        Color(red: 0.1, green: 0.15, blue: 0.35).opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Northern lights hint
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.08),
                        Color.green.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 40)
                .ignoresSafeArea()
                
                // Snowfall
                SnowfallView(particleCount: 25, speed: 0.8)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Corner Snowflakes

struct CornerSnowflakes: View {
    var body: some View {
        ZStack {
            // Top-left
            Text("❄️")
                .font(.system(size: 16))
                .opacity(0.6)
                .offset(x: -8, y: -8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Top-right
            Text("❄️")
                .font(.system(size: 14))
                .opacity(0.5)
                .offset(x: 8, y: -8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            
            // Bottom-right
            Text("✨")
                .font(.system(size: 12))
                .opacity(0.7)
                .offset(x: 8, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Christmas Lights Border

struct ChristmasLights: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let spacing: CGFloat = 30
            
            ZStack {
                // Top lights
                ForEach(0..<Int(width / spacing), id: \.self) { index in
                    Circle()
                        .fill(lightColor(for: index))
                        .frame(width: 6, height: 6)
                        .opacity(pulseOpacity(for: index))
                        .position(x: CGFloat(index) * spacing + spacing / 2, y: 4)
                }
                
                // Bottom lights
                ForEach(0..<Int(width / spacing), id: \.self) { index in
                    Circle()
                        .fill(lightColor(for: index + 1))
                        .frame(width: 6, height: 6)
                        .opacity(pulseOpacity(for: index + 1))
                        .position(x: CGFloat(index) * spacing + spacing / 2, y: height - 4)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .allowsHitTesting(false)
    }
    
    private func lightColor(for index: Int) -> Color {
        let colors: [Color] = [.red, .yellow, .green, .blue, .purple]
        return colors[index % colors.count]
    }
    
    private func pulseOpacity(for index: Int) -> Double {
        let offset = Double(index % 3) * 0.33
        let value = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.4 + (sin(value * .pi * 2) * 0.4)
    }
}

// MARK: - Snow Glow Modifier (for Tab Bar)

struct SnowGlow: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? Color.cyan.opacity(0.6) : Color.clear,
                radius: isActive ? 8 : 0,
                x: 0,
                y: 0
            )
            .shadow(
                color: isActive ? Color.white.opacity(0.4) : Color.clear,
                radius: isActive ? 4 : 0,
                x: 0,
                y: 0
            )
    }
}

extension View {
    func snowGlow(isActive: Bool = false) -> some View {
        modifier(SnowGlow(isActive: isActive))
    }
}

// MARK: - Snowflake Checkmark (for Checklists)

struct SnowflakeCheckmark: View {
    var body: some View {
        ZStack {
            // Glow background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .frame(width: 24, height: 24)
            
            // Snowflake emoji
            Text("❄️")
                .font(.system(size: 18))
        }
    }
}

// MARK: - Winter Progress Bar

struct WinterProgressBar: View {
    let progress: Double
    let height: CGFloat
    
    init(progress: Double, height: CGFloat = 8) {
        self.progress = progress
        self.height = height
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(.systemGray6))
                
                // Progress fill with winter gradient
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.6, green: 0.85, blue: 1.0),
                                Color(red: 0.4, green: 0.7, blue: 0.95),
                                Color(red: 0.7, green: 0.9, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)))
                    .shadow(color: Color.cyan.opacity(0.4), radius: 4, x: 0, y: 0)
                
                // Snowflake at progress end
                if progress > 0.05 {
                    Text("❄️")
                        .font(.system(size: height * 1.5))
                        .offset(x: geometry.size.width * CGFloat(min(max(progress, 0), 1)) - height)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Winter Badge

struct WinterBadge: Identifiable {
    let id: String
    let title: String
    let icon: String
    let description: String
    let earnedDate: Date?
    
    static let winterPioneer = WinterBadge(
        id: "winter_pioneer",
        title: "Зимовий першопрохідець",
        icon: "❄️",
        description: "Перший запуск додатку взимку",
        earnedDate: nil
    )
    
    static let festiveOrganizer = WinterBadge(
        id: "festive_organizer",
        title: "Святковий організатор",
        icon: "🎄",
        description: "Завершено 5 чек-листів у грудні",
        earnedDate: nil
    )
    
    static let newYearHero = WinterBadge(
        id: "new_year_hero",
        title: "Новорічний герой",
        icon: "🎅",
        description: "Прочитано 10 гідів у святковий період",
        earnedDate: nil
    )
    
    static func allWinterBadges() -> [WinterBadge] {
        [winterPioneer, festiveOrganizer, newYearHero]
    }
}

// MARK: - Winter Greeting Screen

struct WinterGreetingScreen: View {
    let onContinue: () -> Void
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Winter night background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.25),
                    Color(red: 0.1, green: 0.15, blue: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Snowfall
            SnowfallView(particleCount: 30, speed: 0.6)
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 32) {
                Spacer()
                
                // Animated emoji - gentle pulse instead of rotation
                Text("🎄")
                    .font(.system(size: 100))
                    .scaleEffect(scale)
                    .shadow(color: Color.cyan.opacity(0.5), radius: 30, x: 0, y: 0)
                
                // Greeting
                VStack(spacing: 12) {
                    Text(WinterTheme.isPostNewYear ? "З Новим Роком!" : "Святкова зима разом із Sweezy")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Ласкаво просимо до Sweezy")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text("Ваш особистий гід для успішного життя в Швейцарії")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(opacity)
                
                Spacer()
                
                // Continue button
                Button(action: onContinue) {
                    HStack(spacing: 12) {
                        Text("Почати подорож")
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.7, blue: 0.9),
                                Color(red: 0.3, green: 0.6, blue: 0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.cyan.opacity(0.5), radius: 20, x: 0, y: 10)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            // Gentle pulse animation instead of rotation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                scale = 1.05
            }
        }
    }
}

// MARK: - Winter Badge Card View

struct WinterBadgeCard: View {
    let badge: WinterBadge
    let isEarned: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        isEarned
                        ? LinearGradient(
                            colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text(badge.icon)
                    .font(.system(size: 28))
                    .grayscale(isEarned ? 0 : 1)
                    .opacity(isEarned ? 1 : 0.4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(badge.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isEarned ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                
                Text(badge.description)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textTertiary)
                    .lineLimit(2)
                
                if isEarned, let date = badge.earnedDate {
                    Text("Отримано \(date, formatter: dateFormatter)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Theme.Colors.card)
        .cornerRadius(12)
        .frostFrame(cornerRadius: 12, lineWidth: isEarned ? 1.5 : 0)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
}

