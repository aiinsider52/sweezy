import SwiftUI
import UIKit

enum JourneyVisual {
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.02)
    /// Brand-colored text on paper (WCAG AA on paper and white cards); lime stays for fills and dark/photo surfaces.
    static let accentText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.78, green: 1.0, blue: 0.02, alpha: 1)
            : UIColor(red: 0.29, green: 0.48, blue: 0.05, alpha: 1)
    })
    /// Brighter brand green for icons and large numerals, where AA-large is enough.
    static let accentStrong = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.78, green: 1.0, blue: 0.02, alpha: 1)
            : UIColor(red: 0.36, green: 0.58, blue: 0.02, alpha: 1)
    })
    static let coral = Color(red: 1.0, green: 0.39, blue: 0.31)
    static let black = Color(red: 0.025, green: 0.03, blue: 0.025)
    static let glassFill = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 0.34)
            : UIColor(white: 1.0, alpha: 0.68)
    })
    static let glassBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.32)
            : UIColor(red: 0.10, green: 0.20, blue: 0.12, alpha: 0.14)
    })
    static let chrome = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.025, green: 0.03, blue: 0.025, alpha: 0.96)
            : UIColor(red: 0.976, green: 0.969, blue: 0.941, alpha: 1)
    })
    static let chromeText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.62)
            : UIColor(red: 0.10, green: 0.18, blue: 0.11, alpha: 0.68)
    })
    static let pageBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.025, green: 0.03, blue: 0.025, alpha: 1)
            : UIColor(red: 0.976, green: 0.969, blue: 0.941, alpha: 1)
    })
    static let primaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.96)
            : UIColor(red: 0.055, green: 0.09, blue: 0.06, alpha: 0.96)
    })
    static let secondaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.62)
            : UIColor(red: 0.10, green: 0.16, blue: 0.11, alpha: 0.64)
    })
    static let softSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.065)
            : UIColor(white: 1, alpha: 0.82)
    })
    static let softBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.14)
            : UIColor(red: 0.10, green: 0.18, blue: 0.11, alpha: 0.12)
    })
    static let elevatedSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.075, blue: 0.060, alpha: 0.92)
            : UIColor(white: 1.0, alpha: 0.92)
    })
}

/// Lightweight editorial background used by non-photo pages.
/// Static geometry adds depth without an always-running render loop.
struct JourneyAmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var accent: Color = JourneyVisual.lime

    var body: some View {
        JourneyVisual.pageBackground.ignoresSafeArea()
    }
}

struct JourneyPhotoBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let imageName: String
    var blurRadius: CGFloat = 0
    var darkness: Double = 0.36

    private var cityArtwork: String {
        if imageName.contains("market") { return "city-scene-market" }
        if imageName.contains("community") { return "city-scene-people" }
        if imageName.contains("tool") || imageName.contains("museum") { return "city-scene-directory" }
        return "city-scene-home"
    }

    var body: some View {
        CityPageBackground(scene: cityArtwork.replacingOccurrences(of: "city-scene-", with: ""))
    }
}

struct JourneyGlassPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(colorScheme == .dark ? Theme.Colors.card : Color.white.opacity(0.94))
            .background(JourneyVisual.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white.opacity(0.62), Color.white.opacity(0.12)]
                                : [Color.white.opacity(0.92), Color.black.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )

    }
}

struct JourneySearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(JourneyVisual.primaryText.opacity(0.78))
            TextField(
                "",
                text: $text,
                prompt: Text(prompt).foregroundColor(JourneyVisual.secondaryText)
            )
                .foregroundStyle(JourneyVisual.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(JourneyVisual.primaryText)
        .padding(.horizontal, 17)
        .frame(height: 48)
        .background(.ultraThinMaterial.opacity(0.78))
        .background(JourneyVisual.softSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
    }
}

struct JourneyFilterChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    init(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isSelected ? .black : JourneyVisual.primaryText)
            .padding(.horizontal, 15)
            .frame(minHeight: Theme.Layout.minimumTouchTarget)
            .background(isSelected ? JourneyVisual.lime : JourneyVisual.softSurface)
            .background(.ultraThinMaterial.opacity(isSelected ? 0 : 0.72))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct JourneyPrimaryButton: View {
    let title: String
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(title)
                Image(systemName: "arrow.right")
            }
            .font(.system(size: compact ? 13 : 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 18 : 22)
            .frame(height: compact ? Theme.Layout.minimumTouchTarget : 50)
            .background(Color.black.opacity(0.92))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct JourneyBottomBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: Int
    @Namespace private var selectionNamespace

    private let items: [(String, String)] = [
        ("house", "journey.tab.home".localized),
        ("list.bullet.rectangle", "journey.tab.directory".localized),
        ("mappin", "journey.tab.map".localized),
        ("cart", "journey.tab.marketplace".localized),
        ("person.2", "journey.tab.people".localized)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    // ScaleButtonStyle below already plays the light haptic on press.
                    withAnimation(reduceMotion ? nil : Theme.Animation.selection) {
                        selection = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selection == index {
                                Circle()
                                    .fill(JourneyVisual.lime)
                                    .frame(width: 34, height: 34)
                                    .matchedGeometryEffect(id: "journey-tab-selection", in: selectionNamespace)
                            }
                            Image(systemName: iconName(for: index, baseName: item.0))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selection == index ? .black : JourneyVisual.chromeText)
                                .contentTransition(.symbolEffect(.replace))
                                .symbolEffect(.bounce, value: selection == index)
                        }
                        Text(item.1)
                            .font(.system(size: 10, weight: selection == index ? .bold : .semibold))
                            .foregroundColor(selection == index ? JourneyVisual.accentText : JourneyVisual.chromeText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.95, hapticStyle: .light))
                .accessibilityLabel(item.1)
                .accessibilityValue(selection == index ? "journey.tab.selected".localized : "")
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
                .accessibilityIdentifier("tab.\(tabIdentifier(for: index))")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 8)
        .sensoryFeedback(.selection, trigger: selection)
        .background(JourneyVisual.chrome)
        .overlay(alignment: .top) {
            Rectangle().fill(JourneyVisual.softBorder).frame(height: 0.5)
        }
    }

    private func iconName(for index: Int, baseName: String) -> String {
        guard selection == index else { return baseName }
        return index == 2 ? "mappin.and.ellipse" : "\(baseName).fill"
    }

    private func tabIdentifier(for index: Int) -> String {
        ["home", "directory", "map", "marketplace", "people"][index]
    }
}

struct JourneyRemoteImage: View {
    let url: URL?
    let fallbackAsset: String

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Image(fallbackAsset).resizable().scaledToFill()
            }
        }
    }
}

enum JourneyBackdrop: String, CaseIterable {
    case zurich = "swiss-moment-zurich"
    case alpine = "swiss-moment-grindelwald"
    case lake = "swiss-moment-luzern"
    case city = "cityhub-zurich-oldtown"
    case market = "journey-market-consultant"
}

extension View {
    /// Paper strip behind the status bar so scrolled content never runs under the clock.
    func statusBarScrim() -> some View {
        overlay(alignment: .top) {
            Color.clear
                .frame(height: 0)
                .background(JourneyVisual.pageBackground.ignoresSafeArea(edges: .top))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct JourneyScreenModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let backdrop: JourneyBackdrop
    let darkness: Double

    func body(content: Content) -> some View {
        content
            .background {
                JourneyPhotoBackground(
                    imageName: backdrop.rawValue,
                    blurRadius: 7,
                    darkness: darkness
                )
            }
            .scrollContentBackground(.hidden)
            .statusBarScrim()
            .tint(JourneyVisual.primaryText)
            .toolbarBackground(JourneyVisual.pageBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
    }
}

private struct JourneyFormModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .listRowBackground(colorScheme == .dark ? Color.black.opacity(0.34) : Color.white.opacity(0.82))
            .listRowSeparatorTint(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
            .foregroundStyle(Theme.Colors.textPrimary)
            .tint(JourneyVisual.accentText)
    }
}

extension View {
    func journeyScreen(
        _ backdrop: JourneyBackdrop = .alpine,
        darkness: Double = 0.58
    ) -> some View {
        modifier(JourneyScreenModifier(backdrop: backdrop, darkness: darkness))
    }

    func journeyForm() -> some View {
        modifier(JourneyFormModifier())
    }

    func journeyCard(cornerRadius: CGFloat = 22) -> some View {
        background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(JourneyVisual.softBorder, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }

    /// One-time, interruptible entrance. Reduced Motion falls back to no movement.
    func journeyEntrance(delay: Double = 0, distance: CGFloat = 12) -> some View {
        modifier(JourneyEntranceModifier(delay: delay, distance: distance))
    }
}

private struct JourneyEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let delay: Double
    let distance: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : distance)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.985)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(Theme.Animation.entrance.delay(min(delay, 0.28))) {
                        appeared = true
                    }
                }
            }
    }
}
