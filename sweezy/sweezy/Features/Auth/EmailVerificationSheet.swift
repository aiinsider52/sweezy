import SwiftUI

struct EmailVerificationSheet: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    private let initialName: String?
    private let onVerified: (() -> Void)?

    @State private var email: String
    @State private var code: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var verificationComplete = false

    init(initialEmail: String, initialName: String? = nil, onVerified: (() -> Void)? = nil) {
        self._email = State(initialValue: initialEmail)
        self.initialName = initialName
        self.onVerified = onVerified
    }

    private var sanitizedCode: String {
        String(code.filter(\.isNumber).prefix(6))
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && sanitizedCode.count == 6
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.darkBackground
                    .ignoresSafeArea()

                AuthAuroraBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                            .padding(.top, 28)

                        if verificationComplete {
                            successCard
                        } else {
                            verificationCard
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
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
        }
        .onChange(of: code) { _, newValue in
            let filtered = String(newValue.filter(\.isNumber).prefix(6))
            if filtered != newValue {
                code = filtered
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.Colors.primary.opacity(0.24), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.primary.opacity(0.3), Theme.Colors.primaryDark.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)

                Image(systemName: verificationComplete ? "checkmark.circle.fill" : "envelope.badge.shield.half.filled")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: verificationComplete ? [Theme.Colors.success, .white] : [Theme.Colors.primary, .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(verificationComplete ? "auth.verify.success.title" : "auth.verify.title")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(verificationComplete ? "auth.verify.success.subtitle" : "auth.verify.subtitle")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
    }

    private var verificationCard: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("auth.verify.email_label")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.65))

                Text(email)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("auth.verify.code_label")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.65))

                TextField("auth.verify.code_placeholder", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(canSubmit ? Theme.Colors.primary.opacity(0.5) : Color.white.opacity(0.16), lineWidth: 1)
                            )
                    )
            }

            Text("auth.verify.code_hint")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let infoMessage {
                feedbackRow(icon: "checkmark.circle.fill", color: .green, text: infoMessage)
            }

            if let errorMessage {
                feedbackRow(icon: "exclamationmark.triangle.fill", color: .orange, text: errorMessage)
            }

            Button {
                Task { await verifyEmail() }
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                        Text("auth.verify.confirm")
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
            .disabled(!canSubmit || isLoading)
            .opacity(canSubmit ? 1 : 0.6)

            Button {
                Task { await resendCode() }
            } label: {
                Text("auth.verify.resend")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.Colors.primary)
            }
            .disabled(isLoading)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.Colors.primary.opacity(0.35), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var successCard: some View {
        VStack(spacing: 18) {
            Text("auth.verify.success.body")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)

            Button {
                dismiss()
                onVerified?()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("auth.verify.success.continue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Theme.Colors.success, Theme.Colors.primary], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(16)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.6))
        )
    }

    private func feedbackRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func verifyEmail() async {
        errorMessage = nil
        infoMessage = nil
        isLoading = true

        do {
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let tokens = try await APIClient.confirmEmailVerification(email: trimmedEmail, code: sanitizedCode)
            try KeychainStore.save(tokens.access_token, for: "access_token")
            try KeychainStore.save(tokens.refresh_token, for: "refresh_token")

            let previousEmail = lockManager.userEmail
            let resolvedName = resolvedDisplayName(for: trimmedEmail)
            withAnimation(Theme.Animation.smooth) {
                lockManager.userName = resolvedName ?? lockManager.userName
                lockManager.userEmail = trimmedEmail
                lockManager.isRegistered = true
            }
            if previousEmail != trimmedEmail {
                appContainer.userStats.reset()
                appContainer.gamification.resetForNewUser()
            }

            var profile = appContainer.userProfile ?? UserProfile()
            if let resolvedName, !resolvedName.isEmpty {
                profile.fullName = resolvedName
            }
            profile.email = trimmedEmail
            profile.preferredLanguage = appContainer.currentLocale.identifier
            appContainer.userProfile = profile
            sessionManager.activateAuthenticatedSession(email: trimmedEmail, name: profile.fullName.isEmpty ? nil : profile.fullName)

            await MainActor.run {
                isLoading = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    verificationComplete = true
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    private func resendCode() async {
        errorMessage = nil
        infoMessage = nil
        isLoading = true

        do {
            let response = try await APIClient.requestEmailVerification(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            await MainActor.run {
                isLoading = false
                infoMessage = response.message ?? "auth.verify.resent".localized
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    private func resolvedDisplayName(for email: String) -> String? {
        let trimmedInitialName = initialName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedInitialName.isEmpty {
            return trimmedInitialName
        }
        let storedName = lockManager.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedName.isEmpty {
            return storedName
        }
        let localPart = email.split(separator: "@").first.map(String.init) ?? ""
        return localPart.isEmpty ? nil : localPart.capitalized
    }
}
