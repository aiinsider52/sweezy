import SwiftUI

/// Shimmering placeholder used while a list loads, so screens keep their shape instead of showing a bare spinner.
struct SkeletonBlock: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8
    var widthFraction: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(JourneyVisual.softBorder)
                .frame(width: max(0, geometry.size.width * widthFraction), height: height)
        }
        .frame(height: height)
    }
}

/// One card-shaped placeholder row: thumbnail, two text lines.
struct SkeletonRow: View {
    var showsThumbnail = true
    var height: CGFloat = 86

    var body: some View {
        HStack(spacing: 12) {
            if showsThumbnail {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(JourneyVisual.softBorder)
                    .frame(width: 64, height: 64)
            }
            VStack(alignment: .leading, spacing: 9) {
                SkeletonBlock(height: 13, widthFraction: 0.72)
                SkeletonBlock(height: 11, widthFraction: 0.45)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(height: height)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
    }
}

struct SkeletonList: View {
    var rows = 3
    var showsThumbnail = true

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<rows, id: \.self) { _ in
                SkeletonRow(showsThumbnail: showsThumbnail)
            }
        }
        .shimmering()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("common.loading".localized)
    }
}

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.55), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.45)
                        .offset(x: phase * geometry.size.width * 1.4)
                        .blendMode(.overlay)
                    }
                    .allowsHitTesting(false)
                }
                .mask(content)
                .onAppear {
                    withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

extension View {
    /// Light sweep across placeholder content; still under Reduce Motion.
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
