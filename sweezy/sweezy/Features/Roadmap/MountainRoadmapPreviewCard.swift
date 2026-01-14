//
//  MountainRoadmapPreviewCard.swift
//  sweezy
//
//  Preview card for Home screen that shows current roadmap progress
//

import SwiftUI

struct MountainRoadmapPreviewCard: View {
    @EnvironmentObject private var appContainer: AppContainer
    @StateObject private var roadmapService = RoadmapService()
    
    private var isPremium: Bool {
        appContainer.subscriptionManager.isPremium
    }
    
    var body: some View {
        ZStack {
            // Background with mountain gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.15, blue: 0.3),
                            Color(red: 0.15, green: 0.25, blue: 0.4),
                            Color(red: 0.2, green: 0.35, blue: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Stars
            GeometryReader { geo in
                ForEach(0..<15, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.3...0.7)))
                        .frame(width: CGFloat.random(in: 1...2))
                        .position(
                            x: CGFloat(i * 25 + 10),
                            y: CGFloat.random(in: 10...50)
                        )
                }
            }
            
            // Mountain silhouette
            MountainSilhouette()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.25, blue: 0.35),
                            Color(red: 0.15, green: 0.2, blue: 0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 80)
                .offset(y: 50)
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(roadmapService.currentLevel?.title ?? "Базовий табір")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Рівень \(roadmapService.progress.currentLevel) з 10")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Current level icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .trim(from: 0, to: roadmapService.levelProgress(for: roadmapService.progress.currentLevel))
                            .stroke(Color.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: roadmapService.currentLevel?.iconName ?? "flag.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                
                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Загальний прогрес")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(roadmapService.overallProgress * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * roadmapService.overallProgress)
                        }
                    }
                    .frame(height: 6)
                }
                
                // Level indicators
                HStack(spacing: 4) {
                    ForEach(1...10, id: \.self) { levelId in
                        let level = roadmapService.levels.first { $0.id == levelId }
                        let status = level.map { roadmapService.status(for: $0, isPremium: isPremium) } ?? .locked
                        
                        Circle()
                            .fill(levelIndicatorColor(for: status))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    
                    Spacer()
                    
                    // Tap hint
                    HStack(spacing: 4) {
                        Text("Відкрити")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding()
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .onReceive(NotificationCenter.default.publisher(for: .roadmapProgressUpdated)) { _ in
            roadmapService.refreshFromStorage()
        }
    }
    
    private func levelIndicatorColor(for status: LevelStatus) -> Color {
        switch status {
        case .completed: return .green
        case .inProgress: return .cyan
        case .available: return .orange
        case .locked: return .gray.opacity(0.5)
        }
    }
}

// MARK: - Mountain Silhouette Shape

struct MountainSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: h))
        
        // First small hill
        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.7))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.85))
        
        // Main mountain
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.3))
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.1)) // Peak
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.25))
        
        // Second peak
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.15))
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.4))
        
        // Small hill
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.6))
        path.addLine(to: CGPoint(x: w * 0.95, y: h * 0.75))
        
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    MountainRoadmapPreviewCard()
        .environmentObject(AppContainer())
        .padding()
        .background(Color.black)
}

