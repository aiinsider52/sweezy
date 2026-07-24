import SwiftUI

struct DocumentReadinessView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.openURL) private var openURL
    @State private var editingDocument: ReadinessDocument?
    @State private var expiryDate = Date()

    var body: some View {
        ZStack {
            JourneyPhotoBackground(imageName: "cityhub-zurich-landesmuseum", blurRadius: 2, darkness: 0.66)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    progressCard
                    ForEach(appContainer.lifeAdmin.documents) { document in
                        documentRow(document)
                    }
                }
                .padding(20)
                .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appContainer.lifeAdmin.prepareDocuments(for: appContainer.userProfile) }
        .sheet(item: $editingDocument) { document in
            NavigationStack {
                Form {
                    DatePicker("Термін дії", selection: $expiryDate, displayedComponents: .date)
                    Button("Прибрати термін") {
                        appContainer.lifeAdmin.setExpiry(nil, for: document.id)
                        editingDocument = nil
                    }
                }
                .navigationTitle(document.title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Зберегти") {
                            appContainer.lifeAdmin.setExpiry(expiryDate, for: document.id)
                            editingDocument = nil
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Readiness")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Sweezy зберігає тільки статус і строк. Файли документів не завантажуються.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.68))
        }
    }

    private var progressCard: some View {
        JourneyGlassPanel(cornerRadius: 23) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Готовність")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(readyCount)/\(appContainer.lifeAdmin.documents.count)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(JourneyVisual.lime)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.14))
                        Capsule().fill(JourneyVisual.lime)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 7)
            }
            .padding(16)
        }
    }

    private func documentRow(_ document: ReadinessDocument) -> some View {
        JourneyGlassPanel(cornerRadius: 21) {
            HStack(spacing: 12) {
                Button { appContainer.lifeAdmin.toggleDocument(document.id) } label: {
                    Image(systemName: document.isReady ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundColor(document.isReady ? JourneyVisual.lime : .white.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(document.requiredFor)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.56))
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        Button {
                            if let url = document.sourceURL { openURL(url) }
                        } label: {
                            Label(document.sourceTitle, systemImage: "checkmark.seal.fill")
                        }
                        Button {
                            expiryDate = document.expiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
                            editingDocument = document
                        } label: {
                            Label(expiryText(document), systemImage: "calendar")
                        }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(JourneyVisual.lime)
                }
                Spacer()
                Text(statusText(document.status))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(statusColor(document.status))
            }
            .padding(14)
        }
    }

    private var readyCount: Int { appContainer.lifeAdmin.documents.filter(\.isReady).count }
    private var progress: CGFloat {
        guard !appContainer.lifeAdmin.documents.isEmpty else { return 0 }
        return CGFloat(readyCount) / CGFloat(appContainer.lifeAdmin.documents.count)
    }

    private func expiryText(_ document: ReadinessDocument) -> String {
        document.expiryDate?.formatted(.dateTime.day().month(.abbreviated).year()) ?? "Додати строк"
    }

    private func statusText(_ status: ReadinessDocumentStatus) -> String {
        switch status {
        case .missing: return "НЕМАЄ"
        case .ready: return "ГОТОВО"
        case .expiring: return "СКОРО"
        case .expired: return "ПРОСТРОЧЕНО"
        }
    }

    private func statusColor(_ status: ReadinessDocumentStatus) -> Color {
        switch status {
        case .ready: return JourneyVisual.lime
        case .expiring: return .orange
        case .expired: return .red
        case .missing: return .white.opacity(0.42)
        }
    }
}
