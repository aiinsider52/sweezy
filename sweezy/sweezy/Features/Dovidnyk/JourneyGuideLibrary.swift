import SwiftUI

extension GuideCategory {
    /// Illustration that matches the topic: the desk for documents, moving boxes for housing…
    var coverAsset: String {
        switch self {
        case .documents, .legal: return "story-documents"
        case .housing: return "story-housing"
        case .work, .finance, .banking: return "story-jobs"
        case .education, .integration: return "story-language"
        case .insurance, .healthcare: return "swiss-moment-luzern"
        case .emergency: return "cityhub-zurich-grossmuenster"
        case .transport: return "cityhub-zurich-viadukt"
        case .lifestyle: return "swiss-moment-grindelwald"
        }
    }
}

extension Guide {
    var coverURL: URL? {
        guard let heroImage, heroImage.hasPrefix("http") else { return nil }
        return URL(string: heroImage)
    }
}

/// Compact three-way switch between guides, tools and checklists.
struct JourneyWorkspaceSwitcher<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    let icon: (Item) -> String
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let selected = item == selection
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                        selection = item
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon(item)).font(.system(size: 12, weight: .bold))
                        Text(title(item))
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundColor(selected ? .black : JourneyVisual.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background {
                        if selected {
                            Capsule()
                                .fill(JourneyVisual.lime)
                                .matchedGeometryEffect(id: "workspace", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.97, hapticStyle: .light))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.Colors.card, in: Capsule())
        .overlay(Capsule().stroke(JourneyVisual.softBorder, lineWidth: 1))
    }
}

/// Editorial cover for the guide worth reading first.
struct JourneyGuideFeatureCard: View {
    let guide: Guide
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .frame(height: 236)
                    .overlay {
                        JourneyRemoteImage(url: guide.coverURL, fallbackAsset: guide.category.coverAsset)
                    }
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.25), .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("journey.directory.featured".localized.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.2)
                            .foregroundColor(.black)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(JourneyVisual.lime, in: Capsule())
                        Label(guide.category.localizedName, systemImage: guide.category.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(.white.opacity(0.18), in: Capsule())
                    }

                    Text(guide.title)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Label("journey.directory.reading_time_minutes".localized(with: guide.estimatedReadingTime), systemImage: "clock")
                        if guide.source != nil {
                            Label("journey.directory.official_sources".localized, systemImage: "checkmark.seal.fill")
                        }
                        Spacer(minLength: 8)
                        HStack(spacing: 6) {
                            Text("journey.directory.read".localized)
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(JourneyVisual.lime, in: Capsule())
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.985, hapticStyle: .light))
        .accessibilityIdentifier("directory.featuredGuide")
    }
}

/// Topic tile: icon sticker, name and how many guides it holds.
struct JourneyGuideTopicTile: View {
    let title: String
    let icon: String
    let swatch: JourneyCategorySwatch
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                JourneyCategoryIcon(symbol: icon, swatch: swatch, size: 36, selected: selected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selected ? .black : JourneyVisual.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(selected ? .black.opacity(0.65) : JourneyVisual.secondaryText)
                }
            }
            .padding(12)
            .frame(width: 112, alignment: .leading)
            .background(selected ? JourneyVisual.lime : Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Color.clear : JourneyVisual.softBorder, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96, hapticStyle: .light))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
