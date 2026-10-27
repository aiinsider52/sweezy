import MapKit
import SwiftUI

struct BusinessPageTarget: Identifiable, Hashable {
    let id: String
}

/// Public page of a business, specialist or club: trust signals first, then actions, offers, services and reviews.
struct BusinessPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager

    let businessID: String

    @State private var profile: PublicBusinessProfile?
    @State private var isLoading = true
    @State private var notFound = false
    @State private var bookingService: BusinessServiceItem?
    @State private var showReviewComposer = false
    @State private var reviewEligibility: BusinessReviewEligibility?
    @State private var nestedBusiness: BusinessPageTarget?
    @State private var conversation: ChatConversation?
    @State private var showAuth = false
    @State private var notice: String?
    @State private var copiedCode: String?
    @State private var joiningClub = false

    var body: some View {
        ZStack(alignment: .top) {
            JourneyVisual.pageBackground.ignoresSafeArea()
            if let profile {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        cover(profile)
                        VStack(alignment: .leading, spacing: 22) {
                            identity(profile)
                            actionBar(profile)
                            if !(profile.offers ?? []).isEmpty { offersSection(profile) }
                            if !profile.services.isEmpty { servicesSection(profile) }
                            aboutSection(profile)
                            if !(profile.photoURLs ?? []).isEmpty { gallery(profile) }
                            if profile.businessKind == .club { membersSection(profile) }
                            if !(profile.clubs ?? []).isEmpty { clubsSection(profile) }
                            reviewsSection(profile)
                            if let coordinate = coordinate(profile) { mapSection(profile, coordinate: coordinate) }
                            if let impressum = profile.impressum, !impressum.isEmpty { impressumSection(impressum) }
                            if profile.isSponsored == true {
                                Text("business.sponsored.explainer".localized)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(JourneyVisual.secondaryText)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, -34)
                        .padding(.bottom, 48)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else if isLoading {
                ProgressView().tint(JourneyVisual.accentText).frame(maxHeight: .infinity)
            } else {
                MascotEmptyState(
                    title: notFound ? "business.page.not_found".localized : "business.directory.error_title".localized,
                    subtitle: notFound ? "business.page.not_found_subtitle".localized : "business.directory.error_subtitle".localized,
                    actionTitle: "common.close".localized,
                    spot: notFound ? .noResults : .offline,
                    action: { dismiss() }
                )
                .padding(24)
                .frame(maxHeight: .infinity)
            }
            topBar
        }
        .statusBarScrim()
        .task { await load() }
        .sheet(item: $bookingService) { service in
            if let profile {
                BusinessBookingFlow(profile: profile, listingID: service.listingID ?? "", preferredServiceID: service.id)
            }
        }
        .sheet(isPresented: $showReviewComposer) {
            if let profile {
                BusinessReviewComposer(business: profile, existing: reviewEligibility?.existing) { _ in
                    Task { await load() }
                }
            }
        }
        .fullScreenCover(item: $nestedBusiness) { target in
            BusinessPageView(businessID: target.id)
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
        .fullScreenCover(item: $conversation) { ChatConversationView(conversation: $0).environmentObject(appContainer) }
        .sheet(isPresented: $showAuth) {
            AuthEntryView(showsCloseButton: true) { showAuth = false }
                .environment(\.locale, appContainer.currentLocale)
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
        .alert("Sweezy", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("common.ok".localized) { notice = nil }
        } message: { Text(notice ?? "") }
        .accessibilityIdentifier("business.page")
    }

    // MARK: Header

    private var topBar: some View {
        HStack {
            circleButton("xmark", label: "common.close".localized) { dismiss() }
            Spacer()
            if let profile {
                ShareLink(item: shareText(profile)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(JourneyVisual.primaryText)
                        .frame(width: 44, height: 44)
                        .background(JourneyVisual.chrome, in: Circle())
                        .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
                }
                .simultaneousGesture(TapGesture().onEnded { BusinessProAPI.track(.share, businessID: businessID) })
                .accessibilityLabel("common.share".localized)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(JourneyVisual.primaryText)
                .frame(width: 44, height: 44)
                .background(JourneyVisual.chrome, in: Circle())
                .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func cover(_ profile: PublicBusinessProfile) -> some View {
        let raw = profile.coverURL ?? profile.photoURLs?.first
        ZStack(alignment: .bottom) {
            JourneyRemoteImage(url: raw.flatMap(APIClient.resolveMediaURL), fallbackAsset: profile.businessCategory.coverAsset)
                .frame(height: 250)
                .frame(maxWidth: .infinity)
                .clipped()
            LinearGradient(colors: [JourneyVisual.pageBackground.opacity(0), JourneyVisual.pageBackground], startPoint: .top, endPoint: .bottom)
                .frame(height: 110)
        }
        .frame(height: 250)
    }

    private func identity(_ profile: PublicBusinessProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BusinessAvatar(logoURL: profile.logoURL, name: profile.displayName, category: profile.businessCategory, size: 76)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
            HStack(spacing: 8) {
                BusinessPill(title: profile.businessKind.title, icon: profile.businessKind.icon)
                BusinessPill(title: profile.businessCategory.title, icon: profile.businessCategory.icon)
                if profile.isSponsored == true { BusinessSponsoredBadge() }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(profile.displayName)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if profile.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(JourneyVisual.accentStrong)
                        .accessibilityLabel("map.verified".localized)
                }
            }
            if let tagline = profile.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
            }
            HStack(spacing: 12) {
                BusinessRatingLabel(rating: profile.averageRating, count: profile.reviewCount)
                Label(profile.address ?? profile.city, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(JourneyVisual.secondaryText)
                    .lineLimit(1)
            }
            if profile.languages.contains(where: { $0.lowercased() == "uk" }) {
                Label("business.speaks_ukrainian".localized, systemImage: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(JourneyVisual.accentText)
            }
        }
    }

    // MARK: Actions

    private func actionBar(_ profile: PublicBusinessProfile) -> some View {
        let actions = availableActions(profile)
        return VStack(spacing: 10) {
            if let first = profile.services.first {
                Button { book(first) } label: {
                    HStack {
                        Text("business.page.book".localized)
                        Spacer()
                        Image(systemName: "calendar.badge.plus")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
                .accessibilityIdentifier("business.page.book")
            }
            if !actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(actions, id: \.title) { action in
                        Button(action: action.run) {
                            VStack(spacing: 6) {
                                Image(systemName: action.icon).font(.system(size: 17, weight: .bold))
                                Text(action.title).font(.system(size: 11, weight: .bold)).lineLimit(1)
                            }
                            .foregroundStyle(JourneyVisual.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .businessCard()
                        }
                        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.96, hapticStyle: .light))
                    }
                }
            }
        }
    }

    private struct PageAction {
        let title: String
        let icon: String
        let run: () -> Void
    }

    private func availableActions(_ profile: PublicBusinessProfile) -> [PageAction] {
        var result: [PageAction] = []
        if let phone = profile.phone, let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
            result.append(PageAction(title: "business.page.call".localized, icon: "phone.fill") {
                BusinessProAPI.track(.call, businessID: businessID)
                openURL(url)
            })
        }
        if profile.services.contains(where: { $0.listingID != nil }) {
            result.append(PageAction(title: "business.page.message".localized, icon: "bubble.left.fill") {
                Task { await message(profile) }
            })
        } else if let telegram = socialURL("telegram", profile) {
            result.append(PageAction(title: "Telegram", icon: "paperplane.fill") {
                BusinessProAPI.track(.message, businessID: businessID)
                openURL(telegram)
            })
        }
        if let coordinate = coordinate(profile) {
            result.append(PageAction(title: "business.page.route".localized, icon: "arrow.triangle.turn.up.right.diamond.fill") {
                BusinessProAPI.track(.route, businessID: businessID)
                let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                item.name = profile.displayName
                item.openInMaps()
            })
        }
        if let website = profile.website.flatMap(URL.init(string:)) {
            result.append(PageAction(title: "business.page.website".localized, icon: "safari.fill") {
                BusinessProAPI.track(.website, businessID: businessID)
                openURL(website)
            })
        }
        return Array(result.prefix(4))
    }

    // MARK: Sections

    private func offersSection(_ profile: PublicBusinessProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BusinessSectionHeader(title: "business.page.offers".localized)
            ForEach(profile.offers ?? []) { offer in
                Button {
                    BusinessProAPI.track(.offer, businessID: businessID)
                    if let code = offer.promoCode, !code.isEmpty {
                        UIPasteboard.general.string = code
                        copiedCode = code
                    }
                } label: {
                    BusinessOfferTicket(offer: offer)
                }
                .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
                .accessibilityHint(offer.promoCode == nil ? "" : "business.offer.copy_hint".localized)
            }
            if let copiedCode {
                Label("business.offer.copied".localized(with: copiedCode), systemImage: "doc.on.doc.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(JourneyVisual.accentText)
                    .transition(.opacity)
            }
        }
    }

    private func servicesSection(_ profile: PublicBusinessProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BusinessSectionHeader(title: "business.page.services".localized, trailing: "\(profile.services.count)")
            ForEach(profile.services) { service in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(JourneyVisual.primaryText)
                        if !service.description.isEmpty {
                            Text(service.description)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(JourneyVisual.secondaryText)
                                .lineLimit(2)
                        }
                        Text("business.page.service_meta".localized(with: service.durationMinutes, service.priceText))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(JourneyVisual.accentText)
                    }
                    Spacer()
                    Button { book(service) } label: {
                        Text("business.page.book_short".localized)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(JourneyVisual.lime, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .businessCard()
            }
        }
    }

    private func aboutSection(_ profile: PublicBusinessProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BusinessSectionHeader(title: "business.page.about".localized)
            Text(profile.description)
                .font(.system(size: 15))
                .foregroundStyle(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 9) {
                infoRow("globe", "business.page.languages".localized, profile.languages.map { $0.uppercased() }.joined(separator: " · "))
                if !profile.deliveryModes.isEmpty {
                    infoRow("figure.walk", "business.page.format".localized, profile.deliveryModes.map { "business.delivery.\($0)".localized }.joined(separator: " · "))
                }
                if let hours = profile.openingHoursNote, !hours.isEmpty { infoRow("clock.fill", "business.page.hours".localized, hours) }
                if let policy = profile.cancellationPolicy, !policy.isEmpty { infoRow("arrow.uturn.backward.circle.fill", "business.page.cancellation".localized, policy) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .businessCard()
            let socials = socialEntries(profile)
            if !socials.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(socials, id: \.0) { name, url in
                            Button {
                                BusinessProAPI.track(.website, businessID: businessID)
                                openURL(url)
                            } label: {
                                BusinessPill(title: name.capitalized, icon: "link")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func infoRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(JourneyVisual.accentText)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(JourneyVisual.secondaryText)
                Text(value).font(.system(size: 14, weight: .medium)).foregroundStyle(JourneyVisual.primaryText)
            }
        }
    }

    private func gallery(_ profile: PublicBusinessProfile) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(profile.photoURLs ?? [], id: \.self) { raw in
                    JourneyRemoteImage(url: APIClient.resolveMediaURL(raw), fallbackAsset: profile.businessCategory.coverAsset)
                        .frame(width: 220, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .scrollClipDisabled()
        .accessibilityLabel("business.page.photos".localized)
    }

    private func membersSection(_ profile: PublicBusinessProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BusinessSectionHeader(title: "business.page.members".localized, trailing: "\(profile.members?.count ?? 0)")
            if let members = profile.members, !members.isEmpty {
                ForEach(members) { member in
                    BusinessDirectoryCard(business: member) { nestedBusiness = BusinessPageTarget(id: member.userID) }
                }
            } else {
                Text("business.page.members_empty".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(JourneyVisual.secondaryText)
            }
            Button { Task { await joinClub() } } label: {
                HStack {
                    if joiningClub { ProgressView().tint(.black) }
                    Text("business.club.join".localized)
                    Spacer()
                    Image(systemName: "person.badge.plus")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(JourneyVisual.primaryText)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .businessCard(stroke: JourneyVisual.lime.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(joiningClub)
        }
    }

    private func clubsSection(_ profile: PublicBusinessProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BusinessSectionHeader(title: "business.page.clubs".localized)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(profile.clubs ?? []) { club in
                        Button { nestedBusiness = BusinessPageTarget(id: club.userID) } label: {
                            HStack(spacing: 8) {
                                BusinessAvatar(logoURL: club.logoURL, name: club.displayName, category: .community, size: 30)
                                Text(club.displayName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(JourneyVisual.primaryText)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 46)
                            .businessCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func reviewsSection(_ profile: PublicBusinessProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BusinessSectionHeader(title: "business.page.reviews".localized)
                BusinessRatingLabel(rating: profile.averageRating, count: profile.reviewCount)
            }
            ForEach(profile.reviews ?? []) { review in
                BusinessReviewRow(review: review)
            }
            if (profile.reviews ?? []).isEmpty {
                Text("business.reviews.empty".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(JourneyVisual.secondaryText)
            }
            Button { Task { await startReview() } } label: {
                Label("business.reviews.write".localized, systemImage: "square.and.pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .businessCard()
            }
            .buttonStyle(.plain)
        }
    }

    private func mapSection(_ profile: PublicBusinessProfile, coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BusinessSectionHeader(title: "business.page.location".localized)
            Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                Marker(profile.displayName, systemImage: profile.businessCategory.icon, coordinate: coordinate)
                    .tint(JourneyVisual.accentStrong)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .allowsHitTesting(false)
            if let address = profile.address {
                Text(address)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(JourneyVisual.secondaryText)
            }
        }
    }

    private func impressumSection(_ impressum: BusinessImpressum) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach([impressum.legalName, impressum.representedBy.map { "business.impressum.represented".localized(with: $0) }, impressum.address, impressum.uidNumber.map { "UID: \($0)" }, impressum.email, impressum.phone].compactMap { $0 }.filter { !$0.isEmpty }, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 12))
                        .foregroundStyle(JourneyVisual.secondaryText)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        } label: {
            Text("business.impressum.title".localized)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(JourneyVisual.primaryText)
        }
        .tint(JourneyVisual.secondaryText)
        .padding(14)
        .businessCard()
    }

    // MARK: Logic

    private func load() async {
        do {
            if let loaded = try await BusinessProAPI.publicProfile(userID: businessID) {
                let firstLoad = profile == nil
                profile = loaded
                if firstLoad { BusinessProAPI.track(.view, businessID: businessID) }
            } else {
                notFound = true
            }
        } catch {
            notFound = false
        }
        isLoading = false
    }

    private func book(_ service: BusinessServiceItem) {
        guard sessionManager.isAuthenticated else { showAuth = true; return }
        BusinessProAPI.track(.booking, businessID: businessID)
        bookingService = service
    }

    private func message(_ profile: PublicBusinessProfile) async {
        guard sessionManager.isAuthenticated else { showAuth = true; return }
        guard let listingID = profile.services.compactMap(\.listingID).first else { return }
        BusinessProAPI.track(.message, businessID: businessID)
        do {
            conversation = try await ChatAPI.createConversation(listingID: listingID)
        } catch {
            notice = error.localizedDescription
        }
    }

    private func startReview() async {
        guard sessionManager.isAuthenticated else { showAuth = true; return }
        do {
            let eligibility = try await BusinessProAPI.reviewEligibility(businessID: businessID)
            reviewEligibility = eligibility
            if eligibility.canReview {
                showReviewComposer = true
            } else {
                notice = "business.reviews.\(eligibility.reason ?? "review_requires_visit")".localized
            }
        } catch {
            notice = error.localizedDescription
        }
    }

    private func joinClub() async {
        guard sessionManager.isAuthenticated else { showAuth = true; return }
        joiningClub = true
        defer { joiningClub = false }
        do {
            let membership = try await BusinessProAPI.joinClub(clubUserID: businessID)
            notice = membership.status == "approved" ? "business.club.already_member".localized : "business.club.request_sent".localized
        } catch {
            notice = (error as NSError).code == 404 ? "business.club.needs_business".localized : error.localizedDescription
        }
    }

    private func coordinate(_ profile: PublicBusinessProfile) -> CLLocationCoordinate2D? {
        guard let latitude = profile.latitude, let longitude = profile.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func socialURL(_ key: String, _ profile: PublicBusinessProfile) -> URL? {
        guard let raw = profile.socialLinks?[key], !raw.isEmpty else { return nil }
        if raw.hasPrefix("https://") { return URL(string: raw) }
        let handle = raw.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
        switch key {
        case "telegram": return URL(string: "https://t.me/\(handle)")
        case "instagram": return URL(string: "https://instagram.com/\(handle)")
        case "tiktok": return URL(string: "https://www.tiktok.com/@\(handle)")
        case "facebook": return URL(string: "https://facebook.com/\(handle)")
        case "linkedin": return URL(string: "https://www.linkedin.com/in/\(handle)")
        case "youtube": return URL(string: "https://youtube.com/@\(handle)")
        case "whatsapp": return URL(string: "https://wa.me/\(handle.filter(\.isNumber))")
        default: return nil
        }
    }

    private func socialEntries(_ profile: PublicBusinessProfile) -> [(String, URL)] {
        (profile.socialLinks ?? [:]).keys.sorted().compactMap { key in socialURL(key, profile).map { (key, $0) } }
    }

    private func shareText(_ profile: PublicBusinessProfile) -> String {
        "business.page.share_text".localized(with: profile.displayName, profile.city)
    }
}

struct BusinessReviewRow: View {
    let review: BusinessReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.authorName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(JourneyVisual.primaryText)
                Spacer()
                Text(String(repeating: "★", count: review.rating) + String(repeating: "☆", count: 5 - review.rating))
                    .font(.system(size: 13))
                    .foregroundStyle(JourneyCategoryPalette.sand.ink)
                    .accessibilityLabel("business.review.stars".localized(with: review.rating))
            }
            if !review.text.isEmpty {
                Text(review.text)
                    .font(.system(size: 14))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(review.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 11))
                .foregroundStyle(JourneyVisual.secondaryText)
            if let reply = review.ownerReply, !reply.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("business.reviews.owner_reply".localized)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(JourneyVisual.accentText)
                    Text(reply)
                        .font(.system(size: 13))
                        .foregroundStyle(JourneyVisual.primaryText)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(JourneyVisual.softSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .businessCard()
    }
}

struct BusinessReviewComposer: View {
    @Environment(\.dismiss) private var dismiss
    let business: PublicBusinessProfile
    let existing: BusinessReview?
    let onSaved: (BusinessReview) -> Void

    @State private var rating = 5
    @State private var text = ""
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyVisual.pageBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            BusinessAvatar(logoURL: business.logoURL, name: business.displayName, category: business.businessCategory, size: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(business.displayName).font(.system(size: 17, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                                Text("business.reviews.composer_hint".localized).font(.system(size: 12)).foregroundStyle(JourneyVisual.secondaryText)
                            }
                        }
                        BusinessStarPicker(rating: $rating)
                            .frame(maxWidth: .infinity)
                        TextField("business.reviews.placeholder".localized, text: $text, axis: .vertical)
                            .lineLimit(4...10)
                            .padding(14)
                            .foregroundStyle(JourneyVisual.primaryText)
                            .businessCard()
                        if let errorMessage {
                            Text(errorMessage).font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyVisual.coral)
                        }
                        Button { Task { await save() } } label: {
                            ProSubmitLabel(title: existing == nil ? "business.reviews.publish".localized : "business.reviews.update".localized, working: working)
                        }
                        .buttonStyle(.plain)
                        .disabled(working)
                        Text("business.reviews.policy".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(JourneyVisual.secondaryText)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("business.reviews.write".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.close".localized) { dismiss() } } }
            .onAppear {
                if let existing { rating = existing.rating; text = existing.text }
            }
        }
    }

    private func save() async {
        working = true
        defer { working = false }
        do {
            let saved = try await BusinessProAPI.writeReview(businessID: business.userID, payload: BusinessReviewPayload(rating: rating, text: text))
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
