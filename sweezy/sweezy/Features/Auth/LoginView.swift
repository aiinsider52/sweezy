import SwiftUI

struct LoginView: View {
    var onRequestRegistration: (() -> Void)? = nil

    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showReset: Bool = false
    @State private var showRegistration: Bool = false
    @State private var showEmailVerification: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    var body: some View {
        NavigationStack {
            AuthScaffold(
                scene: "login",
                eyebrow: "auth.login.eyebrow".localized,
                title: "auth.login.title".localized,
                subtitle: "auth.login.subtitle".localized,
                closeIdentifier: "auth.login.close",
                onClose: { dismiss() }
            ) {
                form
            }
        }
        .sheet(isPresented: $showReset) {
            PasswordResetSheet(initialEmail: normalizedEmail)
        }
        .sheet(isPresented: $showEmailVerification) {
            EmailVerificationSheet(initialEmail: email, initialName: appContainer.userProfile?.fullName.isEmpty == false ? appContainer.userProfile?.fullName : nil) {
                dismiss()
            }
            .environmentObject(appContainer)
            .environmentObject(lockManager)
            .environmentObject(sessionManager)
        }
        .sheet(isPresented: $showRegistration) {
            RegistrationView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
                .environmentObject(sessionManager)
        }
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSubmit: Bool {
        !normalizedEmail.isEmpty && !password.isEmpty
    }

    // MARK: - Form

    private var form: some View {
        VStack(spacing: 14) {
            AuthField(
                label: "auth.login.email".localized,
                placeholder: "name@email.com",
                icon: "envelope.fill",
                text: $email,
                focus: $focusedField,
                field: .email,
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                identifier: "auth.login.email"
            ) { focusedField = .password }

            AuthField(
                label: "auth.login.password".localized,
                placeholder: "••••••••",
                icon: "lock.fill",
                text: $password,
                focus: $focusedField,
                field: .password,
                isSecure: true,
                contentType: .password,
                submitLabel: .go,
                identifier: "auth.login.password"
            ) {
                focusedField = nil
                if canSubmit { Task { await login() } }
            }

            HStack {
                Spacer()
                Button { showReset = true } label: {
                    Text("auth.login.forgot_password".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(JourneyVisual.accentText)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, -4)

            if let errorMessage {
                AuthNotice(text: errorMessage)
            }

            AuthPrimaryButton(
                title: "auth.login.button".localized,
                isLoading: isLoading,
                isEnabled: canSubmit,
                identifier: "auth.login.submit"
            ) {
                focusedField = nil
                Task { await login() }
            }

            SocialAuthPanel(
                errorMessage: $errorMessage,
                onAuthenticated: { dismiss() }
            )
            .padding(.top, 4)

            AuthSwitchRow(
                prompt: "auth.login.no_account".localized,
                action: "auth.login.create".localized,
                identifier: "auth.login.openRegistration"
            ) {
                if let onRequestRegistration {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onRequestRegistration()
                    }
                } else {
                    showRegistration = true
                }
            }

            // Guest mode (App Store 5.1.1): the app stays usable without an account.
            Button {
                sessionManager.continueAsGuest()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Text("auth.login.continue_as_guest".localized)
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(JourneyVisual.secondaryText)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("auth.login.guest")

            AuthSecurityNote(text: "auth.secure_connection".localized)
        }
        .animation(.easeOut(duration: 0.2), value: errorMessage)
    }

    private func login() async {
        errorMessage = nil
        isLoading = true
        do {
            let previousEmail = lockManager.userEmail
            let tokens = try await APIClient.login(email: normalizedEmail, password: password)
            try KeychainStore.save(tokens.access_token, for: "access_token")
            try KeychainStore.save(tokens.refresh_token, for: "refresh_token")
            try KeychainStore.save(tokens.user_id, for: "user_id")
            #if DEBUG
            if !UserDefaults.standard.bool(forKey: "didSyncToBackend") {
                Task {
                    await AdminSyncService.syncAll(contentService: appContainer.contentService)
                    UserDefaults.standard.set(true, forKey: "didSyncToBackend")
                }
            }
            #endif
            withAnimation(Theme.Animation.smooth) {
                lockManager.userEmail = normalizedEmail
                lockManager.isRegistered = true
            }
            // Reset local stats for a new account (avoid inheriting previous user's stats)
            if previousEmail != normalizedEmail {
                appContainer.userStats.reset()
                appContainer.gamification.resetForNewUser()
            }
            // Prime user profile for Settings / Profile forms
            if var profile = appContainer.userProfile {
                profile.email = normalizedEmail
                appContainer.userProfile = profile
                sessionManager.activateAuthenticatedSession(
                    userID: tokens.user_id,
                    email: normalizedEmail,
                    name: profile.fullName.isEmpty ? nil : profile.fullName
                )
            } else {
                var profile = UserProfile()
                // Derive a readable name from email local-part if possible
                let local = normalizedEmail.split(separator: "@").first.map(String.init) ?? "User"
                profile.fullName = local.capitalized
                profile.email = normalizedEmail
                profile.preferredLanguage = appContainer.currentLocale.identifier
                appContainer.userProfile = profile
                sessionManager.activateAuthenticatedSession(
                    userID: tokens.user_id,
                    email: normalizedEmail,
                    name: profile.fullName
                )
            }
            dismiss()
        } catch let error {
            if APIClient.isEmailNotVerified(error) {
                errorMessage = nil
                showEmailVerification = true
            } else {
                errorMessage = AuthErrorPresenter.message(
                    for: error,
                    fallbackKey: "auth.error.generic"
                )
            }
        }
        isLoading = false
    }
}

// MARK: - Aurora Background Effect (shared for auth screens)
struct AuthAuroraBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Aurora blobs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.Colors.primary.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: animate ? -50 : 50, y: animate ? -100 : -150)
                .blur(radius: 60)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.Colors.primaryDark.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: animate ? 80 : 30, y: animate ? 150 : 100)
                .blur(radius: 50)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.Colors.accent.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: animate ? -80 : -30, y: animate ? 80 : 120)
                .blur(radius: 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Password reset sheet (Redesigned)
struct PasswordResetSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Step tracking
    enum ResetStep: Int, CaseIterable {
        case email = 0
        case code = 1
        case newPassword = 2
        case success = 3
        
        var title: String {
            switch self {
            case .email: return "auth.reset.step.email".localized
            case .code: return "auth.reset.step.code".localized
            case .newPassword: return "auth.reset.step.password".localized
            case .success: return "auth.reset.step.done".localized
            }
        }
        
        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .code: return "key.fill"
            case .newPassword: return "lock.rotation"
            case .success: return "checkmark.circle.fill"
            }
        }
    }
    
    @State private var currentStep: ResetStep = .email
    @State private var email: String
    @State private var code: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var emailSent: Bool = false
    @State private var showSuccessAnimation: Bool = false
    
    init(initialEmail: String, initialToken: String? = nil) {
        _email = State(initialValue: initialEmail)
        if let token = initialToken, !token.isEmpty {
            let digits = String(token.filter(\.isNumber).prefix(6))
            if !digits.isEmpty {
                _code = State(initialValue: digits)
                _currentStep = State(initialValue: .code)
            }
        }
    }
    
    private var passwordStrength: PasswordStrength { PasswordStrength(password: newPassword) }
    private var passwordsMatch: Bool { newPassword == confirmPassword && !confirmPassword.isEmpty }
    private var canProceedToPassword: Bool { code.count == 6 && code.allSatisfy(\.isNumber) }
    private var canResetPassword: Bool { passwordStrength.isStrong && passwordsMatch }
    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.lake.rawValue, blurRadius: 6, darkness: 0.66)
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressIndicator
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                    
                    // Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Step content with animation
                            stepContent
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                                .id(currentStep)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if currentStep != .email && currentStep != .success {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                goBack()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("common.back".localized)
                            }
                            .foregroundColor(JourneyVisual.accentText)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(JourneyVisual.secondaryText)
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
        .journeyScreen(.lake, darkness: 0.66)
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Array(ResetStep.allCases.enumerated()), id: \.element) { index, step in
                if index > 0 {
                    // Connector line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: currentStep.rawValue >= step.rawValue
                                    ? [Theme.Colors.primary, Theme.Colors.primaryDark]
                                    : [Color.white.opacity(0.2), Color.white.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
                
                // Step circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: currentStep.rawValue >= step.rawValue
                                    ? [Theme.Colors.primary, Theme.Colors.primaryDark]
                                    : [Color.white.opacity(0.15), Color.white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: currentStep == step ? Theme.Colors.primary.opacity(0.5) : .clear, radius: 8)
                    
                    if currentStep.rawValue > step.rawValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(JourneyVisual.primaryText)
                    } else {
                        Image(systemName: step.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(currentStep.rawValue >= step.rawValue ? JourneyVisual.primaryText : JourneyVisual.primaryText)
                    }
                }
                .scaleEffect(currentStep == step ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .email:
            emailStepView
        case .code:
            codeStepView
        case .newPassword:
            passwordStepView
        case .success:
            successView
        }
    }
    
    // MARK: - Email Step
    private var emailStepView: some View {
        VStack(spacing: 20) {
            // Sweezy with a spare key by the mailbox: calm, "we'll get you back in".
            StoryScene(name: "password", height: 170)

            VStack(spacing: 8) {
                Text("auth.reset.title")
                    .font(.title2.bold())
                    .foregroundColor(JourneyVisual.primaryText)
                
                Text("auth.reset.subtitle")
                    .font(.subheadline)
                    .foregroundColor(JourneyVisual.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Email input card
            VStack(spacing: 16) {
                AccentTextField(
                    "auth.login.email",
                    text: $email,
                    icon: "envelope.fill",
                    keyboardType: .emailAddress
                )
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
                
                if emailSent {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("auth.reset.email_sent")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(colors: [Theme.Colors.primary.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
            )
            
            // Action button
            Button {
                Task { await sendResetEmail() }
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: emailSent ? "arrow.right" : "paperplane.fill")
                        Text(emailSent ? "auth.reset.continue".localized : "auth.reset.send_code".localized)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Theme.Colors.primary, Theme.Colors.primaryDark], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(JourneyVisual.primaryText)
                .cornerRadius(14)
                .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 10, y: 5)
            }
            .disabled(email.isEmpty || isLoading)
            .opacity(email.isEmpty ? 0.6 : 1)
        }
    }
    
    // MARK: - Code Step
    private var codeStepView: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.Colors.accent.opacity(0.3), Theme.Colors.accentCoral.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "key.viewfinder")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.accentCoral], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .padding(.top, 10)
            
            VStack(spacing: 8) {
                Text("auth.reset.enter_code.title")
                    .font(.title2.bold())
                    .foregroundColor(JourneyVisual.primaryText)
                
                Text("auth.reset.enter_code.subtitle_format".localized(with: email))
                    .font(.subheadline)
                    .foregroundColor(JourneyVisual.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Code input
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(JourneyVisual.accentStrong)
                    
                    TextField("auth.reset.enter_code.placeholder".localized, text: $code)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(JourneyVisual.primaryText)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .autocorrectionDisabled()
                    
                    if !code.isEmpty {
                        Button {
                            code = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(JourneyVisual.secondaryText)
                        }
                    }
                    
                    // Paste button
                    Button {
                        if let clipboardString = UIPasteboard.general.string {
                            code = String(clipboardString.filter(\.isNumber).prefix(6))
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(JourneyVisual.accentStrong)
                            .padding(8)
                            .background(Circle().fill(Theme.Colors.primary.opacity(0.2)))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(JourneyVisual.softBorder)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(canProceedToPassword ? .green.opacity(0.5) : .white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Hint
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(JourneyVisual.accentStrong.opacity(0.8))
                    Text("auth.reset.enter_code.hint")
                        .font(.caption)
                        .foregroundColor(JourneyVisual.secondaryText)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(colors: [Theme.Colors.accent.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
            )
            
            // Action button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    errorMessage = nil
                    currentStep = .newPassword
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right")
                    Text("common.next".localized)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.accentCoral], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(JourneyVisual.primaryText)
                .cornerRadius(14)
                .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 10, y: 5)
            }
            .disabled(!canProceedToPassword)
            .opacity(canProceedToPassword ? 1 : 0.6)
            
            // Resend link
            Button {
                Task { await sendResetEmail() }
            } label: {
                Text("auth.reset.resend_code")
                    .font(.subheadline)
                    .foregroundColor(JourneyVisual.accentText)
            }
            .disabled(isLoading)
        }
    }
    
    // MARK: - Password Step
    private var passwordStepView: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.Colors.success.opacity(0.3), Theme.Colors.primary.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.Colors.success, Theme.Colors.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .padding(.top, 10)
            
            VStack(spacing: 8) {
                Text("auth.reset.new_password.title")
                    .font(.title2.bold())
                    .foregroundColor(JourneyVisual.primaryText)
                
                Text("auth.reset.new_password.subtitle")
                    .font(.subheadline)
                    .foregroundColor(JourneyVisual.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Password inputs
            VStack(spacing: 16) {
                AccentSecureField(
                    "auth.reset.new_password.field",
                    text: $newPassword,
                    icon: "lock.fill"
                )
                
                AccentSecureField(
                    "auth.reset.confirm_password.field",
                    text: $confirmPassword,
                    icon: "lock.rotation"
                )
                
                // Password strength indicator
                PasswordChecklist(password: newPassword)
                
                // Match indicator
                if !confirmPassword.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(passwordsMatch ? .green : .red)
                        Text(passwordsMatch ? "auth.reset.passwords_match".localized : "auth.reset.passwords_not_match".localized)
                            .font(.caption)
                            .foregroundColor(passwordsMatch ? .green : .red)
                    }
                }
                
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(colors: [Theme.Colors.success.opacity(0.4), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
            )
            
            // Action button
            Button {
                Task { await resetPassword() }
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                        Text("auth.reset.change_password")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Theme.Colors.success, Theme.Colors.primary], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(JourneyVisual.primaryText)
                .cornerRadius(14)
                .shadow(color: Theme.Colors.success.opacity(0.4), radius: 10, y: 5)
            }
            .disabled(!canResetPassword || isLoading)
            .opacity(canResetPassword ? 1 : 0.6)
        }
    }
    
    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated checkmark
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.Colors.success.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(showSuccessAnimation ? 1.2 : 0.8)
                    .opacity(showSuccessAnimation ? 1 : 0)
                
                // Inner circle
                Circle()
                    .fill(LinearGradient(colors: [Theme.Colors.success, Theme.Colors.primary], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                    .shadow(color: Theme.Colors.success.opacity(0.5), radius: 20)
                    .scaleEffect(showSuccessAnimation ? 1 : 0)
                
                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .scaleEffect(showSuccessAnimation ? 1 : 0)
                    .rotationEffect(.degrees(showSuccessAnimation ? 0 : -90))
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                    showSuccessAnimation = true
                }
            }
            
            VStack(spacing: 12) {
                Text("auth.reset.success.title")
                    .font(.title.bold())
                    .foregroundColor(JourneyVisual.primaryText)
                
                Text("auth.reset.success.subtitle")
                    .font(.subheadline)
                    .foregroundColor(JourneyVisual.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .opacity(showSuccessAnimation ? 1 : 0)
            .offset(y: showSuccessAnimation ? 0 : 20)
            .animation(.easeOut.delay(0.3), value: showSuccessAnimation)
            
            Spacer()
            
            // Close button
            Button {
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("auth.reset.success.login")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Theme.Colors.success, Theme.Colors.primary], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(JourneyVisual.primaryText)
                .cornerRadius(14)
                .shadow(color: Theme.Colors.success.opacity(0.4), radius: 10, y: 5)
            }
            .opacity(showSuccessAnimation ? 1 : 0)
            .animation(.easeOut.delay(0.5), value: showSuccessAnimation)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Actions
    private func sendResetEmail() async {
        errorMessage = nil
        isLoading = true

        do {
            email = normalizedEmail
            _ = try await APIClient.requestPasswordReset(email: normalizedEmail)
            await MainActor.run {
                isLoading = false
                emailSent = true
                // Auto-advance to code step after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep = .code
                    }
                }
            }
        } catch let error {
            await MainActor.run {
                isLoading = false
                errorMessage = AuthErrorPresenter.message(
                    for: error,
                    fallbackKey: "auth.error.generic"
                )
            }
        }
    }
    
    private func resetPassword() async {
        errorMessage = nil
        isLoading = true

        do {
            email = normalizedEmail
            _ = try await APIClient.resetPassword(
                email: normalizedEmail,
                code: code,
                newPassword: newPassword
            )
            await MainActor.run {
                isLoading = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentStep = .success
                }
            }
        } catch let error {
            await MainActor.run {
                isLoading = false
                errorMessage = AuthErrorPresenter.message(
                    for: error,
                    fallbackKey: "auth.error.generic"
                )
            }
        }
    }
    
    private func goBack() {
        switch currentStep {
        case .code:
            currentStep = .email
        case .newPassword:
            currentStep = .code
        default:
            break
        }
    }
}

// Password strength helpers are defined in PasswordStrength.swift (shared)
