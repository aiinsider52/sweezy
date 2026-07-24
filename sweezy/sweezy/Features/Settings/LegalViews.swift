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
                Text("legal.terms.title".localized)
                    .font(.title2.bold())
                Text("legal.terms.body".localized)
                .foregroundColor(.secondary)
            }
            .padding()
            .journeyCard()
            .padding()
        }
        .navigationTitle("legal.terms.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .journeyScreen(.city, darkness: 0.7)
    }
}

