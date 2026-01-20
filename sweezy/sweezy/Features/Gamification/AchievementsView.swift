import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var appContainer: AppContainer
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Досягнення")
                    .font(Theme.Typography.title1)
                    .padding(.horizontal, Theme.Spacing.lg)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(appContainer.gamification.badges, id: \.self) { id in
                        VStack(spacing: 8) {
                            Image(systemName: icon(for: id))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(color(for: id))
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(color(for: id).opacity(0.15)))
                            Text(title(for: id))
                                .font(Theme.Typography.caption)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                                .fill(Theme.Colors.secondaryBackground)
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.top, Theme.Spacing.lg)
        }
        .featureOnboarding(.gamification)
    }
    
    private func icon(for id: String) -> String {
        switch id {
        case "reader_1": return "book.fill"
        case "reader_5": return "books.vertical.fill"
        case "organizer_1": return "checklist"
        default: return "star.fill"
        }
    }
    private func color(for id: String) -> Color {
        switch id {
        case "reader_1": return Theme.Colors.info
        case "reader_5": return Theme.Colors.accentTurquoise
        case "organizer_1": return Theme.Colors.success
        default: return Theme.Colors.accent
        }
    }
    private func title(for id: String) -> String {
        switch id {
        case "reader_1": return "Читач"
        case "reader_5": return "Книголюб"
        case "organizer_1": return "Організатор"
        default: return "Відзнака"
        }
    }
}


