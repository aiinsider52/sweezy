import StoreKit
import SwiftUI
import UIKit

enum SubscriptionSource: String {
    case home
    case cv
    case profile
}

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var manager = SubscriptionManager.shared
    @State private var selectedProductID = SubscriptionManager.ProductID.monthly
    @State private var purchaseSucceeded = false

    let source: SubscriptionSource

    init(source: SubscriptionSource = .profile) {
        self.source = source
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        hero
                        valueHeader
                            .padding(.top, 26)
                        swissRoute
                            .padding(.top, 18)
                        benefits
                            .padding(.top, 30)
                        plans
                            .padding(.top, 30)
                        purchaseDetails
                            .padding(.top, 18)
                        legalLinks
                            .padding(.top, 18)
                            .padding(.bottom, 24)
                    }
                }
                .contentMargins(.top, -windowTopSafeAreaInset, for: .scrollContent)
                .ignoresSafeArea(edges: .top)
            }
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .top) {
                topBar
                    .padding(.top, max(geometry.safeAreaInsets.top, windowTopSafeAreaInset))
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { stickyPurchaseButton }
        }
        .ignoresSafeArea(edges: .top)
        .task {
            APIClient.logPaywall(eventType: "view", context: source.rawValue)
            await manager.load()
        }
        .alert("Sweezy Plus", isPresented: $purchaseSucceeded) {
            Button("Готово") { dismiss() }
        } message: {
            Text("Підписку активовано на всіх ваших пристроях Apple.")
        }
        .accessibilityIdentifier("subscription.paywall")
    }

    private var windowTopSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
    }

    private var pageBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.018, green: 0.026, blue: 0.021, alpha: 1)
                : UIColor(red: 0.955, green: 0.972, blue: 0.944, alpha: 1)
        })
    }

    private var cardBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.055)
                : UIColor(white: 1, alpha: 0.92)
        })
    }

    private var raisedBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.055, green: 0.075, blue: 0.061, alpha: 1)
                : UIColor.white
        })
    }

    private var primaryText: Color { Theme.Colors.textPrimary }
    private var secondaryText: Color { Theme.Colors.textSecondary }
    private var subtleText: Color { Theme.Colors.textTertiary }
    private var softBorder: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.12)
                : UIColor(white: 0, alpha: 0.085)
        })
    }
    private var readableAccent: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.78, green: 1.0, blue: 0.02, alpha: 1)
                : UIColor(red: 0.34, green: 0.49, blue: 0.015, alpha: 1)
        })
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("cityhub-zurich-lake")
                .resizable()
                .scaledToFill()
                .frame(height: 370)
                .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0.06), Color.black.opacity(0.22), Color.black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Label("PLUS", systemImage: "sparkles")
                    if hasMonthlyFreeTrial {
                        Text("30 ДНІВ БЕЗКОШТОВНО")
                    }
                }
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(JourneyVisual.lime)
                .clipShape(Capsule())

                VStack(alignment: .leading, spacing: -4) {
                    Text("Швейцарія.")
                        .foregroundColor(.white)
                    Text("Твій маршрут.")
                        .foregroundColor(JourneyVisual.lime)
                }
                .font(.system(size: 43, weight: .black, design: .rounded))
                .minimumScaleFactor(0.68)
                .lineLimit(2)

                Text("Plus збирає документи, роботу, мову та дедлайни в один зрозумілий план.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .frame(height: 400)
    }

    private var topBar: some View {
        HStack {
            Button {
                APIClient.logPaywall(eventType: "dismiss", context: source.rawValue)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .accessibilityLabel("Закрити")

            Spacer()

            Button {
                Task { await manager.restorePurchases() }
            } label: {
                Label("Відновити покупки", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .accessibilityIdentifier("subscription.restore")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var valueHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Від першого дня — до свого життя")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)
                Text("Один маршрут замість десятків розрізнених сервісів.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(secondaryText)
            }
            Spacer(minLength: 0)
            VStack(spacing: 1) {
                Text("8")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(readableAccent)
                Text("інструментів")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(subtleText)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(softBorder))
        }
        .padding(.horizontal, 22)
    }

    private var swissRoute: some View {
        VStack(spacing: 0) {
            routeStop(icon: "location.fill", title: "Старт", text: "Розкажи про свою ситуацію", isLast: false)
            routeStop(icon: "doc.text.fill", title: "Порядок", text: "Отримай документи, кроки та дедлайни", isLast: false)
            routeStop(icon: "briefcase.fill", title: "Результат", text: "Підготуй CV, листи та пошук роботи", isLast: false)
            routeStop(icon: "checkmark.seal.fill", title: "Впевненість", text: "Контролюй прогрес без зайвого стресу", isLast: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(raisedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(softBorder))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 22, y: 10)
        .padding(.horizontal, 22)
    }

    private func routeStop(icon: String, title: String, text: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 34, height: 34)
                    .background(JourneyVisual.lime)
                    .clipShape(Circle())
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [JourneyVisual.lime, JourneyVisual.lime.opacity(0.18)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 31)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Усе, що входить у Plus")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundColor(primaryText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                benefit(icon: "sparkles", title: "AI-помічник", text: "Запити без лімітів")
                benefit(icon: "map", title: "Особистий план", text: "Кроки під твою ситуацію")
                benefit(icon: "doc.text", title: "CV та листи", text: "Для ринку Швейцарії")
                benefit(icon: "globe.europe.africa", title: "Переклади", text: "DE · FR · IT")
                benefit(icon: "bell.badge", title: "Дедлайни", text: "Розумні нагадування")
                benefit(icon: "checklist", title: "Чеклісти", text: "Документи й побут")
                benefit(icon: "briefcase", title: "Пошук роботи", text: "Від вакансії до заявки")
                benefit(icon: "books.vertical", title: "База знань", text: "Життя у Швейцарії")
            }
        }
        .padding(.horizontal, 22)
    }

    private func benefit(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(readableAccent)
                .frame(width: 38, height: 38)
                .background(JourneyVisual.lime.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(JourneyVisual.lime.opacity(0.22)))

            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(primaryText)
                .lineLimit(2)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(secondaryText)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(softBorder))
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Обери свій Plus")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                    Text("Повний доступ на всіх Apple-пристроях")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryText)
                }
                Spacer(minLength: 8)
                Label("Apple", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(readableAccent)
            }

            planRow(
                id: SubscriptionManager.ProductID.monthly,
                title: "Щомісячно",
                price: "\(manager.displayPrice(for: SubscriptionManager.ProductID.monthly, fallback: "4.95 CHF")) / місяць",
                badge: hasMonthlyFreeTrial ? "1 місяць free" : nil
            )
            planRow(
                id: SubscriptionManager.ProductID.yearly,
                title: "Щорічно",
                price: "\(manager.displayPrice(for: SubscriptionManager.ProductID.yearly, fallback: "49.50 CHF")) / рік",
                badge: "2 місяці в подарунок"
            )
        }
        .padding(.horizontal, 22)
    }

    private func planRow(id: String, title: String, price: String, badge: String?) -> some View {
        let selected = selectedProductID == id
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedProductID = id }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(selected ? readableAccent : subtleText)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(primaryText)
                    Text(price)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selected ? readableAccent : secondaryText)
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 17)
            .frame(minHeight: 78)
            .background(selected ? JourneyVisual.lime.opacity(colorScheme == .dark ? 0.08 : 0.10) : cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? readableAccent : softBorder, lineWidth: selected ? 1.7 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("subscription.plan.\(id)")
    }

    private var purchaseDetails: some View {
        VStack(spacing: 11) {
            if hasSelectedFreeTrial {
                HStack(spacing: 10) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(JourneyVisual.lime)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Перший місяць — 0 CHF")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(primaryText)
                        Text("Потім \(monthlyPrice) / місяць. Скасування будь-коли.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(13)
                .background(JourneyVisual.lime.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(JourneyVisual.lime.opacity(0.24)))
            }

            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }

            Text("Підписка поновлюється автоматично. Скасувати можна будь-коли в налаштуваннях Apple ID.")
                .font(.system(size: 10))
                .foregroundColor(subtleText)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                trustItem("lock.fill", "Безпечна оплата")
                trustItem("arrow.counterclockwise", "Відновлення покупок")
            }
        }
        .padding(.horizontal, 22)
    }

    private func trustItem(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(subtleText)
    }

    private var stickyPurchaseButton: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(softBorder)

            Button {
                APIClient.logPaywall(eventType: "purchase_start", context: source.rawValue)
                Task {
                    if await manager.purchase(productID: selectedProductID) {
                        purchaseSucceeded = true
                    }
                }
            } label: {
                HStack {
                    if manager.purchasingProductID != nil {
                        Spacer()
                        ProgressView().tint(.black)
                        Spacer()
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(hasSelectedFreeTrial ? "Почати безкоштовний місяць" : "Продовжити з Plus")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Text(hasSelectedFreeTrial ? "сьогодні 0 CHF" : selectedPrice)
                                .font(.system(size: 10, weight: .bold))
                                .opacity(0.6)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(JourneyVisual.lime)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(manager.purchasingProductID != nil)
            .accessibilityIdentifier("subscription.purchase")
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .background(pageBackground.opacity(0.88))
    }

    private var legalLinks: some View {
        HStack(spacing: 20) {
            Link("Умови", destination: URL(string: "https://sweezy-9xyk.onrender.com/legal/terms")!)
            Link("Конфіденційність", destination: URL(string: "https://sweezy-9xyk.onrender.com/legal/privacy")!)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(secondaryText)
    }

    private var hasMonthlyFreeTrial: Bool {
        let storeTrial = manager.monthlyProduct?.subscription?.introductoryOffer?.paymentMode == .freeTrial
#if DEBUG
        return (storeTrial && manager.isMonthlyTrialEligible) || ProcessInfo.processInfo.arguments.contains("-screenshotTrial")
#else
        return storeTrial && manager.isMonthlyTrialEligible
#endif
    }

    private var hasSelectedFreeTrial: Bool {
        selectedProductID == SubscriptionManager.ProductID.monthly && hasMonthlyFreeTrial
    }

    private var monthlyPrice: String {
        manager.displayPrice(for: SubscriptionManager.ProductID.monthly, fallback: "4.95 CHF")
    }

    private var selectedPrice: String {
        selectedProductID == SubscriptionManager.ProductID.monthly
            ? "\(monthlyPrice) / місяць"
            : "\(manager.displayPrice(for: SubscriptionManager.ProductID.yearly, fallback: "49.50 CHF")) / рік"
    }
}

struct SweezyPlusHomeCard: View {
    @StateObject private var manager = SubscriptionManager.shared
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image("cityhub-zurich-lake")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.94), Color.black.opacity(0.62), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                VStack(alignment: .leading, spacing: 12) {
                    Label("PLUS", systemImage: "star.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(JourneyVisual.lime)
                        .clipShape(Capsule())

                    Text("Більше можливостей\nз Plus")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Label("Персональний план", systemImage: "person.crop.circle")
                    Label("AI без лімітів", systemImage: "sparkles")

                    HStack {
                        Text("від \(manager.displayPrice(for: SubscriptionManager.ProductID.monthly, fallback: "4.95 CHF")) / місяць")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("Відкрити Plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .background(JourneyVisual.lime)
                            .clipShape(Capsule())
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.82))
                .padding(18)
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(JourneyVisual.lime.opacity(0.9), lineWidth: 1.3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.plusCard")
        .task { await manager.load() }
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

            Text("Продовжуй із\nSweezy Plus")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)

            Text("Без лімітів для твого CV")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)

            gateBenefit("sparkles", "AI-покращення тексту")
            gateBenefit("globe", "Переклад DE / FR / IT")
            gateBenefit("doc.richtext", "PDF без обмежень")

            Label("\(freeActionsUsed) безкоштовні дії використано", systemImage: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Theme.Colors.adaptiveSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: openPlus) {
                Label("Відкрити Plus", systemImage: "arrow.right")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(JourneyVisual.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }

            Button("Не зараз", action: dismiss)
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
