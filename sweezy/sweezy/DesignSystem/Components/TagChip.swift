//
//  TagChip.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import SwiftUI

/// Pill-shaped tag chip for filters and categories
struct TagChip: View {
    let title: String
    let isSelected: Bool
    let style: ChipStyle
    let action: (() -> Void)?
    
    enum ChipStyle {
        case filter
        case category
        case status
    }
    
    init(
        _ title: String,
        isSelected: Bool = false,
        style: ChipStyle = .filter,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.isSelected = isSelected
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action?()
        }) {
            Text(title)
                .font(Theme.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(textColor)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
        }
        .disabled(action == nil)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(Theme.Animation.quick, value: isSelected)
    }
    
    private var backgroundColor: Color {
        switch (style, isSelected) {
        case (.filter, true):
            return Theme.Colors.ukrainianBlue
        case (.filter, false):
            return Theme.Colors.tertiaryBackground
        case (.category, _):
            return Theme.Colors.warmYellow.opacity(0.2)
        case (.status, _):
            return Theme.Colors.success.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch (style, isSelected) {
        case (.filter, true):
            return .white
        case (.filter, false):
            return Theme.Colors.primaryText
        case (.category, _):
            return Theme.Colors.ukrainianBlue
        case (.status, _):
            return Theme.Colors.success
        }
    }
    
    private var borderColor: Color {
        switch (style, isSelected) {
        case (.filter, true):
            return Theme.Colors.ukrainianBlue
        case (.filter, false):
            return Theme.Colors.swissGray.opacity(0.3)
        case (.category, _):
            return Theme.Colors.warmYellow
        case (.status, _):
            return Theme.Colors.success
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .filter:
            return isSelected ? 0 : 1
        case .category, .status:
            return 1
        }
    }
}

/// Horizontal scrollable chip collection
struct ChipCollection: View {
    let chips: [String]
    @Binding var selectedChip: String?
    let style: TagChip.ChipStyle
    
    init(
        chips: [String],
        selectedChip: Binding<String?>,
        style: TagChip.ChipStyle = .filter
    ) {
        self.chips = chips
        self._selectedChip = selectedChip
        self.style = style
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(chips, id: \.self) { chip in
                    TagChip(
                        chip,
                        isSelected: selectedChip == chip,
                        style: style
                    ) {
                        if selectedChip == chip {
                            selectedChip = nil
                        } else {
                            selectedChip = chip
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        // Filter chips
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Filter Chips")
                .font(Theme.Typography.headline)
            
            HStack(spacing: Theme.Spacing.sm) {
                TagChip("All", isSelected: true) { }
                TagChip("Housing") { }
                TagChip("Insurance") { }
                TagChip("Work") { }
            }
        }
        
        // Category chips
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Category Chips")
                .font(Theme.Typography.headline)
            
            HStack(spacing: Theme.Spacing.sm) {
                TagChip("Documents", style: .category)
                TagChip("Healthcare", style: .category)
                TagChip("Education", style: .category)
            }
        }
        
        // Status chips
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Status Chips")
                .font(Theme.Typography.headline)
            
            HStack(spacing: Theme.Spacing.sm) {
                TagChip("Completed", style: .status)
                TagChip("In Progress", style: .status)
                TagChip("Pending", style: .status)
            }
        }
        
        Spacer()
    }
    .padding()
}
