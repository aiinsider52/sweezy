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
Використовуючи додаток, ви погоджуєтесь із умовами використання сервісу та відповідальністю за користування контентом. Контент має інформаційний характер і не є юридичною консультацією. Наразі Sweezy доступний безплатно, без внутрішніх покупок.
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

