//
//  InkPageScaffold.swift
//  sweezy
//
//  Reusable page scaffold for the ink+paper design language:
//  a fixed deep-pine header on top and a rounded paper sheet
//  that overlaps it and hosts the page content.
//

import SwiftUI

struct InkPageScaffold<Header: View, Content: View>: View {
    var sheetCornerRadius: CGFloat = 28
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Theme.Colors.ink
                Theme.Colors.paper
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
                    .padding(.bottom, Theme.Spacing.md + sheetCornerRadius)
                    .background(Theme.Colors.ink)

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: sheetCornerRadius,
                            topTrailingRadius: sheetCornerRadius,
                            style: .continuous
                        )
                        .fill(Theme.Colors.paper)
                        .ignoresSafeArea(edges: .bottom)
                    )
                    .padding(.top, -sheetCornerRadius)
            }
        }
    }
}

/// Standard large rounded white title row for ink headers.
struct InkHeaderTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white.opacity(0.68))
            }
        }
    }
}

/// Dark translucent search field styled for ink headers.
struct InkSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            TextField("", text: $text, prompt: Text(prompt).foregroundColor(.white.opacity(0.88)))
                .font(.system(size: 15))
                .foregroundColor(.white)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .accessibilityLabel("common.cancel".localized)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .fill(Theme.Colors.inkElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .stroke(Theme.Colors.inkBorder, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

#Preview {
    InkPageScaffold {
        VStack(alignment: .leading, spacing: 12) {
            InkHeaderTitle(title: "Довідник", subtitle: "Гайди та чеклісти")
            PillSegmentedControl(items: ["Гайди", "Чеклісти"], selection: .constant(0))
        }
    } content: {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { i in
                    Text("Card \(i)")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .paperCard()
                }
            }
            .padding(16)
        }
    }
}
