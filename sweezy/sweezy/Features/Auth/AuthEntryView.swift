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
    @State private var animateIcon = false
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
            ZStack {
                Theme.Colors.darkBackground
                    .ignoresSafeArea()

                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                AuthAuroraBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        headerSection
                            .padding(.top, 40)

                        benefitsSection

                        actionsSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateIcon = true
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.Colors.primary.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateIcon ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateIcon)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.primary.opacity(0.3), Theme.Colors.primaryDark.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.Colors.primary.opacity(0.6), Theme.Colors.primaryLight.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .scaleEffect(animateIcon ? 1 : 0.8)
                    .opacity(animateIcon ? 1 : 0)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Colors.primary, .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateIcon ? 1 : 0.5)
                    .opacity(animateIcon ? 1 : 0)
            }

            VStack(spacing: 8) {
                Text("auth.entry.title")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)

                Text("auth.entry.subtitle")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .opacity(animateIcon ? 1 : 0)
            .offset(y: animateIcon ? 0 : 20)
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("auth.entry.benefits_title")
                .font(.headline)
                .foregroundColor(.white)

            benefitRow(icon: "person.text.rectangle", text: "auth.entry.benefit.profile")
            benefitRow(icon: "arrow.triangle.2.circlepath", text: "auth.entry.benefit.sync")
            benefitRow(icon: "star.circle.fill", text: "auth.entry.benefit.features")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Colors.darkBackground.opacity(0.96),
                            Color(red: 0.13, green: 0.17, blue: 0.12).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.Colors.primary.opacity(0.24), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var actionsSection: some View {
        VStack(spacing: 14) {
            Button {
                activeDestination = .register
            } label: {
                Label("auth.entry.create_account", systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.primary, Theme.Colors.primaryLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Theme.Colors.primary.opacity(0.35), radius: 12, y: 6)
            }
            .buttonStyle(.plain)

            Button {
                activeDestination = .login
            } label: {
                Label("auth.entry.sign_in", systemImage: "arrow.right.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            SocialAuthPanel(
                errorMessage: $socialErrorMessage,
                showsDivider: true
            )

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
                Text("auth.login.continue_as_guest")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.78))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 22)

            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.88))
        }
    }
}
