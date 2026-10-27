import CoreLocation
import PhotosUI
import SwiftUI

/// Five short steps from "what are you" to a page submitted for moderation.
/// Also used to edit an existing profile (`startsAtIntro == false`).
struct BusinessOnboardingFlow: View {
    @ObservedObject var model: BusinessProViewModel
    var startsAtIntro = true
    var onFinished: (() -> Void)?

    @State private var step: Step = .intro
    @State private var payload = BusinessProfilePayload()
    @State private var country: ResidenceCountry = ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland
    @State private var telegram = ""
    @State private var instagram = ""
    @State private var working = false
    @State private var uploading: ImageSlot?
    @State private var logoItem: PhotosPickerItem?
    @State private var coverItem: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var reaction = 0

    private enum Step: Int, CaseIterable {
        case intro, identity, story, place, contacts, review
    }

    private enum ImageSlot { case logo, cover }

    private static let languageOptions = ["uk", "de", "en", "ru", "fr", "it", "pl"]

    var body: some View {
        VStack(spacing: 0) {
            if step != .intro { progress }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case .intro: intro
                    case .identity: identity
                    case .story: story
                    case .place: place
                    case .contacts: contacts
                    case .review: review
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(JourneyVisual.coral)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollDismissesKeyboard(.interactively)
            if step != .intro { footer }
        }
        .background(JourneyVisual.pageBackground.ignoresSafeArea())
        .onAppear(perform: prefill)
        .onChange(of: logoItem) { _, item in upload(item, slot: .logo) }
        .onChange(of: coverItem) { _, item in upload(item, slot: .cover) }
    }

    // MARK: Chrome

    private var progress: some View {
        let steps = Step.allCases.count - 1
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("business.onboarding.step".localized(with: step.rawValue, steps))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(JourneyVisual.secondaryText)
                Spacer()
            }
            GeometryReader { geometry in
                Capsule().fill(JourneyVisual.softBorder)
                    .overlay(alignment: .leading) {
                        Capsule().fill(JourneyVisual.lime)
                            .frame(width: geometry.size.width * CGFloat(step.rawValue) / CGFloat(steps))
                    }
            }
            .frame(height: 6)
            .animation(.snappy, value: step)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { move(-1) } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .frame(width: 56, height: 56)
                    .businessCard()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("business.onboarding.back".localized)
            Button { step == .review ? submit() : move(1) } label: {
                ProSubmitLabel(
                    title: step == .review ? submitTitle : "business.onboarding.next".localized,
                    working: working
                )
            }
            .buttonStyle(.plain)
            .disabled(!stepIsValid || working || uploading != nil)
            .opacity(stepIsValid ? 1 : 0.55)
            .accessibilityIdentifier("business.onboarding.next")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(JourneyVisual.chrome.ignoresSafeArea(edges: .bottom))
    }

    private var submitTitle: String {
        model.profile?.status == "approved" ? "business.onboarding.save".localized : "business.onboarding.submit".localized
    }

    // MARK: Steps

    private var intro: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Spacer()
                SweezyCompanion(pose: .welcome, size: 150, reaction: reaction)
                Spacer()
            }
            Text("business.onboarding.intro.eyebrow".localized)
                .font(.system(size: 12, weight: .black))
                .tracking(1.5)
                .foregroundStyle(JourneyVisual.accentText)
            Text("business.onboarding.intro.title".localized)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("business.onboarding.intro.subtitle".localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(JourneyVisual.secondaryText)
            VStack(spacing: 0) {
                benefit("storefront.fill", JourneyCategoryPalette.lime, "business.onboarding.benefit.page")
                benefit("magnifyingglass", JourneyCategoryPalette.sky, "business.onboarding.benefit.discovery")
                benefit("calendar.badge.clock", JourneyCategoryPalette.teal, "business.onboarding.benefit.bookings")
                benefit("chart.bar.xaxis", JourneyCategoryPalette.sand, "business.onboarding.benefit.stats")
            }
            .businessCard()
            Text("business.onboarding.intro.free".localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(JourneyVisual.secondaryText)
            Button { move(1) } label: {
                ProSubmitLabel(title: "business.onboarding.start".localized, working: false)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("business.onboarding.start")
        }
    }

    private func benefit(_ icon: String, _ swatch: JourneyCategorySwatch, _ key: String) -> some View {
        HStack(spacing: 14) {
            JourneyCategoryIcon(symbol: icon, swatch: swatch, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(key).title".localized).font(.system(size: 15, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                Text("\(key).subtitle".localized).font(.system(size: 12)).foregroundStyle(JourneyVisual.secondaryText)
            }
            Spacer()
        }
        .padding(14)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle("business.onboarding.identity.title", "business.onboarding.identity.subtitle")
            VStack(spacing: 10) {
                ForEach(BusinessKind.allCases) { kind in
                    let selected = payload.kind == kind.rawValue
                    Button {
                        payload.kind = kind.rawValue
                        if kind == .club { payload.category = BusinessCategory.community.rawValue }
                    } label: {
                        HStack(spacing: 14) {
                            JourneyCategoryIcon(symbol: kind.icon, swatch: kind.swatch, size: 46, selected: selected)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title).font(.system(size: 16, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                                Text(kind.subtitle).font(.system(size: 12)).foregroundStyle(JourneyVisual.secondaryText).multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selected ? JourneyVisual.accentStrong : JourneyVisual.softBorder)
                        }
                        .padding(14)
                        .background(selected ? JourneyVisual.lime.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .businessCard(stroke: selected ? JourneyVisual.lime : JourneyVisual.softBorder)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.lime, lineWidth: selected ? 2 : 0))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .light))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Text("business.onboarding.category".localized)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(JourneyVisual.secondaryText)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 98), spacing: 8)], spacing: 8) {
                ForEach(BusinessCategory.allCases) { category in
                    let selected = payload.category == category.rawValue
                    Button { payload.category = category.rawValue } label: {
                        VStack(spacing: 6) {
                            JourneyCategoryIcon(symbol: category.icon, swatch: category.swatch, size: 34, selected: selected)
                            Text(category.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(JourneyVisual.primaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 82)
                        .background(selected ? JourneyVisual.lime.opacity(0.2) : Theme.Colors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? JourneyVisual.lime : JourneyVisual.softBorder, lineWidth: selected ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var story: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("business.onboarding.story.title", "business.onboarding.story.subtitle")
            ProField("business.field.name".localized, text: $payload.displayName)
            ProField("business.field.tagline".localized, text: optional($payload.tagline))
            ProTextArea("business.field.description".localized, text: $payload.description, hint: "business.field.description_hint".localized)
            Text("business.onboarding.story.counter".localized(with: payload.description.count))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(payload.description.count >= 30 ? JourneyVisual.accentText : JourneyVisual.secondaryText)
        }
    }

    private var place: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("business.onboarding.place.title", "business.onboarding.place.subtitle")
            Picker("business.field.country".localized, selection: $country) {
                ForEach(ResidenceCountry.allCases) { item in Text("\(item.flag) \(item.nativeName)").tag(item) }
            }
            .pickerStyle(.segmented)
            .onChange(of: country) { _, value in
                payload.countryCode = value.rawValue
                payload.subdivisionCode = CountryCatalog.subdivisions(for: value).first?.code ?? payload.subdivisionCode
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(country.subdivisionTitle).font(.caption.bold()).foregroundStyle(JourneyVisual.secondaryText)
                Picker(country.subdivisionTitle, selection: $payload.subdivisionCode) {
                    ForEach(CountryCatalog.subdivisions(for: country)) { area in Text(area.name).tag(area.code) }
                }
                .pickerStyle(.menu)
                .tint(JourneyVisual.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .frame(height: 48)
                .businessCard()
            }
            ProField("business.field.city".localized, text: $payload.city)
            ProField("business.field.address".localized, text: optional($payload.address))
            Text("business.field.address_hint".localized)
                .font(.system(size: 11))
                .foregroundStyle(JourneyVisual.secondaryText)
            chipGroup(title: "business.field.languages".localized, options: Self.languageOptions, selection: $payload.languages) { $0.uppercased() }
            if payload.kind != BusinessKind.club.rawValue {
                chipGroup(title: "business.page.format".localized, options: ["onsite", "remote", "mobile"], selection: $payload.deliveryModes) { "business.delivery.\($0)".localized }
            }
            ProField("business.field.hours".localized, text: optional($payload.openingHoursNote))
        }
    }

    private var contacts: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("business.onboarding.contacts.title", "business.onboarding.contacts.subtitle")
            HStack(spacing: 12) {
                imagePicker(.logo, title: "business.field.logo".localized, url: payload.logoURL, selection: $logoItem)
                imagePicker(.cover, title: "business.field.cover".localized, url: payload.coverURL, selection: $coverItem)
            }
            ProField("business.field.phone".localized, text: optional($payload.phone), keyboard: .phonePad)
            ProField("Email", text: optional($payload.email), keyboard: .emailAddress)
            ProField("business.field.website".localized, text: optional($payload.website), keyboard: .URL)
            HStack(spacing: 10) {
                ProField("Telegram", text: $telegram)
                ProField("Instagram", text: $instagram)
            }
            Divider().overlay(JourneyVisual.softBorder)
            Text("business.impressum.title".localized)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(JourneyVisual.primaryText)
            Text("business.onboarding.impressum_hint".localized)
                .font(.system(size: 12))
                .foregroundStyle(JourneyVisual.secondaryText)
            ProField("business.field.legal_name".localized, text: optional($payload.legalName))
            ProField("business.field.represented_by".localized, text: optional($payload.representedBy))
            ProField("business.field.uid".localized, text: optional($payload.uidNumber))
        }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("business.onboarding.review.title", "business.onboarding.review.subtitle")
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    BusinessAvatar(logoURL: payload.logoURL, name: payload.displayName, category: BusinessCategory(rawValue: payload.category) ?? .other, size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(payload.displayName).font(.system(size: 18, weight: .bold)).foregroundStyle(JourneyVisual.primaryText)
                        Text(payload.tagline ?? (BusinessCategory(rawValue: payload.category) ?? .other).title)
                            .font(.system(size: 13))
                            .foregroundStyle(JourneyVisual.secondaryText)
                    }
                }
                HStack(spacing: 6) {
                    BusinessPill(title: (BusinessKind(rawValue: payload.kind) ?? .business).title, icon: (BusinessKind(rawValue: payload.kind) ?? .business).icon)
                    BusinessPill(title: payload.city, icon: "mappin")
                    if payload.languages.contains("uk") { BusinessPill(title: "business.speaks_ukrainian".localized, icon: "bubble.left.fill", highlighted: true) }
                }
                Text(payload.description)
                    .font(.system(size: 14))
                    .foregroundStyle(JourneyVisual.primaryText)
                    .lineLimit(5)
            }
            .padding(16)
            .businessCard(stroke: JourneyVisual.lime.opacity(0.5))
            Label("business.onboarding.review.moderation".localized, systemImage: "checkmark.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(JourneyVisual.secondaryText)
            if model.profile?.status == "rejected", let reason = model.profile?.rejectionReason {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(14)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: Pieces

    private func stepTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.localized)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle.localized)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(JourneyVisual.secondaryText)
        }
    }

    private func chipGroup(title: String, options: [String], selection: Binding<[String]>, label: @escaping (String) -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundStyle(JourneyVisual.secondaryText)
            FlowChips(options: options, selection: selection, label: label)
        }
    }

    private func imagePicker(_ slot: ImageSlot, title: String, url: String?, selection: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: selection, matching: .images) {
            ZStack {
                if let resolved = url.flatMap(APIClient.resolveMediaURL) {
                    JourneyRemoteImage(url: resolved, fallbackAsset: (BusinessCategory(rawValue: payload.category) ?? .other).coverAsset)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: slot == .logo ? "app.badge" : "photo.on.rectangle.angled")
                            .font(.system(size: 22, weight: .semibold))
                        Text(title).font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(JourneyVisual.secondaryText)
                }
                if uploading == slot {
                    Color.black.opacity(0.35)
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JourneyVisual.softBorder, style: StrokeStyle(lineWidth: 1, dash: url == nil ? [5] : [])))
        }
        .accessibilityLabel(title)
    }

    // MARK: Logic

    private var stepIsValid: Bool {
        switch step {
        case .intro: return true
        case .identity: return !payload.kind.isEmpty && !payload.category.isEmpty
        case .story: return payload.displayName.trimmingCharacters(in: .whitespaces).count >= 2 && payload.description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 30
        case .place: return payload.city.trimmingCharacters(in: .whitespaces).count >= 2 && !payload.languages.isEmpty && (payload.kind == BusinessKind.club.rawValue || !payload.deliveryModes.isEmpty)
        case .contacts: return [payload.phone, payload.email, payload.website].contains { !($0 ?? "").isEmpty } || !telegram.isEmpty || !instagram.isEmpty
        case .review: return true
        }
    }

    private func move(_ delta: Int) {
        errorMessage = nil
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        if next == .intro && !startsAtIntro {
            onFinished?()
            return
        }
        withAnimation(.snappy) { step = next }
    }

    private func prefill() {
        if let profile = model.profile {
            payload = BusinessProfilePayload(profile: profile)
            country = ResidenceCountry(rawValue: payload.countryCode) ?? country
            telegram = payload.socialLinks["telegram"] ?? ""
            instagram = payload.socialLinks["instagram"] ?? ""
        } else {
            payload.languages = ["uk", "de"]
            payload.deliveryModes = ["onsite"]
            payload.serviceArea = [payload.subdivisionCode]
        }
        if !startsAtIntro { step = .identity }
    }

    private func submit() {
        working = true
        errorMessage = nil
        payload.socialLinks["telegram"] = telegram.trimmingCharacters(in: .whitespaces).isEmpty ? nil : telegram.trimmingCharacters(in: .whitespaces)
        payload.socialLinks["instagram"] = instagram.trimmingCharacters(in: .whitespaces).isEmpty ? nil : instagram.trimmingCharacters(in: .whitespaces)
        payload.canton = payload.subdivisionCode
        if payload.serviceArea.isEmpty { payload.serviceArea = [payload.subdivisionCode] }
        if payload.kind == BusinessKind.club.rawValue && payload.deliveryModes.isEmpty { payload.deliveryModes = ["onsite"] }
        Task {
            await geocodeAddress()
            do {
                // The server moves a page back to draft only when its identity changed;
                // only then it needs another moderation pass.
                let saved = try await BusinessProAPI.saveProfile(payload)
                if saved.status == "draft" { _ = try await BusinessProAPI.submitProfile() }
                await model.load()
                reaction += 1
                onFinished?()
            } catch {
                errorMessage = error.localizedDescription
            }
            working = false
        }
    }

    /// Map pin for the directory; the address stays the source of truth if geocoding fails.
    private func geocodeAddress() async {
        let parts = [payload.address, payload.city, country.nativeName].compactMap { $0 }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return }
        if let placemark = try? await CLGeocoder().geocodeAddressString(parts.joined(separator: ", ")).first,
           let location = placemark.location {
            payload.latitude = location.coordinate.latitude
            payload.longitude = location.coordinate.longitude
        }
    }

    private func upload(_ item: PhotosPickerItem?, slot: ImageSlot) {
        guard let item else { return }
        uploading = slot
        Task {
            defer { uploading = nil }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpeg = image.businessResized(maxSide: slot == .logo ? 600 : 1600).jpegData(compressionQuality: 0.82) else { return }
                let url = try await APIClient.uploadMarketplaceImage(data: jpeg, filename: "business-\(slot == .logo ? "logo" : "cover").jpg")
                if slot == .logo { payload.logoURL = url } else { payload.coverURL = url }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func optional(_ binding: Binding<String?>) -> Binding<String> {
        Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}

/// Wrapping multi-select chips.
struct FlowChips: View {
    let options: [String]
    @Binding var selection: [String]
    let label: (String) -> String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = selection.contains(option)
                Button {
                    if selected { selection.removeAll { $0 == option } } else { selection.append(option) }
                } label: {
                    Text(label(option))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(selected ? Color.black : JourneyVisual.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(selected ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule())
                        .overlay(Capsule().stroke(selected ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

extension UIImage {
    func businessResized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
