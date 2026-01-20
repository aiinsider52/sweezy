//
//  NewsDetailView.swift
//  sweezy
//

import SwiftUI

struct NewsDetailView: View, Identifiable {
    let id = UUID()
    let news: NewsItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = news.imageURL, let imgURL = URL(string: url) {
                    CachedAsyncImage(url: imgURL, contentMode: .fill) {
                        ZStack {
                            Rectangle().fill(Theme.Colors.glassMaterial)
                            ProgressView()
                        }
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous))
                }
                
                Text(news.title)
                    .font(Theme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("\(news.source) • \(formattedDate(news.publishedAt))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                if let content = news.content, !content.isEmpty {
                    // SwiftUI Text supports basic Markdown
                    Text(.init(content))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(news.summary)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.primaryBackground.ignoresSafeArea())
        .navigationTitle("Новина")
        .navigationBarTitleDisplayMode(.inline)
        .featureOnboarding(.news)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateStyle = .long
        return df.string(from: date)
    }
}


