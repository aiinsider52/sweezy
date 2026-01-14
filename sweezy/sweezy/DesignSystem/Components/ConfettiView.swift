import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
    let count: Int
    let duration: Double
    
    init(count: Int = 24, duration: Double = 1.4) {
        self.count = count
        self.duration = duration
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let color = colors[i % colors.count]
                ConfettiPiece(color: color)
                    .offset(x: animate ? CGFloat.random(in: -140...140) : 0,
                            y: animate ? CGFloat.random(in: 160...300) : 0)
                    .rotationEffect(.degrees(animate ? Double.random(in: 90...360) : 0))
                    .opacity(animate ? 0 : 1)
                    .animation(.easeOut(duration: duration).delay(Double(i) * 0.01), value: animate)
            }
        }
        .onAppear {
            animate = true
        }
    }
}

private struct ConfettiPiece: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: CGFloat.random(in: 6...10), height: CGFloat.random(in: 6...10))
            .offset(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: -20...20))
    }
}
