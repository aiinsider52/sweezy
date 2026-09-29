import SwiftUI

private enum AuthDestination: String, Identifiable {
    case login
    case register

    var id: String { rawValue }
}

struct AuthEntryView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    private let showsCloseButton: Bool
    private let onComplete: (() -> Void)?

    @State private var activeDestination: AuthDestination?
    @State private var socialErrorMessage: String?

    init(
        showsCloseButton: Bool = true,
        onComplete: (() -> Void)? = nil
    ) {
        self.showsCloseButton = showsCloseButton
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                JourneyVisual.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        JourneyMascotStage(
                            pose: .welcome,
                            stickers: [
                                JourneyStageSticker(icon: "person.fill", title: "auth.entry.sticker.profile".localized, swatch: JourneyCategoryPalette.sky),
                                JourneyStageSticker(icon: "chart.bar.fill", title: "auth.entry.sticker.progress".localized, swatch: JourneyCategoryPalette.lime),
                                JourneyStageSticker(icon: "person.2.fill", title: "auth.entry.sticker.people".localized, swatch: JourneyCategoryPalette.coral)
                            ],
                            height: 212,
                            mascotSize: 168
                        )
                        .padding(.top, showsCloseButton ? 58 : 16)

                        headerSection
                            .padding(.top, 22)

                        benefitsSection
                            .padding(.top, 20)

                        actionsSection
                            .padding(.top, 22)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }

                if showsCloseButton {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(JourneyVisual.primaryText)
                            .frame(width: 40, height: 40)
                            .background(Theme.Colors.card, in: Circle())
                            .overlay(Circle().stroke(JourneyVisual.softBorder, lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94, hapticStyle: .light))
                    .padding(.top, 10)
                    .padding(.trailing, 18)
                    .accessibilityLabel("common.close".localized)
                    .accessibilityIdentifier("auth.entry.close")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.locale, appContainer.currentLocale)
        .sheet(item: $activeDestination) { destination in
            switch destination {
            case .login:
                LoginView(onRequestRegistration: {
                    activeDestination = .register
                })
                .environment(\.locale, appContainer.currentLocale)
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
            case .register:
                RegistrationView(onRequestLogin: {
                    activeDestination = .login
                })
                .environment(\.locale, appContainer.currentLocale)
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
            }
        }
        .onReceive(sessionManager.$state) { state in
            if case .authenticated = state {
                onComplete?()
                dismiss()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("auth.entry.title")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("auth.entry.subtitle")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var benefitsSection: some View {
        VStack(spacing: 0) {
            benefitRow(icon: "person.text.rectangle.fill", swatch: JourneyCategoryPalette.sky, text: "auth.entry.benefit.profile")
            Divider().overlay(JourneyVisual.softBorder).padding(.leading, 50)
            benefitRow(icon: "arrow.triangle.2.circlepath", swatch: JourneyCategoryPalette.teal, text: "auth.entry.benefit.sync")
            Divider().overlay(JourneyVisual.softBorder).padding(.leading, 50)
            benefitRow(icon: "star.fill", swatch: JourneyCategoryPalette.sand, text: "auth.entry.benefit.features")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JourneyVisual.softBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                activeDestination = .register
            } label: {
                HStack {
                    Text("auth.entry.create_account")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.08), in: Circle())
                }
                .foregroundColor(.black)
                .padding(.leading, 20)
                .padding(.trailing, 10)
                .frame(height: 56)
                .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: JourneyVisual.lime.opacity(0.35), radius: 14, y: 5)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
            .accessibilityIdentifier("auth.entry.createAccount")

            Button {
                activeDestination = .login
            } label: {
                Text("auth.entry.sign_in")
                    .font(.headline)
                    .foregroundColor(JourneyVisual.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(JourneyVisual.softBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98))
            .accessibilityIdentifier("auth.entry.signIn")

            SocialAuthPanel(
                errorMessage: $socialErrorMessage,
                showsDivider: true
            )
            .padding(.top, 6)

            if let socialErrorMessage {
                Text(socialErrorMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }

            Button {
                sessionManager.continueAsGuest()
                onComplete?()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Text("auth.login.continue_as_guest")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(JourneyVisual.secondaryText)
                .frame(minHeight: Theme.Layout.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .accessibilityIdentifier("auth.entry.continueAsGuest")
        }
    }

    private func benefitRow(icon: String, swatch: JourneyCategorySwatch, text: String) -> some View {
        HStack(spacing: 12) {
            JourneyCategoryIcon(symbol: icon, swatch: swatch, size: 36)

            Text(LocalizedStringKey(text))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }
}
