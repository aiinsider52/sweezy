import SwiftUI

struct JourneyStageSticker: Identifiable {
    let icon: String
    let title: String
    let swatch: JourneyCategorySwatch

    var id: String { title }
}

/// Lime stage with the mascot on the right and a few feature stickers sliding in on the left.
/// Shared by entry points that ask for a commitment (sign-in, Plus) so they feel like one family.
/// Decorative: the same facts are always repeated in readable rows below it.
struct JourneyMascotStage: View {
    let pose: SweezyCompanionPose
    let stickers: [JourneyStageSticker]
    var height: CGFloat = 226
    var mascotSize: CGFloat = 176

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        ZStack {
            LinearGradient(
                colors: [JourneyVisual.lime.opacity(0.62), JourneyVisual.lime.opacity(0.12)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            Circle()
                .stroke(Color.white.opacity(0.55), lineWidth: 1.2)
                .frame(width: 300, height: 300)
                .offset(x: 110, y: 16)
            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: 196, height: 196)
                .offset(x: 110, y: 16)

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(stickers.enumerated()), id: \.element.id) { index, sticker in
                        stickerView(sticker, order: index)
                    }
                }
                .padding(.leading, 16)

                Spacer(minLength: 0)

                SweezyCompanion(pose: pose, size: mascotSize)
                    .idleFloat(enabled: !reduceMotion)
                    .offset(y: 14)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.88, anchor: .bottom)
                    .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.72), value: appeared)
            }
        }
        .frame(height: height)
        .clipShape(shape)
        .overlay(shape.stroke(JourneyVisual.lime.opacity(0.55), lineWidth: 1))
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }

    private func stickerView(_ sticker: JourneyStageSticker, order: Int) -> some View {
        HStack(spacing: 8) {
            JourneyCategoryIcon(symbol: sticker.icon, swatch: sticker.swatch, size: 26)
            Text(sticker.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(JourneyVisual.primaryText)
                .lineLimit(1)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .frame(height: 38)
        .background(Theme.Colors.card)
        .clipShape(Capsule())
        .shadow(color: JourneyVisual.black.opacity(0.08), radius: 8, y: 3)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared || reduceMotion ? 0 : -18)
        .animation(
            reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8).delay(0.1 + 0.08 * Double(order)),
            value: appeared
        )
    }
}
