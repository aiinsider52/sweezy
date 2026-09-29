import SwiftUI

/// Shared paper palette for every legacy page entry point.
struct AdaptivePageBackground: View {
    var body: some View { CityPageBackground() }
}

struct AppBackground: View {
    var body: some View { CityPageBackground(scene: "home") }
}
