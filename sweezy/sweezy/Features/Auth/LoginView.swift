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
    @State private var showPassword: Bool = false
    @State private var animateIcon: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.alpine.rawValue, blurRadius: 6, darkness: 0.64)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Top icon
                        loginHeader
                            .padding(.top, 40)
                        
                        // Login form
                        loginFormCard
                        
                        // Footer
                        footerSection
                        
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
        .journeyScreen(.alpine, darkness: 0.64)
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateIcon = true
            }
        }
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    // MARK: - Header
    private var loginHeader: some View {
        VStack(spacing: 16) {
            // Animated icon
            ZStack {
                // Outer glow
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
                
                // Inner circle with gradient
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
                                    colors: [Theme.Colors.primary.opacity(0.6), Theme.Colors.primaryDark.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .scaleEffect(animateIcon ? 1 : 0.8)
                    .opacity(animateIcon ? 1 : 0)
                
                // Icon
                Image(systemName: "person.crop.circle.badge.checkmark")
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
                Text("auth.login.title")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("auth.login.subtitle")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .opacity(animateIcon ? 1 : 0)
            .offset(y: animateIcon ? 0 : 20)
        }
    }
    
    // MARK: - Form Card
    private var loginFormCard: some View {
        VStack(spacing: 20) {
            // Email field
            modernTextField(
                placeholder: "auth.login.email",
                text: $email,
                icon: "envelope.fill",
                keyboardType: .emailAddress
            )
            
            // Password field
            modernSecureField(
                placeholder: "auth.login.password",
                text: $password,
                icon: "lock.fill"
            )
            
            // Forgot password link
            HStack {
                Spacer()
                Button {
                    showReset = true
                } label: {
                    Text("auth.login.forgot_password")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            
            // Error message
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.orange.opacity(0.15))
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            // Login button
            Button {
                Task { await login() }
            } label: {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                        Text("auth.login.button")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if email.isEmpty || password.isEmpty {
                            LinearGradient(
                                colors: [.gray.opacity(0.4), .gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: email.isEmpty || password.isEmpty ? .clear : Theme.Colors.primary.opacity(0.4), radius: 12, y: 6)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .animation(.easeInOut(duration: 0.2), value: email.isEmpty || password.isEmpty)

            SocialAuthPanel(
                errorMessage: $errorMessage,
                onAuthenticated: {
                    dismiss()
                }
            )
        }
        .padding(24)
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
                                colors: [Theme.Colors.primary.opacity(0.28), .white.opacity(0.08), Theme.Colors.primaryDark.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.42), radius: 24, y: 12)
        )
    }
    
    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Divider
            HStack {
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: 1)
                Text("common.or")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: 1)
            }
            
            // Guest mode (App Store 5.1.1 compliance):
            // Allow users to use the app for non-account features without creating an account.
            Button {
                sessionManager.continueAsGuest()
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text("auth.login.continue_as_guest")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                if let onRequestRegistration {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onRequestRegistration()
                    }
                } else {
                    showRegistration = true
                }
            } label: {
                Text("auth.login.create_account")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.Colors.primary)
            }
            .buttonStyle(.plain)

            // Security note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(Theme.Colors.primary.opacity(0.7))
                Text("auth.secure_connection")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Modern Text Field
    private func modernTextField(
        placeholder: String,
        text: Binding<String>,
        icon: String,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.Colors.primary.opacity(0.8))
                .frame(width: 24)
            
            TextField("", text: text, prompt: Text(LocalizedStringKey(placeholder)).foregroundColor(.white.opacity(0.4)))
                .font(.body)
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            !text.wrappedValue.isEmpty
                                ? LinearGradient(colors: [Theme.Colors.primary.opacity(0.42), Theme.Colors.primaryDark.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: text.wrappedValue.isEmpty)
    }
    
    // MARK: - Modern Secure Field
    private func modernSecureField(
        placeholder: String,
        text: Binding<String>,
        icon: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.Colors.primary.opacity(0.8))
                .frame(width: 24)
            
            Group {
                if showPassword {
                    TextField("", text: text, prompt: Text(LocalizedStringKey(placeholder)).foregroundColor(.white.opacity(0.4)))
                } else {
                    SecureField("", text: text, prompt: Text(LocalizedStringKey(placeholder)).foregroundColor(.white.opacity(0.4)))
                }
            }
            .font(.body)
            .foregroundColor(.white)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            
            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            !text.wrappedValue.isEmpty
                                ? LinearGradient(colors: [Theme.Colors.primary.opacity(0.42), Theme.Colors.primaryDark.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: text.wrappedValue.isEmpty)
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
                            .foregroundColor(Theme.Colors.primary)
                        }
                    }
                }
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
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: step.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(currentStep.rawValue >= step.rawValue ? .white : .white.opacity(0.4))
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
            // Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.Colors.primary.opacity(0.3), Theme.Colors.primaryDark.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.Colors.primary, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .padding(.top, 10)
            
            VStack(spacing: 8) {
                Text("auth.reset.title")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("auth.reset.subtitle")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
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
                .foregroundColor(.white)
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
                    .foregroundColor(.white)
                
                Text("auth.reset.enter_code.subtitle_format".localized(with: email))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Code input
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(Theme.Colors.primary)
                    
                    TextField("auth.reset.enter_code.placeholder".localized, text: $code)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .autocorrectionDisabled()
                    
                    if !code.isEmpty {
                        Button {
                            code = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    // Paste button
                    Button {
                        if let clipboardString = UIPasteboard.general.string {
                            code = String(clipboardString.filter(\.isNumber).prefix(6))
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(Theme.Colors.primary)
                            .padding(8)
                            .background(Circle().fill(Theme.Colors.primary.opacity(0.2)))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
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
                        .foregroundColor(Theme.Colors.accent.opacity(0.8))
                    Text("auth.reset.enter_code.hint")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
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
                .foregroundColor(.white)
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
                    .foregroundColor(Theme.Colors.primary)
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
                    .foregroundColor(.white)
                
                Text("auth.reset.new_password.subtitle")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
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
                .foregroundColor(.white)
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
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)
                
                Text("auth.reset.success.subtitle")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
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
                .foregroundColor(.white)
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
