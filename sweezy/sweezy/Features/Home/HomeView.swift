import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    
    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""
    @State private var showWhatsNewSheet = false
    @State private var scrollOffset: CGFloat = 0
    @State private var animateGradient = false
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(key: HomeScrollOffsetKey.self, value: proxy.frame(in: .named("homeScroll")).minY)
                                }
                            )
                        
                        premiumHero
                            .padding(.bottom, Theme.Spacing.lg)
                        
                        whatsNewBanner
                            .padding(.bottom, Theme.Spacing.md)
                        
                        quickActionsGrid
                            .padding(.bottom, Theme.Spacing.xl)
                        
                        statsCards
                            .padding(.bottom, Theme.Spacing.xl)
                        
                        newsCarousel
                            .padding(.bottom, Theme.Spacing.xl)
                        
                        telegramCTA
                            .padding(.bottom, Theme.Spacing.xl)
                    }
                }
            }
            .coordinateSpace(name: "homeScroll")
            .onPreferenceChange(HomeScrollOffsetKey.self) { y in
                scrollOffset = -y
            }
            .background(
                ZStack {
                    // Winter gradient background (always festive)
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.1, blue: 0.2),
                            Color(red: 0.08, green: 0.15, blue: 0.28),
                            Color(red: 0.06, green: 0.12, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    // Subtle snowfall
                    WinterSceneLite(intensity: .light)
                }
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
    
    private var premiumHero: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: animateGradient ? 
                    [Theme.Colors.warmYellow.opacity(0.7), Theme.Colors.ukrainianBlue] :
                    [Theme.Colors.ukrainianBlue, Theme.Colors.warmYellow.opacity(0.7)],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Theme.Colors.ukrainianBlue.opacity(0.3), radius: 20, x: 0, y: 10)
            .scaleEffect(max(CGFloat(0.92), CGFloat(1.0) - min(max(scrollOffset, 0), CGFloat(150)) / CGFloat(1500)))
            .opacity(max(CGFloat(0.3), CGFloat(1.0) - min(max(scrollOffset, 0), CGFloat(150)) / CGFloat(300)))
            .offset(y: -min(max(scrollOffset, 0), CGFloat(80)) / CGFloat(10))
            
            // Floating particles effect
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: CGFloat.random(in: 20...40))
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: CGFloat.random(in: -80...80)
                    )
                    .blur(radius: 4)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.25))
                            .frame(width: 80, height: 80)
                            .blur(radius: 8)
                        Circle()
                            .fill(.white)
                            .frame(width: 70, height: 70)
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Theme.Colors.primaryGradient)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greetingText)
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        Text("home.greeting.subtitle".localized)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 200)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("home.quick_actions".localized)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                PremiumActionTile(
                    icon: "function",
                    title: "qa.calculator.title".localized,
                    subtitle: "qa.calculator.subtitle".localized,
                    colors: [Color(red: 0.2, green: 0.4, blue: 0.9), Color(red: 0.4, green: 0.6, blue: 1.0)],
                    destination: AnyView(BenefitsCalculatorView().environmentObject(appContainer))
                )
                
                PremiumActionTile(
                    icon: "map",
                    title: "map.title".localized,
                    subtitle: "map.nearby_services".localized,
                    colors: [Color(red: 0.2, green: 0.8, blue: 0.8), Color(red: 0.4, green: 0.9, blue: 0.6)],
                    destination: AnyView(MapView().environmentObject(appContainer))
                )
                
                PremiumActionTile(
                    icon: "book.pages",
                    title: "guides.title".localized,
                    subtitle: "qa.documents.subtitle".localized,
                    colors: [Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.8, green: 0.5, blue: 1.0)],
                    destination: AnyView(GuidesView().environmentObject(appContainer))
                )
                
                PremiumActionTile(
                    icon: "doc.richtext",
                    title: "templates.title".localized,
                    subtitle: "qa.templates.subtitle".localized,
                    colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.8, blue: 0.3)],
                    destination: AnyView(TemplatesView().environmentObject(appContainer))
                )
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
    
    private var statsCards: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Статистика")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            HStack(spacing: Theme.Spacing.sm) {
                PremiumStatCard(
                    icon: "book.fill",
                    title: "home.metrics.guides".localized,
                    value: "\(appContainer.userStats.guidesReadCount)",
                    color: Color(red: 0.3, green: 0.5, blue: 1.0)
                )
                PremiumStatCard(
                    icon: "checklist",
                    title: "home.metrics.lists".localized,
                    value: "\(appContainer.userStats.activeChecklistsCount)",
                    color: Color(red: 0.2, green: 0.8, blue: 0.5)
                )
                PremiumStatCard(
                    icon: "doc.text.fill",
                    title: "home.metrics.templates".localized,
                    value: "\(appContainer.contentService.templates.count)",
                    color: Color(red: 1.0, green: 0.6, blue: 0.2)
                )
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
    
    private var newsCarousel: some View {
        let items = appContainer.contentService.latestNews(limit: 6, language: appContainer.currentLocale.identifier)
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("news.latest".localized)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(items) { item in
                        PremiumNewsCard(item: item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
    
    private var telegramCTA: some View {
        Button(action: {
            if let url = URL(string: "https://t.me/sweezy_app") { UIApplication.shared.open(url) }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.6, blue: 0.9), Color(red: 0.2, green: 0.4, blue: 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)
                    .shadow(color: Color(red: 0.2, green: 0.5, blue: 0.9).opacity(0.4), radius: 16, x: 0, y: 8)
                
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 60, height: 60)
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("home.telegram_join".localized)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("home.telegram_subtitle".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, Theme.Spacing.md)
    }
    
    private var whatsNewBanner: some View {
        let currentVersion = Bundle.main.appVersion
        let shouldShow = lastSeenVersion.isEmpty || lastSeenVersion != currentVersion
        return Group {
            if shouldShow {
                Button(action: { showWhatsNewSheet = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                        
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Theme.Colors.primaryGradient).frame(width: 50, height: 50)
                                Image(systemName: "sparkles").foregroundColor(.white).font(.system(size: 20, weight: .bold))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("whats_new.title".localized)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Theme.Colors.primaryText)
                                Text("whats_new.subtitle".localized)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                        .padding(16)
                    }
                    .frame(height: 80)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, Theme.Spacing.md)
                .sheet(isPresented: $showWhatsNewSheet, onDismiss: {
                    lastSeenVersion = currentVersion
                }) {
                    WhatsNewView()
                }
            }
        }
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "home.greeting.morning".localized
        case 12..<17: return "home.greeting.afternoon".localized
        case 17..<22: return "home.greeting.evening".localized
        default: return "home.greeting.night".localized
        }
    }
}

private struct PremiumActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let colors: [Color]
    let destination: AnyView
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(destination: destination) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: colors[0].opacity(0.4), radius: isPressed ? 8 : 16, x: 0, y: isPressed ? 4 : 8)
                
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        Circle().fill(.white.opacity(0.25)).frame(width: 50, height: 50)
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
                .padding(20)
            }
            .frame(height: 180)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

private struct PremiumStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: color.opacity(0.15), radius: 12, x: 0, y: 6)
            
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(value)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(Theme.Colors.primaryText)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }
            .padding(.vertical, 16)
        }
    }
}

private struct PremiumNewsCard: View {
    let item: NewsItem
    
    var body: some View {
        Button(action: {
            if let url = URL(string: item.url) { UIApplication.shared.open(url) }
        }) {
            ZStack(alignment: .bottomLeading) {
                if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url, contentMode: .fill) {
                        Rectangle().fill(Theme.Colors.secondaryBackground)
                    }
                    .frame(width: 280, height: 200)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(colors: [Theme.Colors.ukrainianBlue.opacity(0.6), Theme.Colors.warmYellow.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 280, height: 200)
                }
                
                LinearGradient(colors: [Color.clear, Color.black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(item.source)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        Text("•").foregroundColor(.white.opacity(0.6))
                        Text(RelativeDateTimeFormatter().localizedString(for: item.publishedAt, relativeTo: Date()))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(16)
            }
            .frame(width: 280, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct HomeScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    HomeView()
        .environmentObject(AppContainer())
        .environmentObject(AppLockManager())
}
