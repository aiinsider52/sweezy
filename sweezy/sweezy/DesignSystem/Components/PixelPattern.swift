import SwiftUI

struct PixelPatternBackground: View {
    let color: Color
    let size: CGFloat
    let opacity: Double
    
    init(color: Color = Color.black.opacity(0.06), size: CGFloat = 6, opacity: Double = 0.12) {
        self.color = color
        self.size = size
        self.opacity = opacity
    }
    
    var body: some View {
        GeometryReader { geo in
            let cols = Int(ceil(geo.size.width / size))
            let rows = Int(ceil(geo.size.height / size))
            Canvas { context, _ in
                for x in 0..<cols {
                    for y in 0..<rows {
                        if (x + y) % 2 == 0 { // checker-like pixel grid
                            let rect = CGRect(x: CGFloat(x) * size, y: CGFloat(y) * size, width: size, height: size)
                            context.fill(Path(rect), with: .color(color.opacity(opacity)))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct PixelBadgeIcon: View {
    let systemImage: String
    let tint: Color
    
    init(_ systemImage: String, tint: Color = Theme.Colors.accentTurquoise) {
        self.systemImage = systemImage
        self.tint = tint
    }
    
    var body: some View {
        ZStack {
            PixelPatternBackground(color: tint, size: 4, opacity: 0.15)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        PixelBadgeIcon("globe")
        PixelBadgeIcon("checkmark.seal.fill", tint: .green)
        PixelBadgeIcon("exclamationmark.triangle.fill", tint: .orange)
    }
}
