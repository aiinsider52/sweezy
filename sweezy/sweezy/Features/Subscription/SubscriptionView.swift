import StoreKit
import SwiftUI
import UIKit

/// Where the paywall was opened from. Each trigger has its own case so the funnel shows which
/// moment sells, and the paywall headline speaks to what the person was just trying to do.
enum SubscriptionSource: String {
    case home
    case cv
    case profile
    case letters
    case careerKit = "career_kit"
    case interview
    case jobs
    case people
    case events
    case marketplace
    case discovery
    case guides
}

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var manager = SubscriptionManager.shared
    /// Annual is the default: it is the better deal, and it is what most people keep.
    @State private var selectedProductID = SubscriptionManager.ProductID.yearly
    @State private var purchaseSucceeded = false

    let source: SubscriptionSource

    init(source: SubscriptionSource = .profile) {
        self.source = source
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroStage
                    headline.padding(.top, 22)
                    benefits.padding(.top, 26)
                    plans.padding(.top, 28)
                    if hasSelectedFreeTrial {
                        trialTimeline
                            .padding(.top, 14)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    purchaseDetails.padding(.top, 16)
                    legalLinks.padding(.top, 10).padding(.bottom, 20)
                }
                .frame(width: geometry.size.width)
                .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86), value: selectedProductID)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .accessibilityIdentifier("subscription.paywall")
            .background(pageBackground)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar.background(pageBackground) }
        .safeAreaInset(edge: .bottom, spacing: 0) { stickyPurchaseButton }
        .background(pageBackground.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: selectedProductID)
        .task {
            APIClient.logPaywall(eventType: "view", context: source.rawValue)
            TelemetryService.current?.track(.paywallViewed, source: "paywall", meta: ["context": source.rawValue])
            await manager.load()
            // Fall back to monthly only if the yearly product is not on sale in this storefront.
            if manager.yearlyProduct == nil, manager.monthlyProduct != nil {
                selectedProductID = SubscriptionManager.ProductID.monthly
            }
        }
        .alert("Sweezy Plus", isPresented: $purchaseSucceeded) {
            Button("Готово".localized) { dismiss() }
        } message: {
            Text("Підписку активовано на всіх ваших пристроях Apple.".localized)
        }
    }

    private var pageBackground: Color { JourneyVisual.pageBackground }
    private var primaryText: Color { JourneyVisual.primaryText }
    private var secondaryText: Color { JourneyVisual.secondaryText }
    private var softBorder: Color { JourneyVisual.softBorder }
    private var readableAccent: Color { JourneyVisual.accentText }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                APIClient.logPaywall(eventType: "dismiss", context: source.rawValue)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(primaryText)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.card)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(softBorder, lineWidth: 1))
            }
            .accessibilityLabel("Закрити".localized)
            .accessibilityIdentifier("subscription.close")

            Spacer()

            Button {
                Task { await manager.restorePurchases() }
            } label: {
                Label("Відновити покупки".localized, systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(primaryText)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Theme.Colors.card)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(softBorder, lineWidth: 1))
            }
            .accessibilityIdentifier("subscription.restore")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    // MARK: - Hero

    /// Mascot celebrating on a lime stage, with the four things people buy Plus for
    /// pinned beside it as stickers. Decorative: the same facts are in the list below.
    private var heroStage: some View {
        JourneyMascotStage(
            pose: .celebrate,
            stickers: [
                JourneyStageSticker(icon: "envelope.open.fill", title: "paywall.sticker.letters".localized, swatch: JourneyCategoryPalette.lime),
                JourneyStageSticker(icon: "wand.and.stars", title: "paywall.sticker.career".localized, swatch: JourneyCategoryPalette.sky),
                JourneyStageSticker(icon: "doc.text.fill", title: "CV і листи".localized, swatch: JourneyCategoryPalette.sand),
                JourneyStageSticker(icon: "megaphone.fill", title: "paywall.sticker.promo".localized, swatch: JourneyCategoryPalette.coral)
            ]
        )
        .padding(.horizontal, 18)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("PLUS", systemImage: "sparkles")
                if let days = selectedTrialDays {
                    Text("paywall.trial.badge".localized(with: "\(days)"))
                }
            }
            .font(.system(size: 10, weight: .black))
            .foregroundColor(.black)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(JourneyVisual.lime)
            .clipShape(Capsule())

            if let pitch = contextualPitch {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pitch.title)
                        .font(.largeTitle.bold())
                        .foregroundColor(primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(pitch.subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let usage = usageNote {
                        Label(usage, systemImage: "hourglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(readableAccent)
                            .padding(.top, 2)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: -2) {
                    Text("\(selectedCountry.name).")
                        .foregroundColor(primaryText)
                    Text("Твій маршрут.".localized)
                        .foregroundColor(readableAccent)
                }
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)

                // Honest about what stays free: trust is what converts this audience.
                Text("paywall.default.subtitle".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Benefits

    /// Only what Plus really unlocks today (App Review 3.1.2: describe what people get).
    private var benefitItems: [PlusBenefit] {
        let items: [PlusBenefit?] = [
            PlusBenefit(icon: "envelope.open.fill", title: "paywall.benefit.letters".localized, text: "paywall.benefit.letters.text".localized, swatch: JourneyCategoryPalette.lime),
            PlusBenefit(icon: "wand.and.stars", title: "paywall.benefit.career".localized, text: selectedCountry.jobMarketPhrase, swatch: JourneyCategoryPalette.sky),
            PlusBenefit(icon: "doc.text.fill", title: "paywall.benefit.cv".localized, text: "paywall.benefit.cv.text".localized, swatch: JourneyCategoryPalette.sand),
            selectedCountry == .switzerland
                ? PlusBenefit(icon: "map.fill", title: "paywall.benefit.discovery".localized, text: "paywall.benefit.discovery.text".localized, swatch: JourneyCategoryPalette.teal)
                : nil,
            PlusBenefit(icon: "person.2.fill", title: "paywall.benefit.people".localized, text: "paywall.benefit.people.text".localized, swatch: JourneyCategoryPalette.coral),
            PlusBenefit(icon: "megaphone.fill", title: "paywall.benefit.market".localized, text: "paywall.benefit.market.text".localized, swatch: JourneyCategoryPalette.lilac)
        ]
        return items.compactMap { $0 }
    }

    private struct Pitch {
        let title: String
        let subtitle: String
    }

    /// Speak to what the person was just doing when the paywall opened.
    private var contextualPitch: Pitch? {
        switch source {
        case .letters:
            return Pitch(title: "paywall.pitch.letters.title".localized, subtitle: "paywall.pitch.letters.subtitle".localized)
        case .careerKit, .interview, .cv, .jobs:
            return Pitch(title: "paywall.pitch.career.title".localized, subtitle: "paywall.pitch.career.subtitle".localized)
        case .people, .events:
            return Pitch(title: "paywall.pitch.people.title".localized, subtitle: "paywall.pitch.people.subtitle".localized)
        case .discovery where selectedCountry == .switzerland:
            return Pitch(title: "paywall.pitch.discovery.title".localized, subtitle: "paywall.pitch.discovery.subtitle".localized)
        case .marketplace:
            return Pitch(title: "paywall.pitch.market.title".localized, subtitle: "paywall.pitch.market.subtitle".localized)
        case .home, .profile, .guides, .discovery:
            return nil
        }
    }

    /// "You've used all 3 free letter explanations", when that is why the paywall opened.
    private var usageNote: String? {
        let feature: String
        let limit: Int
        switch source {
        case .letters: feature = "letter_explain"; limit = 3
        case .careerKit: feature = "career_kit"; limit = 3
        case .interview: feature = "interview_turns"; limit = 14
        case .cv: feature = "cv_tools"; limit = 3
        default: return nil
        }
        guard let left = manager.freeUsesRemaining[feature], left == 0 else { return nil }
        return "paywall.usage.spent".localized(with: "\(limit)")
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Що відкриває Plus".localized)
                .font(.title3.bold())
                .foregroundColor(primaryText)

            VStack(spacing: 0) {
                ForEach(Array(benefitItems.enumerated()), id: \.offset) { index, item in
                    benefitRow(item)
                    if index < benefitItems.count - 1 {
                        Divider()
                            .overlay(softBorder)
                            .padding(.leading, 50)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(softBorder, lineWidth: 1))

            Label(
                "А ще чеклісти й база знань про життя %@".localized(with: selectedCountry.inCountryPhrase),
                systemImage: "plus.circle.fill"
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(secondaryText)
        }
        .padding(.horizontal, 22)
    }

    private func benefitRow(_ item: PlusBenefit) -> some View {
        HStack(spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize {
                JourneyCategoryIcon(symbol: item.icon, swatch: item.swatch, size: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundColor(primaryText)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.text)
                    .font(.caption)
                    .foregroundColor(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(JourneyVisual.accentStrong)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plans

    private var plans: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Обери план".localized)
                    .font(.title3.bold())
                    .foregroundColor(primaryText)
                Spacer(minLength: 8)
                Label("Оплата через Apple".localized, systemImage: "checkmark.shield.fill")
                    .font(.caption2.bold())
                    .foregroundColor(readableAccent)
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 14))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                planCard(
                    id: SubscriptionManager.ProductID.yearly,
                    title: "Щорічно".localized,
                    price: yearlyPrice,
                    period: "на рік".localized,
                    badge: yearlyBadge,
                    note: trialDays(for: SubscriptionManager.ProductID.yearly).map { "paywall.trial.days_free".localized(with: "\($0)") }
                        ?? "≈ %@ / міс".localized(with: "\(yearlyPerMonth)")
                )
                planCard(
                    id: SubscriptionManager.ProductID.monthly,
                    title: "Щомісячно".localized,
                    price: monthlyPrice,
                    period: "на місяць".localized,
                    badge: nil,
                    note: trialDays(for: SubscriptionManager.ProductID.monthly).map { "paywall.trial.days_free".localized(with: "\($0)") }
                        ?? "Без зобов’язань".localized
                )
            }
        }
        .padding(.horizontal, 22)
    }

    private func planCard(id: String, title: String, price: String, period: String, badge: String?, note: String) -> some View {
        let selected = selectedProductID == id
        return Button {
            selectedProductID = id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(primaryText)
                    Spacer(minLength: 6)
                    ZStack {
                        Circle()
                            .stroke(selected ? Color.clear : softBorder, lineWidth: 1.5)
                        if selected {
                            Circle().fill(JourneyVisual.lime)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.black)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: 22, height: 22)
                }
                .padding(.top, badge == nil ? 0 : 6)

                Text(price)
                    .font(.system(size: 22, weight: .black).monospacedDigit())
                    .foregroundColor(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 6)
                Text(period)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(secondaryText)
                Text(note)
                    .font(.caption2.bold())
                    .foregroundColor(readableAccent)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(selected ? JourneyVisual.lime.opacity(0.12) : Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? JourneyVisual.accentStrong : softBorder, lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .topLeading) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .frame(height: 20)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())
                        .offset(x: 12, y: -10)
                }
            }
            .scaleEffect(selected || reduceMotion ? 1 : 0.985)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("subscription.plan.\(id)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// What happens after "Start": said plainly, because trust is what converts a trial.
    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            trialStep(icon: "lock.open.fill", title: "Сьогодні".localized, text: "Повний доступ до Plus · 0 %@".localized(with: "\(selectedCountry.currencyCode)"), isLast: false)
            trialStep(icon: "calendar", title: "paywall.trial.after_days".localized(with: "\(selectedTrialDays ?? 0)"), text: "paywall.trial.then".localized(with: "\(selectedPlainPrice)"), isLast: false)
            trialStep(icon: "hand.raised.fill", title: "Будь-коли".localized, text: "Скасування в налаштуваннях Apple ID".localized, isLast: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(JourneyVisual.lime.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JourneyVisual.lime.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 22)
    }

    private func trialStep(icon: String, title: String, text: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 26, height: 26)
                    .background(JourneyVisual.lime)
                    .clipShape(Circle())
                if !isLast {
                    Rectangle()
                        .fill(JourneyVisual.lime.opacity(0.5))
                        .frame(width: 2, height: 18)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(primaryText)
                Text(text)
                    .font(.caption)
                    .foregroundColor(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var purchaseDetails: some View {
        VStack(spacing: 10) {
            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }

            Text("Підписка поновлюється автоматично. Скасувати можна будь-коли в налаштуваннях Apple ID.".localized)
                .font(.system(size: 11))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                trustItem("lock.fill", "Безпечна оплата".localized)
                trustItem("iphone.and.arrow.forward", "На всіх пристроях".localized)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
    }

    private func trustItem(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(secondaryText)
    }

    // MARK: - Purchase

    private var stickyPurchaseButton: some View {
        VStack(spacing: 0) {
            // Content fades out under the button instead of being cut by a hard line.
            LinearGradient(colors: [pageBackground.opacity(0), pageBackground], startPoint: .top, endPoint: .bottom)
                .frame(height: 18)
                .allowsHitTesting(false)

            Button {
                APIClient.logPaywall(eventType: "purchase_start", context: source.rawValue)
                Task {
                    if await manager.purchase(productID: selectedProductID) {
                        purchaseSucceeded = true
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    if manager.purchasingProductID != nil {
                        Spacer()
                        ProgressView().tint(.black)
                        Spacer()
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedTrialDays.map { "paywall.trial.cta".localized(with: "\($0)") } ?? "Продовжити з Plus".localized)
                                .font(.headline)
                                .contentTransition(.opacity)
                            Text(hasSelectedFreeTrial ? "paywall.trial.then".localized(with: "\(selectedPlainPrice)") : selectedPrice)
                                .font(.caption.weight(.semibold))
                                .opacity(0.72)
                                .contentTransition(.opacity)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .foregroundColor(.black)
                .padding(.leading, 20)
                .padding(.trailing, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: JourneyVisual.lime.opacity(0.35), radius: 14, y: 4)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
            .disabled(manager.purchasingProductID != nil)
            .accessibilityIdentifier("subscription.purchase")
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            .background(pageBackground)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var legalLinks: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 20))
        return layout {
            Link(destination: URL(string: "https://sweezy-api.onrender.com/legal/terms")!) {
                Text("Умови".localized).font(.subheadline).frame(minHeight: 44)
            }
            Link(destination: URL(string: "https://sweezy-api.onrender.com/legal/privacy")!) {
                Text("Конфіденційність".localized).font(.subheadline)
                    .lineLimit(1).minimumScaleFactor(0.8).frame(minHeight: 44)
            }
            .accessibilityIdentifier("subscription.privacy")
            Button("paywall.offer_code".localized) { manager.presentOfferCodeRedemption() }
                .font(.subheadline)
                .frame(minHeight: 44)
                .accessibilityIdentifier("subscription.offerCode")
        }
        .foregroundColor(secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
    }

    private var yearlyPrice: String {
        manager.displayPrice(for: SubscriptionManager.ProductID.yearly, fallback: yearlyFallbackPrice)
    }

    /// Yearly price spread over 12 months, in the store's own currency format.
    private var yearlyPerMonth: String {
        if let yearly = manager.yearlyProduct {
            return (yearly.price / 12).formatted(yearly.priceFormatStyle)
        }
        return selectedCountry == .switzerland ? "4.13 CHF" : "4.13 EUR"
    }

    /// Days of free trial the person can still get on a product (nil if none or not eligible).
    private func trialDays(for productID: String) -> Int? {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-screenshotTrial"), productID == SubscriptionManager.ProductID.yearly { return 14 }
#endif
        let eligible = productID == SubscriptionManager.ProductID.yearly ? manager.isYearlyTrialEligible : manager.isMonthlyTrialEligible
        guard eligible else { return nil }
        return manager.trialDays(for: productID)
    }

    private var selectedTrialDays: Int? { trialDays(for: selectedProductID) }

    private var hasSelectedFreeTrial: Bool { selectedTrialDays != nil }

    private var yearlyBadge: String {
        if let percent = manager.yearlySavingsPercent {
            return "paywall.yearly.save".localized(with: "\(percent)")
        }
        return "2 міс. у подарунок".localized
    }

    private var monthlyPrice: String {
        manager.displayPrice(for: SubscriptionManager.ProductID.monthly, fallback: monthlyFallbackPrice)
    }

    private var selectedPrice: String {
        selectedProductID == SubscriptionManager.ProductID.monthly
            ? "%@ / місяць".localized(with: "\(monthlyPrice)")
            : "%@ / рік".localized(with: "\(yearlyPrice)")
    }

    /// "49.90 CHF / рік" or "6.90 CHF / місяць" for the selected plan.
    private var selectedPlainPrice: String { selectedPrice }

    private var selectedCountry: ResidenceCountry {
        ResidenceCountry(rawValue: APIClient.countryCode) ?? .switzerland
    }

    private var monthlyFallbackPrice: String {
        selectedCountry == .switzerland ? "4.95 CHF" : "4.95 EUR"
    }

    private var yearlyFallbackPrice: String {
        selectedCountry == .switzerland ? "49.50 CHF" : "49.50 EUR"
    }
}

private struct PlusBenefit {
    let icon: String
    let title: String
    let text: String
    let swatch: JourneyCategorySwatch
}

struct SweezyPlusHomeCard: View {
    @StateObject private var manager = SubscriptionManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let country: ResidenceCountry
    let action: () -> Void

    /// A slim lime strip: what Plus is, the price, one arrow. The full pitch lives on the paywall.
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Button(action: action) {
            HStack(spacing: 12) {
                SweezyCompanion(pose: .celebrate, size: 58)
                    .idleFloat(enabled: !reduceMotion)
                    .frame(width: 52, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("PLUS")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(JourneyVisual.lime)
                            .padding(.horizontal, 7)
                            .frame(height: 18)
                            .background(JourneyVisual.black, in: Capsule())
                        Text("від %@ / місяць".localized(with: "\(manager.displayPrice(for: SubscriptionManager.ProductID.monthly, fallback: fallbackPrice))"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black.opacity(0.62))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Text("Більше можливостей з Plus".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(JourneyVisual.lime)
                    .frame(width: 38, height: 38)
                    .background(JourneyVisual.black, in: Circle())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [JourneyVisual.lime, JourneyVisual.lime.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: shape
            )
            .contentShape(shape)
        }
        .buttonStyle(CardPressStyle())
        .accessibilityIdentifier("home.plusCard")
        .task { await manager.load() }
    }

    private var fallbackPrice: String {
        country == .switzerland ? "4.95 CHF" : "4.95 EUR"
    }
}

struct CVPlusGateSheet: View {
    let freeActionsUsed: Int
    let openPlus: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Capsule()
                .fill(Theme.Colors.adaptiveBorder)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)

            HStack {
                Label("PLUS", systemImage: "star.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Theme.Colors.adaptiveSurface)
                        .clipShape(Circle())
                }
            }

            Text("Продовжуй із\nSweezy Plus".localized)
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Без лімітів для твого CV".localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)

            gateBenefit("sparkles", "AI-покращення тексту".localized)
            gateBenefit("globe", "Переклад DE / FR / IT".localized)
            gateBenefit("doc.richtext", "PDF без обмежень".localized)

            Label("%@ безкоштовні дії використано".localized(with: "\(freeActionsUsed)"), systemImage: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Theme.Colors.adaptiveSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: openPlus) {
                Label("Відкрити Plus".localized, systemImage: "arrow.right")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }

            Button("Не зараз".localized, action: dismiss)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(Theme.Colors.primaryBackground)
        .accessibilityIdentifier("cv.plusGate")
    }

    private func gateBenefit(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(Theme.Colors.textPrimary)
            .symbolRenderingMode(.monochrome)
    }
}

#if DEBUG
#Preview {
    SubscriptionView()
}
#endif
