import SwiftUI

struct RegistrationView: View {
    var onRequestLogin: (() -> Void)? = nil

    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var verificationEmail = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    @State private var showLogin = false
    @State private var showEmailVerification = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, email, password
    }

    var body: some View {
        NavigationStack {
            AuthScaffold(
                scene: "registration",
                eyebrow: "auth.registration.eyebrow".localized,
                title: "auth.registration.hero_title".localized,
                subtitle: "auth.registration.hero_subtitle".localized,
                closeIdentifier: "auth.registration.close",
                onClose: { dismiss() }
            ) {
                form
            }
        }
        .onAppear {
            name = lockManager.userName
            email = lockManager.userEmail
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showEmailVerification) {
            EmailVerificationSheet(initialEmail: verificationEmail, initialName: name) {
                dismiss()
            }
            .environmentObject(appContainer)
            .environmentObject(lockManager)
            .environmentObject(sessionManager)
        }
    }

    private var form: some View {
        VStack(spacing: 14) {
            AuthField(
                label: "auth.registration.name".localized,
                placeholder: "auth.registration.name_placeholder".localized,
                icon: "person.fill",
                text: $name,
                focus: $focusedField,
                field: .name,
                contentType: .name,
                capitalization: .words,
                identifier: "auth.registration.name"
            ) { focusedField = .email }

            AuthField(
                label: "auth.registration.email".localized,
                placeholder: "name@email.com",
                icon: "envelope.fill",
                text: $email,
                focus: $focusedField,
                field: .email,
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                identifier: "auth.registration.email"
            ) { focusedField = .password }

            if isEmailInvalid {
                AuthNotice(text: "validation.email_invalid".localized, icon: "envelope.badge", tint: .orange)
            }

            AuthField(
                label: "auth.registration.password".localized,
                placeholder: "auth.registration.password_placeholder".localized,
                icon: "lock.fill",
                text: $password,
                focus: $focusedField,
                field: .password,
                isSecure: true,
                contentType: .newPassword,
                submitLabel: .done,
                identifier: "auth.registration.password"
            ) {
                focusedField = nil
                if !disabled { Task { await registerAsync() } }
            }

            if !password.isEmpty {
                passwordStrengthView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let errorMessage {
                AuthNotice(text: errorMessage)
            }

            AuthPrimaryButton(
                title: "auth.registration.submit".localized,
                isLoading: isRegistering,
                isEnabled: !disabled,
                identifier: "auth.registration.submit"
            ) {
                focusedField = nil
                Task { await registerAsync() }
            }
            .padding(.top, 4)

            SocialAuthPanel(
                errorMessage: $errorMessage,
                onAuthenticated: dismiss.callAsFunction
            )
            .padding(.top, 4)

            AuthSwitchRow(
                prompt: "auth.registration.have_account".localized,
                action: "auth.registration.login".localized,
                identifier: "auth.registration.openLogin",
                onTap: openLogin
            )

            AuthSecurityNote(text: "auth.registration.secure_storage".localized)
        }
        .animation(.easeOut(duration: 0.2), value: password.isEmpty)
        .animation(.easeOut(duration: 0.2), value: errorMessage)
    }

    private var passwordStrengthView: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(passwordIsStrong ? "auth.password.ready".localized : "auth.password.requirements".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(passwordIsStrong ? JourneyVisual.accentText : JourneyVisual.primaryText)
                Spacer()
                Text("\(passwordScore)/6")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(JourneyVisual.secondaryText)
            }

            HStack(spacing: 5) {
                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(index < passwordScore ? JourneyVisual.accentStrong : JourneyVisual.primaryText.opacity(0.1))
                        .frame(height: 4)
                }
            }

            Text("auth.password.compact_rules".localized)
                .font(.caption2)
                .foregroundStyle(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var disabled: Bool {
        normalizedName.isEmpty || normalizedEmail.isEmpty || isEmailInvalid || !passwordIsStrong
    }

    private var isEmailInvalid: Bool {
        if normalizedEmail.isEmpty { return false }
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(location: 0, length: normalizedEmail.utf16.count)
        return regex?.firstMatch(in: normalizedEmail, range: range) == nil
    }

    private var strengthModel: PasswordStrength {
        PasswordStrength(password: password)
    }

    private var passwordIsStrong: Bool {
        strengthModel.isStrong
    }

    private var passwordScore: Int {
        [
            strengthModel.hasMinLength,
            strengthModel.hasUpper,
            strengthModel.hasLower,
            strengthModel.hasDigit,
            strengthModel.hasSpecial,
            strengthModel.noSpaces
        ].filter { $0 }.count
    }

    private func openLogin() {
        if let onRequestLogin {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onRequestLogin()
            }
        } else {
            showLogin = true
        }
    }

    private func registerAsync() async {
        guard !disabled, !isRegistering else { return }
        errorMessage = nil
        isRegistering = true

        do {
            let response = try await APIClient.register(email: normalizedEmail, password: password)
            await MainActor.run {
                isRegistering = false
                guard response.status == "verification_required" else {
                    errorMessage = "auth.registration.error.generic".localized
                    return
                }

                verificationEmail = (response.email ?? normalizedEmail)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                showEmailVerification = true
            }
        } catch {
            await MainActor.run {
                isRegistering = false
                errorMessage = AuthErrorPresenter.message(
                    for: error,
                    fallbackKey: "auth.registration.error.generic"
                )
            }
        }
    }
}
