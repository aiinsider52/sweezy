import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
enum AuthSessionBootstrapper {
    static func finishAuthenticatedSession(
        email: String,
        name: String?,
        tokens: APIClient.TokenPair,
        appContainer: AppContainer,
        lockManager: AppLockManager,
        sessionManager: SessionManager
    ) throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousEmail = lockManager.userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        try KeychainStore.save(tokens.access_token, for: "access_token")
        try KeychainStore.save(tokens.refresh_token, for: "refresh_token")

        #if DEBUG
        if !UserDefaults.standard.bool(forKey: "didSyncToBackend") {
            Task {
                await AdminSyncService.syncAll(contentService: appContainer.contentService)
                UserDefaults.standard.set(true, forKey: "didSyncToBackend")
            }
        }
        #endif

        let resolvedName: String = {
            if let trimmedName, !trimmedName.isEmpty {
                return trimmedName
            }
            if let existing = appContainer.userProfile?.fullName, !existing.isEmpty {
                return existing
            }
            let local = trimmedEmail.split(separator: "@").first.map(String.init) ?? "User"
            return local.capitalized
        }()

        withAnimation(Theme.Animation.smooth) {
            lockManager.userName = resolvedName
            lockManager.userEmail = trimmedEmail
            lockManager.isRegistered = true
        }

        if previousEmail != trimmedEmail {
            appContainer.userStats.reset()
            appContainer.gamification.resetForNewUser()
        }

        var profile = appContainer.userProfile ?? UserProfile()
        profile.fullName = resolvedName
        profile.email = trimmedEmail
        profile.preferredLanguage = appContainer.currentLocale.identifier
        appContainer.userProfile = profile

        sessionManager.activateAuthenticatedSession(email: trimmedEmail, name: resolvedName)
    }
}

struct SocialAuthPanel: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager

    @Binding var errorMessage: String?

    var onAuthenticated: (() -> Void)? = nil
    var showsDivider: Bool = true

    @State private var isGoogleLoading = false
    @State private var appleNonce: String?
    @State private var pendingLinkResponse: APIClient.SocialAuthResponse?

    var body: some View {
        VStack(spacing: 14) {
            if showsDivider {
                HStack {
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 1)
                    Text("auth.social.or_continue_with".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 1)
                }
            }

            SignInWithAppleButton(.continue) { request in
                let nonce = randomNonceString()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                Task { await handleAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                Task { await startGoogleSignIn() }
            } label: {
                HStack(spacing: 10) {
                    if isGoogleLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.textPrimary))
                    } else {
                        Text("G")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(Color.white)
                            )
                    }

                    Text("auth.social.google".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.965, green: 0.972, blue: 0.965))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isGoogleLoading)
        }
        .sheet(item: $pendingLinkResponse) { response in
            SocialLinkConfirmationSheet(response: response) {
                onAuthenticated?()
            }
            .environmentObject(appContainer)
            .environmentObject(lockManager)
            .environmentObject(sessionManager)
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "auth.social.error.apple_failed".localized])
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  !idToken.isEmpty else {
                throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "auth.social.error.missing_identity_token".localized])
            }

            let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            let formatter = PersonNameComponentsFormatter()
            formatter.style = .default
            let formattedName = credential.fullName.flatMap { formatter.string(from: $0) }
            let fullName = formattedName?.trimmingCharacters(in: .whitespacesAndNewlines)

            let response = try await APIClient.signInWithApple(
                idToken: idToken,
                authorizationCode: authorizationCode,
                nonce: appleNonce,
                fullName: fullName?.isEmpty == false ? fullName : nil
            )
            try await handleSocialResponse(response)
        } catch {
            await MainActor.run {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    private func startGoogleSignIn() async {
        await MainActor.run {
            errorMessage = nil
            isGoogleLoading = true
        }

        do {
            let idTokenResult = try await GoogleSignInCoordinator.signIn()
            let response = try await APIClient.signInWithGoogle(
                idToken: idTokenResult.idToken,
                fullName: idTokenResult.fullName
            )
            try await handleSocialResponse(response)
        } catch {
            await MainActor.run {
                errorMessage = (error as NSError).localizedDescription
            }
        }

        await MainActor.run {
            isGoogleLoading = false
        }
    }

    private func handleSocialResponse(_ response: APIClient.SocialAuthResponse) async throws {
        if response.status == "link_required" {
            await MainActor.run {
                pendingLinkResponse = response
            }
            return
        }

        guard response.status == "authenticated",
              let email = response.email,
              let tokens = response.tokenPair else {
            throw NSError(
                domain: "Auth",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: response.message ?? "auth.social.error.generic".localized]
            )
        }

        try await MainActor.run {
            try AuthSessionBootstrapper.finishAuthenticatedSession(
                email: email,
                name: response.name,
                tokens: tokens,
                appContainer: appContainer,
                lockManager: lockManager,
                sessionManager: sessionManager
            )
            onAuthenticated?()
        }
    }
}

private struct GoogleTokenResult {
    let idToken: String
    let fullName: String?
}

private enum GoogleSignInCoordinator {
    @MainActor
    static func signIn() async throws -> GoogleTokenResult {
        #if canImport(GoogleSignIn)
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String,
              !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "auth.social.error.google_config".localized])
        }
        guard let presentingViewController = activeRootViewController() else {
            throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "auth.social.error.google_presenter".localized])
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        guard let idToken = result.user.idToken?.tokenString, !idToken.isEmpty else {
            throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "auth.social.error.missing_identity_token".localized])
        }

        return GoogleTokenResult(
            idToken: idToken,
            fullName: result.user.profile?.name
        )
        #else
        throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "auth.social.error.google_unavailable".localized])
        #endif
    }
}

struct SocialLinkConfirmationSheet: View {
    let response: APIClient.SocialAuthResponse
    let onSuccess: () -> Void

    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.darkBackground.ignoresSafeArea()
                AuthAuroraBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 42))
                                .foregroundColor(Theme.Colors.primary)

                            Text("auth.social.link.title".localized)
                                .font(.title3.bold())
                                .foregroundColor(.white)

                            Text(
                                "auth.social.link.subtitle".localized(
                                    with: response.providerDisplayName,
                                    response.email ?? ""
                                )
                            )
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)

                        VStack(spacing: 14) {
                            AccentTextField(
                                "auth.login.email",
                                text: $email,
                                icon: "envelope.fill",
                                keyboardType: .emailAddress
                            )
                            .autocapitalization(.none)

                            AccentSecureField(
                                "auth.login.password",
                                text: $password,
                                icon: "lock.fill"
                            )

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
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
                                    RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )

                        Button {
                            Task { await confirmLink() }
                        } label: {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "link.badge.plus")
                                    Text("auth.social.link.confirm".localized)
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .disabled(email.isEmpty || password.isEmpty || isLoading)
                        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .onAppear {
                email = response.email ?? ""
            }
        }
    }

    private func confirmLink() async {
        guard let linkToken = response.link_token else { return }

        await MainActor.run {
            errorMessage = nil
            isLoading = true
        }

        do {
            let linkResponse = try await APIClient.confirmSocialLink(email: email, password: password, linkToken: linkToken)
            guard let tokens = linkResponse.tokenPair, let resolvedEmail = linkResponse.email else {
                throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: linkResponse.message ?? "auth.social.error.generic".localized])
            }

            try await MainActor.run {
                try AuthSessionBootstrapper.finishAuthenticatedSession(
                    email: resolvedEmail,
                    name: linkResponse.name,
                    tokens: tokens,
                    appContainer: appContainer,
                    lockManager: lockManager,
                    sessionManager: sessionManager
                )
                isLoading = false
                onSuccess()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}

private extension APIClient.SocialAuthResponse {
    var providerDisplayName: String {
        switch provider {
        case "apple": return "Apple"
        case "google": return "Google"
        default: return "social sign-in"
        }
    }
}

private func randomNonceString(length: Int = 32) -> String {
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        let randoms: [UInt8] = (0..<16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return random
        }

        randoms.forEach { random in
            if remainingLength == 0 {
                return
            }

            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }

    return result
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap { String(format: "%02x", $0) }.joined()
}

#if canImport(UIKit)
@MainActor
private func activeRootViewController() -> UIViewController? {
    let windowScene = UIApplication.shared.connectedScenes
        .first { $0.activationState == .foregroundActive } as? UIWindowScene
    let root = windowScene?.windows.first(where: \.isKeyWindow)?.rootViewController
    return topViewController(from: root)
}

private func topViewController(from viewController: UIViewController?) -> UIViewController? {
    if let navigationController = viewController as? UINavigationController {
        return topViewController(from: navigationController.visibleViewController)
    }
    if let tabBarController = viewController as? UITabBarController {
        return topViewController(from: tabBarController.selectedViewController)
    }
    if let presented = viewController?.presentedViewController {
        return topViewController(from: presented)
    }
    return viewController
}
#endif
