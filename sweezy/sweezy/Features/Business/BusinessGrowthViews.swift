import Charts
import SwiftUI

@MainActor
final class BusinessGrowthModel: ObservableObject {
    @Published var plan: BusinessPlanInfo?
    @Published var stats: BusinessStats?
    @Published var offers: [BusinessOffer] = []
    @Published var reviews: [BusinessReview] = []
    @Published var clubMembers: [BusinessClubMember] = []
    @Published var myClubs: [BusinessClubMember] = []
    @Published var statsDays = 30
    @Published var error: String?

    var tier: BusinessPlanTier { plan?.tier ?? .free }

    func load(isClub: Bool) async {
        async let planTask = BusinessProAPI.plan()
        async let statsTask = BusinessProAPI.stats(days: statsDays)
        async let offersTask = BusinessProAPI.offers()
        async let reviewsTask = BusinessProAPI.myReviews()
        async let clubsTask = BusinessProAPI.myClubs()
        plan = try? await planTask
        stats = try? await statsTask
        offers = (try? await offersTask) ?? offers
        reviews = (try? await reviewsTask) ?? reviews
        myClubs = (try? await clubsTask) ?? myClubs
        if isClub { clubMembers = (try? await BusinessProAPI.clubMembers()) ?? clubMembers }
    }

    func reloadStats() async {
        stats = try? await BusinessProAPI.stats(days: statsDays)
    }

    func saveOffer(_ payload: BusinessOfferPayload, editing: BusinessOffer?) async -> Bool {
        do {
            if let editing {
                let updated = try await BusinessProAPI.updateOffer(id: editing.id, payload: payload)
                if let index = offers.firstIndex(where: { $0.id == editing.id }) { offers[index] = updated }
            } else {
                offers.insert(try await BusinessProAPI.createOffer(payload), at: 0)
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func toggle(_ offer: BusinessOffer) async {
        let payload = BusinessOfferPayload(title: offer.title, description: offer.description, discountLabel: offer.discountLabel, promoCode: offer.promoCode, endsAt: offer.endsAt, isActive: !offer.isActive)
        _ = await saveOffer(payload, editing: offer)
    }

    func delete(_ offer: BusinessOffer) async {
        do {
            try await BusinessProAPI.deleteOffer(id: offer.id)
            offers.removeAll { $0.id == offer.id }
        } catch { self.error = error.localizedDescription }
    }

    func reply(to review: BusinessReview, text: String) async {
        do {
            let updated = try await BusinessProAPI.replyToReview(id: review.id, text: text)
            if let index = reviews.firstIndex(where: { $0.id == review.id }) { reviews[index] = updated }
        } catch { self.error = error.localizedDescription }
    }

    func decide(_ member: BusinessClubMember, approve: Bool) async {
        do {
            let updated = try await BusinessProAPI.reviewClubMember(id: member.id, approve: approve)
            if let index = clubMembers.firstIndex(where: { $0.id == member.id }) { clubMembers[index] = updated }
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: - Promotion tab

struct BusinessPromotionPanel: View {
    @ObservedObject var growth: BusinessGrowthModel
    @ObservedObject private var store = BusinessStoreManager.shared
    let profile: BusinessProfile
    let openPublicPage: () -> Void
    let openPlans: () -> Void
    let editProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            pageStatusCard
            statsCard
            boostCard
            planCard
        }
        .task { await store.load() }
    }

    private var pageStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                BusinessAvatar(logoURL: profile.logoURL, name: profile.displayName, category: BusinessCategory(rawValue: profile.category) ?? .other, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName).font(.system(size: 17, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                    Label(statusText, systemImage: statusIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(profile.status == "approved" ? JourneyVisual.accentText : .orange)
                }
                Spacer()
            }
            if profile.status == "rejected", let reason = profile.rejectionReason {
                Text(reason).font(.system(size: 13)).foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                Button(action: openPublicPage) {
                    Label("business.growth.open_page".localized, systemImage: "eye.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(JourneyVisual.lime, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(profile.status != "approved")
                .opacity(profile.status == "approved" ? 1 : 0.5)
                Button(action: editProfile) {
                    Label("business.growth.edit_page".localized, systemImage: "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(JourneyVisual.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(JourneyVisual.softSurface, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .businessCard()
    }

    private var statusText: String {
        switch profile.status {
        case "approved": return "business.status.approved".localized
        case "pending": return "business.status.pending".localized
        case "rejected": return "business.status.rejected".localized
        case "suspended": return "business.status.suspended".localized
        default: return "business.status.draft".localized
        }
    }

    private var statusIcon: String {
        switch profile.status {
        case "approved": return "checkmark.seal.fill"
        case "pending": return "hourglass"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("business.growth.stats".localized).font(.system(size: 18, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                Spacer()
                Menu {
                    ForEach([7, 30, 90], id: \.self) { days in
                        Button("business.growth.days".localized(with: days)) {
                            growth.statsDays = days
                            Task { await growth.reloadStats() }
                        }
                    }
                } label: {
                    Label("business.growth.days".localized(with: growth.stats?.days ?? growth.statsDays), systemImage: "calendar")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(JourneyVisual.primaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(JourneyVisual.softSurface, in: Capsule())
                }
            }
            HStack(spacing: 10) {
                statTile("business.growth.views".localized, growth.stats?.views ?? 0, "eye.fill", JourneyCategoryPalette.sky)
                statTile("business.growth.actions".localized, growth.stats?.actions ?? 0, "hand.tap.fill", JourneyCategoryPalette.lime)
            }
            if let series = growth.stats?.series, series.contains(where: { $0.views + $0.actions > 0 }) {
                Chart(series) { day in
                    BarMark(x: .value("day", day.date, unit: .day), y: .value("views", day.views))
                        .foregroundStyle(JourneyCategoryPalette.sky.ink.opacity(0.75))
                    LineMark(x: .value("day", day.date, unit: .day), y: .value("actions", day.actions))
                        .foregroundStyle(JourneyVisual.accentStrong)
                        .interpolationMethod(.catmullRom)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 150)
                .accessibilityLabel("business.growth.chart".localized)
            } else {
                Text("business.growth.no_stats".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(JourneyVisual.secondaryText)
            }
            if let totals = growth.stats?.totals {
                HStack(spacing: 6) {
                    ForEach([("call", "phone.fill"), ("route", "map.fill"), ("website", "safari.fill"), ("booking", "calendar"), ("offer", "tag.fill")], id: \.0) { key, icon in
                        VStack(spacing: 3) {
                            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(JourneyVisual.accentText)
                            Text("\(totals[key] ?? 0)").font(.system(size: 14, weight: .black)).foregroundStyle(JourneyVisual.primaryText)
                            Text("business.metric.\(key)".localized).font(.system(size: 9, weight: .semibold)).foregroundStyle(JourneyVisual.secondaryText).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            if let stats = growth.stats, stats.maxDays < 90 {
                Button(action: openPlans) {
                    Label("business.growth.stats_locked".localized(with: stats.maxDays), systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(JourneyVisual.accentText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .businessCard()
    }

    private func statTile(_ title: String, _ value: Int, _ icon: String, _ swatch: JourneyCategorySwatch) -> some View {
        HStack(spacing: 10) {
            JourneyCategoryIcon(symbol: icon, swatch: swatch, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.system(size: 22, weight: .black)).foregroundStyle(JourneyVisual.primaryText)
                    .contentTransition(.numericText(value: Double(value)))
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(JourneyVisual.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(JourneyVisual.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var boostCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                JourneyCategoryIcon(symbol: "flame.fill", swatch: JourneyCategoryPalette.coral, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("business.boost.title".localized).font(.system(size: 17, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                    Text(boostSubtitle).font(.system(size: 12)).foregroundStyle(JourneyVisual.secondaryText)
                }
            }
            Text("business.boost.explainer".localized)
                .font(.system(size: 13))
                .foregroundStyle(JourneyVisual.secondaryText)
            Button { Task { await buyBoost() } } label: {
                HStack {
                    if store.purchasingProductID == BusinessStoreManager.ProductID.boost { ProgressView().tint(.black) }
                    Text(growth.plan?.isBoosted == true ? "business.boost.extend".localized : "business.boost.buy".localized)
                    Spacer()
                    Text(store.displayPrice(BusinessStoreManager.ProductID.boost, fallback: "—"))
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(profile.status != "approved" || store.purchasingProductID != nil)
            .opacity(profile.status == "approved" ? 1 : 0.5)
            if profile.status != "approved" {
                Text("business.boost.needs_approval".localized).font(.system(size: 11)).foregroundStyle(JourneyVisual.secondaryText)
            }
            if let error = store.lastError {
                Text(error).font(.system(size: 12, weight: .semibold)).foregroundStyle(JourneyVisual.coral)
            }
        }
        .padding(16)
        .businessCard(stroke: growth.plan?.isBoosted == true ? JourneyVisual.lime : JourneyVisual.softBorder)
    }

    private var boostSubtitle: String {
        if growth.plan?.isBoosted == true, let until = growth.plan?.boostUntil {
            return "business.boost.active_until".localized(with: until.formatted(date: .abbreviated, time: .shortened))
        }
        return "business.boost.inactive".localized
    }

    private var planCard: some View {
        Button(action: openPlans) {
            HStack(spacing: 12) {
                JourneyCategoryIcon(symbol: "crown.fill", swatch: JourneyCategoryPalette.sand, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("business.plan.current".localized(with: growth.tier.title)).font(.system(size: 16, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                    Text(planSubtitle).font(.system(size: 12)).foregroundStyle(JourneyVisual.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(JourneyVisual.secondaryText)
            }
            .padding(16)
            .businessCard()
        }
        .buttonStyle(.plain)
    }

    private var planSubtitle: String {
        if let expires = growth.plan?.planExpiresAt, growth.tier != .free {
            return "business.plan.renews".localized(with: expires.formatted(date: .abbreviated, time: .omitted))
        }
        return "business.plan.upgrade_hint".localized
    }

    private func buyBoost() async {
        if let plan = await store.purchase(BusinessStoreManager.ProductID.boost) {
            growth.plan = plan
        }
    }
}

// MARK: - Plans paywall

struct BusinessPlansView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject var growth: BusinessGrowthModel
    @ObservedObject private var store = BusinessStoreManager.shared

    private struct Feature: Identifiable {
        let key: String
        let values: [String]
        var id: String { key }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.pageBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            SweezyCompanion(pose: .celebrate, size: 96)
                            Text("business.plans.title".localized)
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(JourneyVisual.primaryText)
                            Text("business.plans.subtitle".localized)
                                .font(.system(size: 15))
                                .foregroundStyle(JourneyVisual.secondaryText)
                        }
                        planCard(.pro, productID: BusinessStoreManager.ProductID.pro, highlights: ["business.plans.pro.1", "business.plans.pro.2", "business.plans.pro.3", "business.plans.pro.4"])
                        planCard(.business, productID: BusinessStoreManager.ProductID.business, highlights: ["business.plans.business.1", "business.plans.business.2", "business.plans.business.3", "business.plans.business.4"])
                        comparison
                        if let error = store.lastError {
                            Text(error).font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyVisual.coral)
                        }
                        Button("business.plans.restore".localized) { Task { await store.restore(); await growth.load(isClub: false) } }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(JourneyVisual.accentText)
                        Text("business.plans.legal".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(JourneyVisual.secondaryText)
                        HStack(spacing: 16) {
                            Button("business.plans.terms".localized) { openURL(APIClient.url("legal/terms")) }
                            Button("business.plans.privacy".localized) { openURL(APIClient.url("legal/privacy")) }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(JourneyVisual.secondaryText)
                    }
                    .padding(20)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.close".localized) { dismiss() } } }
            .task { await store.load() }
        }
    }

    private func planCard(_ tier: BusinessPlanTier, productID: String, highlights: [String]) -> some View {
        let current = growth.tier == tier
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tier.title).font(.system(size: 22, weight: .black)).foregroundStyle(JourneyVisual.primaryText)
                if tier == .pro { BusinessPill(title: "business.plans.popular".localized, highlighted: true) }
                Spacer()
                Text("business.plans.per_month".localized(with: store.displayPrice(productID, fallback: "—")))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(JourneyVisual.primaryText)
            }
            ForEach(highlights, id: \.self) { key in
                Label(key.localized, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .symbolRenderingMode(.multicolor)
            }
            Button {
                Task {
                    if let plan = await store.purchase(productID) {
                        growth.plan = plan
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if store.purchasingProductID == productID { ProgressView().tint(.black) }
                    Text(current ? "business.plans.current_plan".localized : "business.plans.choose".localized(with: tier.title))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(current || store.purchasingProductID != nil)
            .opacity(current ? 0.55 : 1)
            .accessibilityIdentifier("business.plans.buy.\(tier.rawValue)")
        }
        .padding(18)
        .businessCard(stroke: tier == .pro ? JourneyVisual.lime : JourneyVisual.softBorder)
    }

    private var comparison: some View {
        let rows: [Feature] = [
            Feature(key: "business.plans.row.page", values: ["✓", "✓", "✓"]),
            Feature(key: "business.plans.row.services", values: ["3", "20", "50"]),
            Feature(key: "business.plans.row.offers", values: ["—", "5", "20"]),
            Feature(key: "business.plans.row.stats", values: ["7", "90", "365"]),
            Feature(key: "business.plans.row.priority", values: ["—", "✓", "✓✓"]),
            Feature(key: "business.plans.row.documents", values: ["—", "✓", "✓"]),
            Feature(key: "business.plans.row.ai", values: ["—", "—", "✓"]),
            Feature(key: "business.plans.row.team", values: ["—", "—", "10"])
        ]
        return VStack(spacing: 0) {
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(BusinessPlanTier.allCases) { tier in
                    Text(tier.title).font(.system(size: 12, weight: .black)).foregroundStyle(JourneyVisual.primaryText).frame(width: 64)
                }
            }
            .padding(.vertical, 10)
            ForEach(rows) { row in
                Divider().overlay(JourneyVisual.softBorder)
                HStack {
                    Text(row.key.localized).font(.system(size: 12, weight: .medium)).foregroundStyle(JourneyVisual.secondaryText).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(row.values.indices, id: \.self) { index in
                        Text(row.values[index]).font(.system(size: 13, weight: .bold)).foregroundStyle(JourneyVisual.primaryText).frame(width: 64)
                    }
                }
                .padding(.vertical, 9)
            }
        }
        .padding(.horizontal, 14)
        .businessCard()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Offers tab

struct BusinessOffersPanel: View {
    @ObservedObject var growth: BusinessGrowthModel
    let openPlans: () -> Void
    @State private var editing: BusinessOffer?
    @State private var creating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("business.offers.manage_title".localized).font(.system(size: 26, weight: .black)).foregroundStyle(JourneyVisual.primaryText)
                    Text("business.offers.manage_subtitle".localized).font(.system(size: 14)).foregroundStyle(JourneyVisual.secondaryText)
                }
                Spacer()
                if growth.tier >= .pro {
                    Button { creating = true } label: {
                        Image(systemName: "plus").font(.headline).foregroundStyle(.black).frame(width: 40, height: 40).background(JourneyVisual.lime, in: Circle())
                    }
                    .accessibilityLabel("business.offers.add".localized)
                }
            }
            if growth.tier < .pro {
                lockedCard
            } else if growth.offers.isEmpty {
                MascotEmptyState(title: "business.offers.empty_title".localized, subtitle: "business.offers.empty_subtitle".localized, pose: .celebrate, actionTitle: "business.offers.add".localized, action: { creating = true })
            }
            ForEach(growth.offers) { offer in
                VStack(alignment: .leading, spacing: 10) {
                    BusinessOfferTicket(offer: offer)
                        .opacity(offer.isActive ? 1 : 0.5)
                    HStack {
                        Toggle("business.offers.active".localized, isOn: Binding(get: { offer.isActive }, set: { _ in Task { await growth.toggle(offer) } }))
                            .tint(JourneyVisual.lime)
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Button("common.edit".localized) { editing = offer }.font(.system(size: 13, weight: .bold))
                        Button(role: .destructive) { Task { await growth.delete(offer) } } label: { Image(systemName: "trash") }
                            .accessibilityLabel("common.delete".localized)
                    }
                    .foregroundStyle(JourneyVisual.primaryText)
                }
            }
        }
        .sheet(isPresented: $creating) { BusinessOfferEditor(growth: growth, editing: nil) }
        .sheet(item: $editing) { BusinessOfferEditor(growth: growth, editing: $0) }
    }

    private var lockedCard: some View {
        Button(action: openPlans) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill").font(.title3).foregroundStyle(JourneyVisual.accentText)
                VStack(alignment: .leading, spacing: 3) {
                    Text("business.offers.locked_title".localized).font(.system(size: 15, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                    Text("business.offers.locked_subtitle".localized).font(.system(size: 12)).foregroundStyle(JourneyVisual.secondaryText).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundStyle(JourneyVisual.primaryText)
            }
            .padding(16)
            .businessCard(stroke: JourneyVisual.lime.opacity(0.5))
        }
        .buttonStyle(.plain)
    }
}

struct BusinessOfferEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var growth: BusinessGrowthModel
    let editing: BusinessOffer?
    @State private var payload = BusinessOfferPayload()
    @State private var hasEnd = false
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var working = false

    var body: some View {
        ProFormShell(title: editing == nil ? "business.offers.add".localized : "business.offers.edit".localized) {
            ProField("business.offers.field.label".localized, text: $payload.discountLabel)
            Text("business.offers.field.label_hint".localized).font(.system(size: 11)).foregroundStyle(JourneyVisual.secondaryText)
            ProField("business.offers.field.title".localized, text: $payload.title)
            ProTextArea("business.offers.field.description".localized, text: $payload.description, hint: "business.offers.field.description_hint".localized)
            ProField("business.offers.field.code".localized, text: Binding(get: { payload.promoCode ?? "" }, set: { payload.promoCode = $0.isEmpty ? nil : $0.uppercased() }))
            Toggle("business.offers.field.has_end".localized, isOn: $hasEnd).tint(JourneyVisual.lime).foregroundStyle(JourneyVisual.primaryText)
            if hasEnd {
                DatePicker("business.offers.field.ends".localized, selection: $endDate, in: Date()..., displayedComponents: .date)
                    .foregroundStyle(JourneyVisual.primaryText)
            }
            BusinessOfferTicket(offer: preview)
            if let error = growth.error { Text(error).font(.system(size: 13)).foregroundStyle(JourneyVisual.coral) }
            Button {
                working = true
                payload.endsAt = hasEnd ? endDate : nil
                Task {
                    if await growth.saveOffer(payload, editing: editing) { dismiss() }
                    working = false
                }
            } label: { ProSubmitLabel(title: "common.save".localized, working: working) }
                .disabled(payload.title.count < 2 || payload.discountLabel.isEmpty || working)
        }
        .onAppear {
            growth.error = nil
            if let editing {
                payload = BusinessOfferPayload(title: editing.title, description: editing.description, discountLabel: editing.discountLabel, promoCode: editing.promoCode, endsAt: editing.endsAt, isActive: editing.isActive)
                if let ends = editing.endsAt { hasEnd = true; endDate = ends }
            }
        }
    }

    private var preview: BusinessOffer {
        BusinessOffer(id: "preview", businessUserID: "", title: payload.title.isEmpty ? "business.offers.field.title".localized : payload.title, description: payload.description, discountLabel: payload.discountLabel.isEmpty ? "−10%" : payload.discountLabel, promoCode: payload.promoCode, endsAt: hasEnd ? endDate : nil, isActive: true, createdAt: Date(), business: nil)
    }
}

// MARK: - Reviews tab

struct BusinessReviewsPanel: View {
    @ObservedObject var growth: BusinessGrowthModel
    let profile: BusinessProfile
    @State private var replying: BusinessReview?
    @State private var replyText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("business.page.reviews".localized).font(.system(size: 26, weight: .black)).foregroundStyle(JourneyVisual.primaryText)
                BusinessRatingLabel(rating: profile.averageRating, count: profile.reviewCount ?? 0)
            }
            Text("business.reviews.owner_hint".localized).font(.system(size: 13)).foregroundStyle(JourneyVisual.secondaryText)
            if growth.reviews.isEmpty {
                MascotEmptyState(title: "business.reviews.owner_empty_title".localized, subtitle: "business.reviews.owner_empty_subtitle".localized, pose: .guide)
            }
            ForEach(growth.reviews) { review in
                VStack(alignment: .leading, spacing: 8) {
                    BusinessReviewRow(review: review)
                    if review.ownerReply == nil {
                        Button("business.reviews.reply".localized) { replying = review; replyText = "" }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(JourneyVisual.accentText)
                    }
                }
            }
        }
        .sheet(item: $replying) { review in
            ProFormShell(title: "business.reviews.reply".localized) {
                BusinessReviewRow(review: review)
                ProTextArea("business.reviews.reply".localized, text: $replyText, hint: "business.reviews.reply_hint".localized)
                Button {
                    Task {
                        await growth.reply(to: review, text: replyText)
                        replying = nil
                    }
                } label: { ProSubmitLabel(title: "business.reviews.reply_send".localized, working: false) }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - Club tab

struct BusinessClubPanel: View {
    @ObservedObject var growth: BusinessGrowthModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("business.club.manage_title".localized).font(.system(size: 26, weight: .black)).foregroundStyle(JourneyVisual.primaryText)
                Text("business.club.manage_subtitle".localized).font(.system(size: 14)).foregroundStyle(JourneyVisual.secondaryText)
            }
            let pending = growth.clubMembers.filter { $0.status == "pending" }
            let approved = growth.clubMembers.filter { $0.status == "approved" }
            if !pending.isEmpty {
                BusinessSectionHeader(title: "business.club.requests".localized, trailing: "\(pending.count)")
                ForEach(pending) { member in
                    VStack(alignment: .leading, spacing: 10) {
                        BusinessDirectoryCard(business: member.business) {}
                            .allowsHitTesting(false)
                        HStack {
                            Button("business.club.approve".localized) { Task { await growth.decide(member, approve: true) } }
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                                .padding(.horizontal, 16).frame(height: 38).background(JourneyVisual.lime, in: Capsule())
                            Button("business.club.reject".localized) { Task { await growth.decide(member, approve: false) } }
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                                .padding(.horizontal, 16).frame(height: 38).background(JourneyVisual.softSurface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            BusinessSectionHeader(title: "business.page.members".localized, trailing: "\(approved.count)")
            if approved.isEmpty {
                MascotEmptyState(title: "business.club.empty_title".localized, subtitle: "business.club.empty_subtitle".localized, pose: .people)
            }
            ForEach(approved) { member in
                BusinessDirectoryCard(business: member.business) {}
                    .allowsHitTesting(false)
            }
        }
    }
}

struct BusinessMyClubsCard: View {
    let memberships: [BusinessClubMember]

    var body: some View {
        if !memberships.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("business.page.clubs".localized).font(.system(size: 17, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                ForEach(memberships) { membership in
                    HStack(spacing: 10) {
                        BusinessAvatar(logoURL: membership.business.logoURL, name: membership.business.displayName, category: .community, size: 34)
                        Text(membership.business.displayName).font(.system(size: 14, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                        Spacer()
                        BusinessPill(title: "business.club.status.\(membership.status)".localized, highlighted: membership.status == "approved")
                    }
                }
            }
            .padding(16)
            .businessCard()
        }
    }
}
