import SwiftUI

/// Plain paper under forms and reading surfaces. City artwork is reserved for the main tabs.
struct CityPageBackground: View {
    var scene = "directory"

    var body: some View {
        JourneyVisual.pageBackground
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

struct CitySectionBanner: View {
    var scene = "directory"
    var height: CGFloat = 120

    var body: some View {
        CityScene(scene: scene, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

/// Shared artwork is decorative; native controls and live maps stay interactive.
struct CityScene: View {
    var scene = "home"
    var height: CGFloat = 190

    var body: some View {
        GeometryReader { geometry in
            Image("city-scene-\(scene)")
                .resizable().scaledToFill()
                .frame(width: geometry.size.width, height: height)
                .clipped()
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct CityPaper<Content: View>: View {
    var inset: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content.padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(JourneyVisual.softBorder))
    }
}

/// Fill the width offered by the parent; never let an image's aspect ratio widen a page.
struct FittedAssetImage: View {
    let name: String
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: height)
                .clipped()
        }
        .frame(height: height)
    }
}
