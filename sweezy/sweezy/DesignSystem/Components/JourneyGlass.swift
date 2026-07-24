import SwiftUI
import UIKit

enum JourneyVisual {
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.02)
    static let coral = Color(red: 1.0, green: 0.39, blue: 0.31)
    static let black = Color(red: 0.025, green: 0.03, blue: 0.025)
    static let glassFill = Color.black.opacity(0.34)
    static let glassBorder = Color.white.opacity(0.32)
}

struct JourneyPhotoBackground: View {
    let imageName: String
    var blurRadius: CGFloat = 0
    var darkness: Double = 0.36

    var body: some View {
        GeometryReader { geometry in
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .blur(radius: blurRadius)
                .overlay(Color.black.opacity(darkness))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.22),
                            Color.clear,
                            Color.black.opacity(0.68)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipped()
        }
        .ignoresSafeArea()
    }
}

struct JourneyGlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial.opacity(0.76))
            .background(JourneyVisual.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.62), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.28), radius: 20, y: 10)
    }
}

struct JourneySearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(.white)
        .padding(.horizontal, 17)
        .frame(height: 48)
        .background(.ultraThinMaterial.opacity(0.78))
        .background(Color.black.opacity(0.18))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.34), lineWidth: 1))
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
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 15)
            .frame(height: 38)
            .background(isSelected ? JourneyVisual.lime : Color.black.opacity(0.28))
            .background(.ultraThinMaterial.opacity(isSelected ? 0 : 0.72))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0 : 0.28), lineWidth: 1))
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
            .frame(height: compact ? 42 : 48)
            .background(Color.black.opacity(0.92))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct JourneyBottomBar: View {
    @Binding var selection: Int

    private let items: [(String, String)] = [
        ("house", "journey.tab.home".localized),
        ("list.bullet.rectangle", "journey.tab.directory".localized),
        ("mappin", "journey.tab.map".localized),
        ("cart", "journey.tab.marketplace".localized),
        ("gearshape", "journey.tab.settings".localized)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        selection = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(selection == index ? JourneyVisual.lime : Color.clear)
                                .frame(width: 34, height: 34)
                            Image(systemName: iconName(for: index, baseName: item.0))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selection == index ? .black : .white.opacity(0.62))
                        }
                        Text(item.1)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(selection == index ? JourneyVisual.lime : .white.opacity(0.48))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.1)
                .accessibilityValue(selection == index ? "journey.tab.selected".localized : "")
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
                .accessibilityIdentifier("tab.\(tabIdentifier(for: index))")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 8)
        .background(JourneyVisual.black.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
    }

    private func iconName(for index: Int, baseName: String) -> String {
        guard selection == index else { return baseName }
        return index == 2 ? "mappin.and.ellipse" : "\(baseName).fill"
    }

    private func tabIdentifier(for index: Int) -> String {
        ["home", "directory", "map", "marketplace", "settings"][index]
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

private struct JourneyScreenModifier: ViewModifier {
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
            .tint(JourneyVisual.lime)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.34), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
    }
}

private struct JourneyFormModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.black.opacity(0.34))
            .listRowSeparatorTint(Color.white.opacity(0.12))
            .foregroundStyle(.white)
            .tint(JourneyVisual.lime)
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
        background(.ultraThinMaterial.opacity(0.78))
            .background(Color.black.opacity(0.32))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.26), radius: 18, y: 9)
    }
}
