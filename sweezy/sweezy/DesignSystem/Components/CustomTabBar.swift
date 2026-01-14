//
//  CustomTabBar.swift
//  sweezy
//
//  Frosted glass tab bar with animated gradient indicator
//

import SwiftUI

struct TabItem: Identifiable {
    let id: String
    let icon: String
    let label: String
}

struct CustomTabBar: View {
    let tabs: [TabItem]
    @Binding var selectedTab: String
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab.id,
                    namespace: animation
                ) {
                    withAnimation(Theme.Animation.smooth) {
                        selectedTab = tab.id
                        
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
        .background(
            // Frosted glass background
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Theme.Colors.glassMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: -1)
        )
        .overlay(
            // Top border
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

private struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Icon
                Image(systemName: tab.icon)
                    .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? AnyShapeStyle(Theme.Colors.gradientPrimaryAdaptive)
                            : AnyShapeStyle(Theme.Colors.textTertiary)
                    )
                    .frame(height: 28)
                
                // Label
                Text(tab.label)
                    .font(Theme.Typography.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(
                        isSelected
                            ? Theme.Colors.textPrimary
                            : Theme.Colors.textTertiary
                    )
                
                // Animated indicator
                if isSelected {
                    Rectangle()
                        .fill(Theme.Colors.gradientPrimaryAdaptive)
                        .frame(width: 40, height: 3)
                        .cornerRadius(1.5)
                        .matchedGeometryEffect(id: "indicator", in: namespace)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview("Tab Bar Light") {
    VStack {
        Spacer()
        
        CustomTabBar(
            tabs: [
                TabItem(id: "home", icon: "house.fill", label: "Home"),
                TabItem(id: "guides", icon: "book.fill", label: "Guides"),
                TabItem(id: "map", icon: "map.fill", label: "Map"),
                TabItem(id: "calculator", icon: "function", label: "Benefits"),
                TabItem(id: "settings", icon: "gearshape.fill", label: "Settings")
            ],
            selectedTab: .constant("home")
        )
    }
    .background(Theme.Colors.surface)
}

#Preview("Tab Bar Dark") {
    VStack {
        Spacer()
        
        CustomTabBar(
            tabs: [
                TabItem(id: "home", icon: "house.fill", label: "Главная"),
                TabItem(id: "guides", icon: "book.fill", label: "Гіди"),
                TabItem(id: "map", icon: "map.fill", label: "Карта"),
                TabItem(id: "calculator", icon: "function", label: "Пільги"),
                TabItem(id: "settings", icon: "gearshape.fill", label: "Налашт.")
            ],
            selectedTab: .constant("guides")
        )
    }
    .background(Theme.Colors.darkBackground)
    .preferredColorScheme(.dark)
}

#Preview("Tab Bar Interactive") {
    struct InteractivePreview: View {
        @State private var selected = "home"
        
        var body: some View {
            ZStack {
                // Different background for each tab
                Group {
                    switch selected {
                    case "home":
                        Theme.Colors.gradientHero.ignoresSafeArea()
                    case "guides":
                        Color.blue.opacity(0.2).ignoresSafeArea()
                    case "map":
                        Color.green.opacity(0.2).ignoresSafeArea()
                    case "calculator":
                        Color.orange.opacity(0.2).ignoresSafeArea()
                    case "settings":
                        Color.purple.opacity(0.2).ignoresSafeArea()
                    default:
                        Theme.Colors.surface.ignoresSafeArea()
                    }
                }
                
                VStack {
                    Text(selected.capitalized)
                        .font(Theme.Typography.largeTitle)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    CustomTabBar(
                        tabs: [
                            TabItem(id: "home", icon: "house.fill", label: "Home"),
                            TabItem(id: "guides", icon: "book.fill", label: "Guides"),
                            TabItem(id: "map", icon: "map.fill", label: "Map"),
                            TabItem(id: "calculator", icon: "function", label: "Benefits"),
                            TabItem(id: "settings", icon: "gearshape.fill", label: "Settings")
                        ],
                        selectedTab: $selected
                    )
                }
            }
        }
    }
    
    return InteractivePreview()
}

