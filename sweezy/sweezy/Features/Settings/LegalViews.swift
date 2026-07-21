//
//  LegalViews.swift
//  sweezy
//
//  Simple in-app Privacy Policy and Terms screens.
//

import SwiftUI

struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Умови використання")
                    .font(.title2.bold())
                Text("""
Використовуючи додаток, ви погоджуєтесь із умовами використання сервісу, політикою підписок та відповідальністю за користування контентом.
""")
                .foregroundColor(.secondary)
            }
            .padding()
            .journeyCard()
            .padding()
        }
        .navigationTitle("Умови використання")
        .navigationBarTitleDisplayMode(.inline)
        .journeyScreen(.city, darkness: 0.7)
    }
}

