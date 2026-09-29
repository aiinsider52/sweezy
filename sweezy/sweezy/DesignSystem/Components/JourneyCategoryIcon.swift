import SwiftUI

/// Brand palette for category glyphs.
/// System tints (`.blue`, `.pink`, `.yellow`) clashed with the illustrated paper look,
/// so every category now maps to one of a few hand-picked paper/ink pairs.
struct JourneyCategorySwatch: Hashable {
    let fill: Color
    let ink: Color

    fileprivate init(paper: (Double, Double, Double), ink: (Double, Double, Double)) {
        self.fill = JourneyCategorySwatch.dynamic(light: paper, dark: (ink.0 * 0.42 + 0.03, ink.1 * 0.42 + 0.04, ink.2 * 0.42 + 0.03))
        self.ink = JourneyCategorySwatch.dynamic(light: ink, dark: (min(1, paper.0 + 0.05), min(1, paper.1 + 0.05), min(1, paper.2 + 0.05)))
    }

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

enum JourneyCategoryPalette {
    static let lime = JourneyCategorySwatch(paper: (0.87, 0.95, 0.66), ink: (0.28, 0.42, 0.04))
    static let coral = JourneyCategorySwatch(paper: (1.0, 0.85, 0.81), ink: (0.66, 0.21, 0.15))
    static let teal = JourneyCategorySwatch(paper: (0.77, 0.93, 0.90), ink: (0.05, 0.38, 0.36))
    static let sky = JourneyCategorySwatch(paper: (0.81, 0.88, 1.0), ink: (0.16, 0.29, 0.62))
    static let sand = JourneyCategorySwatch(paper: (1.0, 0.90, 0.69), ink: (0.53, 0.35, 0.02))
    static let lilac = JourneyCategorySwatch(paper: (0.89, 0.85, 1.0), ink: (0.35, 0.24, 0.63))
    static let graphite = JourneyCategorySwatch(paper: (0.90, 0.90, 0.88), ink: (0.24, 0.25, 0.23))

    private static let cycle: [JourneyCategorySwatch] = [lime, coral, teal, sky, sand, lilac]

    /// Stable swatch for categories that have no explicit mapping (guides, events, checklists).
    static func swatch(for key: String) -> JourneyCategorySwatch {
        guard !key.isEmpty else { return graphite }
        let hash = key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        return cycle[hash % cycle.count]
    }
}

// MARK: - Sticker tile

/// Category glyph drawn as a paper sticker: tinted plate, ink outline and a soft drop plate underneath.
/// Replaces bare SF Symbols so category rows read as part of the illustrated style.
struct JourneyCategoryIcon: View {
    let symbol: String
    var swatch: JourneyCategorySwatch = JourneyCategoryPalette.graphite
    var size: CGFloat = 40
    /// Sticker sitting on a dark hero: the plate goes translucent instead of paper-white.
    var onDark = false
    var selected = false

    private var corner: CGFloat { size * 0.32 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: corner, style: .continuous) }

    var body: some View {
        ZStack {
            shape
                .fill(onDark ? Color.black.opacity(0.35) : JourneyVisual.black.opacity(0.14))
                .offset(x: size * 0.045, y: size * 0.06)

            shape
                .fill(onDark ? swatch.fill.opacity(selected ? 0.95 : 0.24) : swatch.fill)

            shape
                .stroke(onDark ? Color.white.opacity(selected ? 0.9 : 0.28) : swatch.ink.opacity(0.35), lineWidth: 1.2)

            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(onDark && !selected ? Color.white.opacity(0.92) : swatch.ink)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
