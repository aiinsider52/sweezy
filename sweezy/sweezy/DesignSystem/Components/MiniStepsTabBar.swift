import SwiftUI

struct MiniStep: Identifiable, Equatable {
    let id: UUID
    let title: String
    let isDone: Bool
}

struct MiniStepsTabBar: View {
    let steps: [MiniStep]
    var onTap: ((MiniStep) -> Void)?
    
    private var activeIndex: Int? {
        steps.firstIndex(where: { !$0.isDone })
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.1.id) { idx, step in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        onTap?(step)
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(step.isDone ? 0.22 : 0.14))
                                    .frame(width: 18, height: 18)
                                if step.isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Text(step.title)
                                .font(Theme.Typography.caption)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(stepBackground(for: idx, isDone: step.isDone))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(stepStroke(for: idx, isDone: step.isDone), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    private func stepBackground(for idx: Int, isDone: Bool) -> AnyShapeStyle {
        if activeIndex == idx && !isDone {
            return AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Color.white.opacity(isDone ? 0.10 : 0.08))
    }
    
    private func stepStroke(for idx: Int, isDone: Bool) -> AnyShapeStyle {
        if activeIndex == idx && !isDone {
            return AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Color.white.opacity(0.22))
    }
}


