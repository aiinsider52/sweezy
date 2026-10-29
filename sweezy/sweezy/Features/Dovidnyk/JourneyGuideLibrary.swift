import SwiftUI

extension GuideCategory {
    /// Illustrations that fit the topic. Guides of one category rotate through them,
    /// so a list of six banking guides doesn't show the same picture six times.
    /// First entries differ between categories, so neighbouring topics start apart.
    var coverPool: [String] {
        switch self {
        case .documents:
            return ["story-documents", "journey-tool-documents", "journey-place-government", "business-cover-translation", "journey-tool-deadlines", "story-plan-complete"]
        case .legal:
            return ["business-cover-legal", "journey-market-consultant", "journey-place-government", "business-cover-translation", "story-documents"]
        case .housing:
            return ["story-housing", "journey-place-housing", "business-cover-moving", "marketplace-service-moving", "business-cover-community", "business-cover-cleaning", "business-cover-repair"]
        case .insurance:
            return ["journey-market-consultant", "business-cover-finance", "marketplace-service-business", "journey-place-healthcare", "business-cover-legal"]
        case .healthcare:
            return ["journey-place-healthcare", "marketplace-service-family", "business-cover-health", "story-chat", "journey-tool-ask"]
        case .work:
            return ["story-jobs", "journey-place-employment", "journey-tool-cv", "journey-tool-jobs", "business-cover-it", "marketplace-service-business", "business-cover-other"]
        case .finance:
            return ["business-cover-finance", "marketplace-service-business", "journey-market-consultant", "journey-tool-ask", "business-cover-retail", "journey-tool-deadlines"]
        case .banking:
            return ["journey-tool-ask", "business-cover-finance", "marketplace-service-business", "journey-market-consultant", "business-cover-it", "story-jobs"]
        case .education:
            return ["journey-place-education", "business-cover-education", "story-language", "journey-tool-deadlines", "journey-place-community"]
        case .integration:
            return ["story-language", "story-events", "story-find-people", "journey-place-community", "business-cover-community", "story-chat", "business-cover-events"]
        case .emergency:
            return ["business-cover-health", "journey-place-government", "story-chat", "journey-tool-ask", "journey-place-healthcare"]
        case .transport:
            return ["journey-tool-my-plan", "business-cover-auto", "journey-place-housing", "story-login", "marketplace-service-moving", "marketplace-service-family"]
        case .lifestyle:
            return ["story-events", "business-cover-food", "business-cover-events", "story-chat", "journey-place-community", "story-registration", "business-cover-beauty"]
        }
    }
}

extension Guide {
    /// Picture from the category pool, assigned in turn by `GuideCovers` so that
    /// neighbours in a category never repeat. Hash fallback for guides not indexed yet.
    var coverAsset: String {
        if let assigned = GuideCovers.assigned[id] { return assigned }
        let pool = category.coverPool
        var seed = 5381
        for scalar in id.uuidString.unicodeScalars { seed = (seed &* 33 &+ Int(scalar.value)) & 0x7fffffff }
        return pool[seed % pool.count]
    }

    var coverURL: URL? {
        guard let heroImage, heroImage.hasPrefix("http") else { return nil }
        return URL(string: heroImage)
    }
}

/// Rotates each category's cover pool over its guides (per language, in list order: by priority),
/// so the same guide keeps its picture in the list, the featured card and the article.
enum GuideCovers {
    /// Written only from ContentService on the main actor.
    nonisolated(unsafe) private(set) static var assigned: [UUID: String] = [:]

    static func index(_ guides: [Guide]) {
        var result: [UUID: String] = [:]
        let groups = Dictionary(grouping: guides) { "\($0.category.rawValue)|\($0.language ?? "")" }
        for group in groups.values {
            for (offset, guide) in group.sorted(by: { $0.priority > $1.priority }).enumerated() {
                let pool = guide.category.coverPool
                result[guide.id] = pool[offset % pool.count]
            }
        }
        assigned = result
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
                        JourneyRemoteImage(url: guide.coverURL, fallbackAsset: guide.coverAsset)
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
