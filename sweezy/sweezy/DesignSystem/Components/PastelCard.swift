import SwiftUI

struct PastelCard<Content: View>: View {
    let background: Color
    let content: Content
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    init(background: Color, cornerRadius: CGFloat = 28, @ViewBuilder content: () -> Content) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        let fill = colorScheme == .dark ? Theme.Colors.darkCard : background
        let stroke = colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.05)
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .themeShadow(colorScheme == .dark ? Theme.Shadows.level1 : Theme.Shadows.level2)
    }
}

#Preview {
    VStack(spacing: 16) {
        PastelCard(background: Color(red: 0.93, green: 0.96, blue: 1.0)) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                    .opacity(0.8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Document Templates")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Ready to download")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Spacer()
            }
        }
    }
    .padding()
    .background(Theme.Colors.primaryBackground)
}
