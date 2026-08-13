import SwiftUI
import UIKit

struct MarketplaceProDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    let dashboard: MarketplaceProDashboard?
    let listings: [ServiceListing]
    let onPromoted: (ServiceListing) -> Void
    @State private var promotingID: String?
    @State private var error: String?
    @State private var copiedReply: String?
    @State private var selectedConversation: ChatConversation?
    @State private var showAppointments = false
    @State private var quickReplies = ["Дякую за запит. Коли вам зручно?", "Так, пропозиція ще актуальна.", "Надішліть, будь ласка, більше деталей."]
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 12)]
    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.market.rawValue, blurRadius: 10, darkness: 0.8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        LazyVGrid(columns: columns, spacing: 12) {
                            metric("Перегляди", dashboard?.totalViews ?? listings.reduce(0) { $0 + $1.viewCount }, "eye.fill")
                            metric("Запити", dashboard?.inquiries ?? 0, "bubble.left.and.bubble.right.fill")
                            metric("Активні", dashboard?.activeListings ?? listings.filter { $0.status == .approved }.count, "checkmark.seal.fill")
                            metric("Ліміт", dashboard?.publicationLimit ?? 20, "doc.badge.plus")
                        }
                        Button { showAppointments = true } label: {
                            HStack(spacing: 13) {
                                Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(.black).frame(width: 48, height: 48).background(JourneyVisual.lime).clipShape(RoundedRectangle(cornerRadius: 15))
                                VStack(alignment: .leading, spacing: 3) { Text("Календар бронювань").font(.headline); Text("Зустрічі, нагадування й статуси клієнтів").font(.caption).foregroundStyle(.white.opacity(0.58)) }
                                Spacer(); Image(systemName: "arrow.right")
                            }.foregroundStyle(.white).padding(15).background(.black.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 19))
                        }.buttonStyle(.plain)
                        section("Просування на 7 днів")
                        ForEach(listings.filter { $0.status == .approved }) { item in
                            HStack { VStack(alignment: .leading, spacing: 4) { Text(item.title).font(.headline).foregroundStyle(.white); Text(item.isFeatured ? "Просувається" : "Готове до просування").font(.caption).foregroundStyle(item.isFeatured ? JourneyVisual.lime : .white.opacity(0.5)) }; Spacer(); Button(item.isFeatured ? "Активне" : "Підняти") { Task { await promote(item) } }.buttonStyle(.borderedProminent).tint(JourneyVisual.lime).foregroundStyle(.black).disabled(item.isFeatured || promotingID != nil) }.padding(15).background(.black.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        section("Швидкі відповіді")
                        ForEach(quickReplies, id: \.self) { reply in Button { UIPasteboard.general.string = reply; copiedReply = reply; UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: { HStack { Text(reply).multilineTextAlignment(.leading); Spacer(); Image(systemName: copiedReply == reply ? "checkmark" : "doc.on.doc") }.foregroundStyle(copiedReply == reply ? JourneyVisual.lime : .white).padding(15).background(.black.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain) }
                        section("Клієнти")
                        if dashboard?.clients.isEmpty != false { Text("Нові звернення з оголошень з’являться тут.").foregroundStyle(.white.opacity(0.55)).padding(.vertical, 20) }
                        ForEach(dashboard?.clients ?? []) { client in Button { Task { await openConversation(client.conversationID) } } label: { HStack { Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(JourneyVisual.lime); VStack(alignment: .leading) { Text(client.displayName).foregroundStyle(.white); Text(client.listingTitle).font(.caption).foregroundStyle(.white.opacity(0.5)) }; Spacer(); Image(systemName: "message.fill").foregroundStyle(JourneyVisual.lime) }.padding(14).background(.black.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 17)) }.buttonStyle(.plain) }
                    }.padding(18).padding(.bottom, 30)
                }
            }.navigationTitle("Marketplace Pro").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } } }.alert("Marketplace Pro", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
                .sheet(isPresented: $showAppointments) { NavigationStack { AppointmentsView() }.environmentObject(appContainer.appointmentRepository) }
                .fullScreenCover(item: $selectedConversation) { ChatConversationView(conversation: $0).environmentObject(appContainer) }
        }
    }
    private var header: some View { VStack(alignment: .leading, spacing: 8) { Text("PLUS PRO").font(.caption.bold()).tracking(2).foregroundStyle(JourneyVisual.lime); Text("Твій бізнес у Sweezy").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white); Text("Реальні показники, клієнти й інструменти продажу.").foregroundStyle(.white.opacity(0.6)) } }
    private func section(_ title: String) -> some View { Text(title).font(.title3.bold()).foregroundStyle(.white).padding(.top, 4) }
    private func metric(_ title: String, _ value: Int, _ icon: String) -> some View { VStack(alignment: .leading, spacing: 8) { Image(systemName: icon).foregroundStyle(JourneyVisual.lime); Text("\(value)").font(.title.bold()).foregroundStyle(.white); Text(title).font(.caption).foregroundStyle(.white.opacity(0.55)) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.black.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 19)) }
    private func promote(_ listing: ServiceListing) async { promotingID = listing.id; defer { promotingID = nil }; do { onPromoted(try await APIClient.promoteListing(id: listing.id)) } catch { self.error = error.localizedDescription } }
    @MainActor private func openConversation(_ id: String) async { do { selectedConversation = try await ChatAPI.conversation(id: id) } catch { self.error = error.localizedDescription } }
}
