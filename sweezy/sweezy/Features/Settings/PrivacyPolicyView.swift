//
//  PrivacyPolicyView.swift
//  sweezy
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    private let lastUpdatedDate = Date()

    private var supportEmail: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "SUPPORT_EMAIL") as? String) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "support@sweezy.app" : trimmed
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("privacy.title".localized)
                            .font(Theme.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.primaryText)
                        Text(String(format: "privacy.last_updated".localized, formattedDate(lastUpdatedDate)))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    PrivacySection(
                        title: "privacy.intro.title".localized,
                        content: "privacy.intro.content".localized
                    )
                    PrivacySection(
                        title: "privacy.data_collection.title".localized,
                        content: "privacy.data_collection.content".localized
                    )
                    PrivacySection(
                        title: "privacy.data_usage.title".localized,
                        content: "privacy.data_usage.content".localized
                    )
                    PrivacySection(
                        title: "privacy.data_storage.title".localized,
                        content: "privacy.data_storage.content".localized
                    )
                    PrivacySection(
                        title: "privacy.third_parties.title".localized,
                        content: "privacy.third_parties.content".localized
                    )
                    PrivacySection(
                        title: "privacy.rights.title".localized,
                        content: "privacy.rights.content".localized
                    )
                    PrivacySection(
                        title: "privacy.contact.title".localized,
                        content: "privacy.contact.content".localized + " \(supportEmail)"
                    )
                }
                .padding(.vertical, Theme.Spacing.xl)
            }
            .background(Theme.Colors.primaryBackground)
            .navigationTitle("privacy.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) { dismiss() }
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

private struct PrivacySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(Theme.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.primaryText)
            Text(content)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
}



