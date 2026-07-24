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
    @State private var showPassword = false
    @State private var showLogin = false
    @State private var showEmailVerification = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, email, password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(
                    imageName: "cityhub-zurich-oldtown",
                    blurRadius: 2,
                    darkness: 0.72
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        topBar
                        hero
                        formCard
                        securityNote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
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

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("SWEEZY")
                    .font(.caption.weight(.black))
                    .tracking(2.2)
                    .foregroundStyle(JourneyVisual.lime)
                Text("auth.registration.account_label".localized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.48), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .accessibilityLabel("common.close".localized)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("auth.registration.hero_title".localized)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)

            Text("auth.registration.hero_subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("auth.registration.form_title".localized)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("auth.registration.form_subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            authTextField(
                title: "auth.registration.name".localized,
                placeholder: "auth.registration.name_placeholder".localized,
                text: $name,
                icon: "person",
                field: .name,
                contentType: .name,
                identifier: "auth.registration.name"
            )

            authTextField(
                title: "auth.registration.email".localized,
                placeholder: "name@email.com",
                text: $email,
                icon: "envelope",
                field: .email,
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                identifier: "auth.registration.email"
            )

            if isEmailInvalid {
                feedbackRow(
                    icon: "exclamationmark.circle.fill",
                    text: "validation.email_invalid".localized,
                    color: .orange
                )
            }

            passwordField

            if !password.isEmpty {
                passwordStrengthView
            }

            if let errorMessage {
                feedbackRow(icon: "exclamationmark.triangle.fill", text: errorMessage, color: .orange)
            }

            Button {
                focusedField = nil
                Task { await registerAsync() }
            } label: {
                HStack(spacing: 10) {
                    if isRegistering {
                        ProgressView().tint(.black)
                    } else {
                        Text("auth.registration.submit".localized)
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(disabled || isRegistering)
            .opacity(disabled ? 0.46 : 1)
            .accessibilityIdentifier("auth.registration.submit")

            SocialAuthPanel(
                errorMessage: $errorMessage,
                onAuthenticated: dismiss.callAsFunction
            )

            Button {
                openLogin()
            } label: {
                HStack(spacing: 5) {
                    Text("auth.registration.have_account".localized)
                        .foregroundStyle(.white.opacity(0.62))
                    Text("auth.registration.login".localized)
                        .fontWeight(.semibold)
                        .foregroundStyle(JourneyVisual.lime)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.registration.openLogin")
        }
        .padding(18)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.36), radius: 22, y: 12)
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("auth.registration.password".localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))

            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundStyle(JourneyVisual.lime)
                    .frame(width: 22)

                Group {
                    if showPassword {
                        TextField("auth.registration.password_placeholder".localized, text: $password)
                    } else {
                        SecureField("auth.registration.password_placeholder".localized, text: $password)
                    }
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .password)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                    if !disabled { Task { await registerAsync() } }
                }
                .accessibilityIdentifier("auth.registration.password")

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.white.opacity(0.52))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(showPassword ? "auth.password.hide".localized : "auth.password.show".localized)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focusedField == .password ? JourneyVisual.lime.opacity(0.78) : .white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var passwordStrengthView: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(passwordIsStrong ? "auth.password.ready".localized : "auth.password.requirements".localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(passwordIsStrong ? JourneyVisual.lime : .white.opacity(0.7))
                Spacer()
                Text("\(passwordScore)/6")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 5) {
                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill(index < passwordScore ? JourneyVisual.lime : Color.white.opacity(0.12))
                        .frame(height: 4)
                }
            }

            Text("auth.password.compact_rules".localized)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.48))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private var securityNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(JourneyVisual.lime)
            Text("auth.registration.secure_storage".localized)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private func authTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String,
        field: Field,
        contentType: UITextContentType?,
        keyboardType: UIKeyboardType = .default,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(JourneyVisual.lime)
                    .frame(width: 22)

                TextField(placeholder, text: text)
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .submitLabel(field == .name ? .next : field == .email ? .next : .done)
                    .onSubmit {
                        switch field {
                        case .name: focusedField = .email
                        case .email: focusedField = .password
                        case .password: focusedField = nil
                        }
                    }
                    .accessibilityIdentifier(identifier)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focusedField == field ? JourneyVisual.lime.opacity(0.78) : .white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private func feedbackRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    errorMessage = response.message ?? "auth.registration.error.generic".localized
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
