import SwiftUI

struct TypewriterText: View {
    let text: String
    let speed: Double
    let font: Font
    let color: Color
    let showCursor: Bool
    
    @State private var visible: String = ""
    @State private var index: Int = 0
    @State private var showBar: Bool = true
    
    init(text: String, speed: Double = 0.04, font: Font = Theme.Typography.largeTitle, color: Color = .white, showCursor: Bool = true) {
        self.text = text
        self.speed = speed
        self.font = font
        self.color = color
        self.showCursor = showCursor
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(visible)
                .font(font)
                .foregroundColor(color)
            if showCursor {
                Text("|")
                    .font(font)
                    .foregroundColor(color.opacity(showBar ? 0.9 : 0.2))
                    .padding(.leading, 2)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            visible = ""
            index = 0
            showBar = true
            typeNext()
            blinkCursor()
        }
    }
    
    private func typeNext() {
        guard index < text.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            let nextIndex = text.index(text.startIndex, offsetBy: index + 1)
            visible = String(text[..<nextIndex])
            index += 1
            typeNext()
        }
    }
    
    private func blinkCursor() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            showBar.toggle()
        }
    }
}

#Preview {
    ZStack {
        Theme.Colors.gradientHero.ignoresSafeArea()
        TypewriterText(text: "Добрий ранок")
    }
}
