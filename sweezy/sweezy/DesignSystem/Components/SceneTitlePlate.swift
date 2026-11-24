import SwiftUI

/// Frosted caption that carries a screen title over city artwork. The art stays visible
/// around it, and the text no longer depends on a glow or a paper wash for contrast.
struct SceneTitlePlate<Content: View>: View {
    var maxWidth: CGFloat = 260
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 14)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(JourneyVisual.pageBackground.opacity(colorScheme == .dark ? 0.42 : 0.62))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.75), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 20, y: 10)
    }
}

/// Title for a scene plate: keeps the localized line breaks and marks the last word
/// with the lime highlighter used on the home hero ("у [Швейцарії]").
struct SceneTitleText: View {
    let text: String
    var size: CGFloat = 26

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(lines.dropLast().enumerated()), id: \.offset) { _, line in
                Text(line)
            }
            lastLine(lines.last ?? "")
        }
        .font(.system(size: size, weight: .bold))
        .tracking(-0.3)
        .foregroundColor(JourneyVisual.primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.replacingOccurrences(of: "\n", with: " "))
        .accessibilityAddTraits(.isHeader)
    }

    private func lastLine(_ line: String) -> some View {
        let words = line.split(separator: " ")
        let head = words.dropLast().joined(separator: " ")
        return HStack(spacing: 6) {
            if !head.isEmpty { Text(head) }
            if let last = words.last {
                Text(String(last))
                    .foregroundColor(.black)
                    .padding(.horizontal, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(JourneyVisual.lime)
                            .rotationEffect(.degrees(-1.5))
                    )
            }
        }
    }
}
