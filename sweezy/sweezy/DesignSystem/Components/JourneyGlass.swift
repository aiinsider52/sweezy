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

    private var cityScene: String {
        if imageName.contains("market") { return "market" }
        if imageName.contains("community") { return "people" }
        if imageName.contains("tool") || imageName.contains("museum") { return "directory" }
        return "home"
    }

    var body: some View {
        CityPageBackground(scene: cityScene)
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

/// Floating dock: the selected tab opens into a lime pill with its name, the rest stay as quiet icons.
/// People lives in the marketplace and the home page now, so it has no tab of its own.
struct JourneyBottomBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: Int
    @Namespace private var selectionNamespace

    private struct Item {
        let tab: Int
        let icon: String
        let selectedIcon: String
        let title: String
        let identifier: String
    }

    private let items: [Item] = [
        Item(tab: 0, icon: "house", selectedIcon: "house.fill", title: "journey.tab.home".localized, identifier: "home"),
        Item(tab: 1, icon: "book.pages", selectedIcon: "book.pages.fill", title: "journey.tab.directory".localized, identifier: "directory"),
        Item(tab: 2, icon: "map", selectedIcon: "map.fill", title: "journey.tab.map".localized, identifier: "map"),
        Item(tab: 3, icon: "bag", selectedIcon: "bag.fill", title: "journey.tab.marketplace".localized, identifier: "marketplace"),
        Item(tab: MainTabRouter.settingsTab, icon: "gearshape", selectedIcon: "gearshape.fill", title: "journey.tab.settings".localized, identifier: "settings")
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.tab) { item in
                tabButton(item)
            }
        }
        .padding(6)
        .background {
            Capsule()
                .fill(JourneyVisual.black)
                .overlay(
                    Capsule().stroke(
                        LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
                .shadow(color: JourneyVisual.lime.opacity(0.10), radius: 30, y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.8), value: selection)
    }

    private func tabButton(_ item: Item) -> some View {
        let selected = selection == item.tab
        return Button {
            selection = item.tab
        } label: {
            HStack(spacing: 7) {
                Image(systemName: selected ? item.selectedIcon : item.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: selected)
                if selected {
                    Text(item.title)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .leading)))
                }
            }
            .foregroundColor(selected ? .black : .white.opacity(0.62))
            .padding(.horizontal, selected ? 16 : 0)
            .frame(maxWidth: selected ? nil : .infinity)
            .frame(height: 50)
            .background {
                if selected {
                    Capsule()
                        .fill(JourneyVisual.lime)
                        .shadow(color: JourneyVisual.lime.opacity(0.45), radius: 12, y: 2)
                        .matchedGeometryEffect(id: "journey-tab-selection", in: selectionNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.92, hapticStyle: .light))
        .layoutPriority(selected ? 1 : 0)
        .accessibilityLabel(item.title)
        .accessibilityValue(selected ? "journey.tab.selected".localized : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("tab.\(item.identifier)")
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
