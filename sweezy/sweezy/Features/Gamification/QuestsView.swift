import SwiftUI

struct QuestsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Завдання")
                .font(Theme.Typography.title1)
                .padding(.horizontal, Theme.Spacing.lg)
            
            List {
                Section("Сьогодні") {
                    QuestRow(title: "Прочитай 1 гайд", progress: 0.0, reward: "+30 XP")
                    QuestRow(title: "Заверши 2 кроки чекліста", progress: 0.5, reward: "+40 XP")
                }
                Section("Тиждень") {
                    QuestRow(title: "5 кроків у Roadmap", progress: 0.2, reward: "+150 XP")
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct QuestRow: View {
    let title: String
    let progress: Double
    let reward: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 6)
                Circle().trim(from: 0, to: progress).stroke(Theme.Colors.accentTurquoise, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.Typography.subheadline)
                ProgressView(value: progress).progressViewStyle(.linear)
            }
            Spacer()
            Text(reward).font(Theme.Typography.caption).foregroundColor(Theme.Colors.accentTurquoise)
        }
        .padding(.vertical, 6)
    }
}


