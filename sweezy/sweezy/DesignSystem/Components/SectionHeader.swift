//
//  SectionHeader.swift
//  sweezy
//
//  Bold section header with gradient accent underline — GoIT-inspired
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let showAccentLine: Bool
    let alignment: HorizontalAlignment
    
    init(
        _ title: String,
        subtitle: String? = nil,
        showAccentLine: Bool = true,
        alignment: HorizontalAlignment = .leading
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showAccentLine = showAccentLine
        self.alignment = alignment
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: Theme.Spacing.xs) {
            // Title with optional accent line
            VStack(alignment: alignment, spacing: 6) {
                Text(title)
                    .font(Theme.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                if showAccentLine {
                    // Gradient accent underline (GoIT style)
                    Rectangle()
                        .fill(Theme.Colors.gradientPrimaryAdaptive)
                        .frame(width: 40, height: 3)
                        .cornerRadius(1.5)
                }
            }
            
            // Optional subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
    }
}

// MARK: - Compact variant

struct CompactSectionHeader: View {
    let title: String
    let action: (() -> Void)?
    let actionTitle: String
    
    init(
        _ title: String,
        actionTitle: String = "See All",
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(Theme.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            if let action = action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(Theme.Typography.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.gradientPrimaryAdaptive)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }
}

// MARK: - Preview

#Preview("Section Headers") {
    ZStack {
        Theme.Colors.surface.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Full header with accent
                VStack {
                    SectionHeader(
                        "Featured Guides",
                        subtitle: "Essential information for newcomers"
                    )
                    Rectangle().fill(.gray.opacity(0.3)).frame(height: 100)
                }
                
                // Header without subtitle
                VStack {
                    SectionHeader("Checklists")
                    Rectangle().fill(.gray.opacity(0.3)).frame(height: 100)
                }
                
                // Centered header
                VStack {
                    SectionHeader(
                        "Welcome to Switzerland",
                        subtitle: "Your journey starts here",
                        alignment: .center
                    )
                    Rectangle().fill(.gray.opacity(0.3)).frame(height: 100)
                }
                
                // Compact header with action
                VStack {
                    CompactSectionHeader("Latest News") {
                        print("See all")
                    }
                    Rectangle().fill(.gray.opacity(0.3)).frame(height: 100)
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }
}

#Preview("Dark Mode") {
    ZStack {
        Theme.Colors.darkBackground.ignoresSafeArea()
        
        VStack(spacing: Theme.Spacing.xxl) {
            SectionHeader(
                "My Templates",
                subtitle: "Ready-to-use document templates"
            )
            
            CompactSectionHeader("Quick Actions") {
                print("See all")
            }
        }
        .padding(Theme.Spacing.lg)
    }
    .preferredColorScheme(.dark)
}

