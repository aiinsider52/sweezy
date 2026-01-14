//
//  SubscriptionView.swift
//  sweezy
//

import SwiftUI
import SafariServices
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var current: APIClient.SubscriptionCurrent?
    @State private var isLoading: Bool = false
    @State private var showSafari: Bool = false
    @State private var safariURL: URL?
    @State private var errorText: String?
    @State private var isYearly: Bool = true
    @State private var showConfetti: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var showTerms: Bool = false
    @State private var promoCodeSheet: Bool = false
    @State private var promoCodeInput: String = ""
    @State private var remoteBenefits: [String] = []
    
    private let monthlyPrice: Double = 4.90
    private let yearlyPrice: Double = 44.0
    private var yearlySavings: Double { monthlyPrice * 12 - yearlyPrice }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Winter gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.1, blue: 0.2),
                        Color(red: 0.08, green: 0.15, blue: 0.28),
                        Color(red: 0.06, green: 0.12, blue: 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Subtle snowfall
                WinterSceneLite(intensity: .light)
                
                // Ambient glows - winter cyan tint
                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -100, y: -200)
                
                Circle()
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: 120, y: 100)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        heroSection
                        benefitsStrip
                        billingToggle
                        priceDisplay
                        comparisonTable
                        socialProof
                        ctaButton
                        termsText
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Redeem Code") { subManager.presentOfferCodeRedemption() }
                        Button("Manage Subscription") { Task { await subManager.showManageSubscriptions() } }
                        Button("Restore Purchases") { Task { await subManager.restore() } }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showSafari) {
                if let u = safariURL { SafariView(url: u).ignoresSafeArea() }
            }
            .sheet(isPresented: $promoCodeSheet) { promoCodeSheetContent }
            .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
            .sheet(isPresented: $showTerms) { TermsOfUseView() }
        }
        .overlay(ConfettiOverlay(show: $showConfetti, reduceMotion: reduceMotion))
        .task {
            // Paywall view analytics
            APIClient.logPaywall(eventType: "view", context: "subscription_screen")
            appContainer.analytics.track("paywall_view", properties: ["source": "subscription_screen"])
            // RemoteConfig: default plan + benefits
            if let cfg = await appContainer.remoteConfigService.getRemoteConfig() {
                if let plan = cfg.paywallDefaultPlan {
                    isYearly = plan.lowercased() != "monthly"
                }
                if let benefits = cfg.paywallBenefits, !benefits.isEmpty {
                    remoteBenefits = benefits
                }
            }
            current = await APIClient.subscriptionCurrent()
            if let cur = current, cur.status == "trial", let exp = cur.expire_at {
                let iso = ISO8601DateFormatter()
                let date = iso.date(from: exp)
                if let date {
                    _ = await appContainer.notificationService.requestPermission()
                    _ = await appContainer.notificationService.scheduleTrialEndReminder(endDate: date)
                }
            }
            await subManager.load()
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Crown icon with glow
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.75, blue: 0.20),
                                Color(red: 0.90, green: 0.60, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: Color(red: 0.95, green: 0.75, blue: 0.20).opacity(0.5), radius: 20, x: 0, y: 8)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("Sweezy Pro")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Повний доступ до всіх можливостей")
                .font(Theme.Typography.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 20)
    }
    
    // MARK: - Benefits Strip
    private var benefitsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                if remoteBenefits.isEmpty {
                    BenefitPill(icon: "wand.and.stars", text: "AI CV")
                    BenefitPill(icon: "envelope.fill", text: "Листи")
                    BenefitPill(icon: "globe", text: "Переклад")
                    BenefitPill(icon: "list.clipboard", text: "План")
                    BenefitPill(icon: "infinity", text: "Безліміт")
                } else {
                    ForEach(remoteBenefits, id: \.self) { item in
                        BenefitPill(icon: "sparkles", text: item)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Billing Toggle
    private var billingToggle: some View {
        HStack(spacing: 0) {
            toggleButton(title: "Щомісяця", isSelected: !isYearly) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isYearly = false }
                haptic(.light)
            }
            
            toggleButton(title: "Щорічно", isSelected: isYearly, badge: "−\(Int(yearlySavings)) CHF") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isYearly = true }
                haptic(.light)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Billing period")
        .accessibilityValue(isYearly ? "Yearly" : "Monthly")
    }
    
    private func toggleButton(title: String, isSelected: Bool, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                
                if let badge, isSelected {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.yellow)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Theme.Colors.accentTurquoise.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Price Display
    private var priceDisplay: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(isYearly ? "\(Int(yearlyPrice))" : String(format: "%.2f", monthlyPrice))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("CHF")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Text(isYearly ? "на рік • \(String(format: "%.2f", yearlyPrice / 12)) CHF/міс" : "на місяць")
                .font(Theme.Typography.caption)
                .foregroundColor(.white.opacity(0.5))
            
            if isYearly {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Економія \(Int(yearlySavings)) CHF на рік")
                        .font(Theme.Typography.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Comparison Table
    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Можливості")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Free")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 60)
                
                Text("Pro")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Colors.accentTurquoise)
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Rows
            ComparisonTableRow(feature: "AI-генерація CV", freeValue: .no, proValue: .yes)
            ComparisonTableRow(feature: "AI-листи для RAV", freeValue: .no, proValue: .yes)
            ComparisonTableRow(feature: "Переклад листів", freeValue: .no, proValue: .yes)
            ComparisonTableRow(feature: "Job Finder", freeValue: .limited, proValue: .unlimited)
            ComparisonTableRow(feature: "Збереження", freeValue: .text("3"), proValue: .unlimited)
            ComparisonTableRow(feature: "PDF експорт", freeValue: .no, proValue: .yes)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Social Proof
    private var socialProof: some View {
        HStack(spacing: 16) {
            HStack(spacing: -8) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    [Color.blue, Color.purple, Color.green, Color.orange][i],
                                    [Color.blue, Color.purple, Color.green, Color.orange][i].opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(["A", "M", "K", "S"][i])
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(Color(red: 0.04, green: 0.06, blue: 0.12), lineWidth: 2))
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                    Text("4.9")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("1200+ користувачів")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - CTA Button
    private var ctaButton: some View {
        Button {
            Task { await startPurchase() }
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text("Спробувати 7 днів безкоштовно")
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Theme.Colors.accentTurquoise.opacity(0.5), radius: 16, x: 0, y: 8)
            )
        }
        .disabled(isLoading)
        .padding(.top, 8)
        .accessibilityLabel("Start 7-day free trial")
        .accessibilityHint("Activates \(isYearly ? "yearly" : "monthly") plan with free trial")
    }
    
    // MARK: - Terms Text
    private var termsText: some View {
        VStack(spacing: 8) {
            Text("Підписка авто‑поновлюється. Скасувати можна будь‑коли в налаштуваннях Apple ID.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))

            HStack(spacing: 14) {
                Button("Privacy Policy") { showPrivacy = true }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.accentTurquoise)
                Button("Terms") { showTerms = true }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.accentTurquoise)
            }
            
            Button("Є промокод?") { promoCodeSheet = true }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.accentTurquoise)
            
            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Promo Code Sheet
    private var promoCodeSheetContent: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Введіть код", text: $promoCodeInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                
                Button {
                    promoCodeSheet = false
                } label: {
                    Text("Застосувати")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.accentTurquoise)
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Промокод")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Скасувати") { promoCodeSheet = false }
                }
            }
        }
        .presentationDetents([.height(220)])
    }
    
    // MARK: - Actions
    private func startPurchase() async {
        isLoading = true
        defer { isLoading = false }
        
        APIClient.logPaywall(eventType: "cta_click", context: isYearly ? "yearly" : "monthly")
        appContainer.analytics.track("paywall_cta_click", properties: ["plan": isYearly ? "yearly" : "monthly"])
        
        let ok: Bool
        if isYearly {
            ok = await subManager.purchaseYearly()
        } else {
            ok = await subManager.purchaseMonthly()
        }
        
        if ok || subManager.isPremium {
            appContainer.analytics.track("purchase_success", properties: ["plan": isYearly ? "yearly" : "monthly", "provider": "storekit"])
            haptic(.success)
            let approxEnd = Date().addingTimeInterval(6 * 24 * 3600 + 20 * 3600)
            _ = await appContainer.notificationService.scheduleTrialEndReminder(endDate: approxEnd)
            showConfetti = true
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
            return
        }
        
        // Fallback to Stripe
        APIClient.logPaywall(eventType: "purchase_start", context: "stripe_checkout")
        appContainer.analytics.track("purchase_start", properties: ["plan": isYearly ? "yearly" : "monthly", "provider": "stripe"])
        if let url = await APIClient.createCheckout(plan: isYearly ? "yearly" : "monthly", promotionCode: promoCodeInput.isEmpty ? nil : promoCodeInput) {
            safariURL = url
            showSafari = true
        } else {
            errorText = "Не вдалося розпочати оплату"
        }
    }
    
    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Supporting Views

private struct BenefitPill: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Colors.accentTurquoise, Theme.Colors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

private enum TableCellValue {
    case yes, no, limited, unlimited, text(String)
}

private struct ComparisonTableRow: View {
    let feature: String
    let freeValue: TableCellValue
    let proValue: TableCellValue
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            cellView(for: freeValue, isPro: false)
                .frame(width: 60)
            
            cellView(for: proValue, isPro: true)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.02))
        .overlay(
            Divider().background(Color.white.opacity(0.05)),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private func cellView(for value: TableCellValue, isPro: Bool) -> some View {
        switch value {
        case .yes:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(isPro ? Theme.Colors.accentTurquoise : .green)
        case .no:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red.opacity(0.6))
        case .limited:
            Text("3")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.orange)
        case .unlimited:
            Image(systemName: "infinity")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.accentTurquoise)
        case .text(let str):
            Text(str)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

private struct ConfettiOverlay: View {
    @Binding var show: Bool
    var reduceMotion: Bool = false
    var body: some View {
        Group {
            if reduceMotion {
                EmptyView()
            } else {
                ZStack {
                    ForEach(0..<24, id: \.self) { i in
                        Circle()
                            .fill([Color.red, .yellow, .green, .blue, .pink, .orange, .purple].randomElement()!.opacity(show ? 1 : 0))
                            .frame(width: CGFloat.random(in: 6...14), height: CGFloat.random(in: 6...14))
                            .offset(
                                x: CGFloat.random(in: -160...160),
                                y: show ? CGFloat.random(in: (-280)...(-60)) : 0
                            )
                            .animation(
                                .spring(response: Double.random(in: 0.5...0.9), dampingFraction: 0.6)
                                .delay(Double(i) * 0.025),
                                value: show
                            )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(AppContainer())
}
