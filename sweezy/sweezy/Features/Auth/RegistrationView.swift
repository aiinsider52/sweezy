import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isRegistering: Bool = false
    @State private var errorMessage: String?
    @State private var showConfetti: Bool = false
    @State private var showPassword: Bool = false
    @State private var animateIcon: Bool = false
    @State private var showLogin: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Deep gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.08, blue: 0.16),
                        Color(red: 0.06, green: 0.12, blue: 0.24),
                        Color(red: 0.04, green: 0.1, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Aurora background
                AuthAuroraBackground()
                
                // Subtle snowfall
                WinterSceneLite(intensity: .light)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Top icon
                        registrationHeader
                            .padding(.top, 30)
                        
                        // Registration form
                        registrationFormCard
                        
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
        .overlay(alignment: .top) {
            if showConfetti { ConfettiView().allowsHitTesting(false) }
        }
        .onAppear {
            // Prefill from storage if any
            name = lockManager.userName
            email = lockManager.userEmail
            
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateIcon = true
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environmentObject(appContainer)
                .environmentObject(lockManager)
        }
    }
    
    // MARK: - Header
    private var registrationHeader: some View {
        VStack(spacing: 16) {
            // Animated icon
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.25), .clear],
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
                            colors: [.green.opacity(0.3), .cyan.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.green.opacity(0.6), .cyan.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .scaleEffect(animateIcon ? 1 : 0.8)
                    .opacity(animateIcon ? 1 : 0)
                
                // Icon
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateIcon ? 1 : 0.5)
                    .opacity(animateIcon ? 1 : 0)
                
                // Winter decoration
                if WinterTheme.isActive {
                    Text("🎄")
                        .font(.system(size: 28))
                        .offset(x: 50, y: -30)
                        .opacity(animateIcon ? 1 : 0)
                    
                    Text("❄️")
                        .font(.system(size: 16))
                        .offset(x: -45, y: -35)
                        .opacity(animateIcon ? 0.7 : 0)
                }
            }
            
            VStack(spacing: 8) {
                Text("Зареєструватись")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Зареєструйтесь, щоб отримати повний доступ")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .opacity(animateIcon ? 1 : 0)
            .offset(y: animateIcon ? 0 : 20)
        }
    }
    
    // MARK: - Form Card
    private var registrationFormCard: some View {
        VStack(spacing: 18) {
            // Name field
            modernTextField(
                placeholder: "Повне ім'я",
                text: $name,
                icon: "person.fill"
            )
            
            // Email field
            modernTextField(
                placeholder: "Електронна пошта",
                text: $email,
                icon: "envelope.fill",
                keyboardType: .emailAddress
            )
            
            // Email validation error
            if isEmailInvalid {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("validation.email_invalid".localized)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            // Password field
            modernSecureField(
                placeholder: "Пароль",
                text: $password,
                icon: "lock.fill"
            )
            
            // Password checklist
            PasswordChecklist(password: password)
                .padding(.top, 4)
            
            // Error message
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.red.opacity(0.15))
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            // Register button
            Button {
                Task { await registerAsync() }
            } label: {
                HStack(spacing: 12) {
                    if isRegistering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.title3)
                        Text("Зареєструватись")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if disabled {
                            LinearGradient(
                                colors: [.gray.opacity(0.4), .gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: disabled ? .clear : .green.opacity(0.4), radius: 12, y: 6)
            }
            .disabled(disabled || isRegistering)
            .animation(.easeInOut(duration: 0.2), value: disabled)
            
            // Login link
            Button {
                showLogin = true
            } label: {
                Text("Уже є акаунт? Увійти")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.cyan)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [.green.opacity(0.4), .white.opacity(0.1), .cyan.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
    }
    
    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Security note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green.opacity(0.7))
                Text("Дані зберігаються локально на пристрої")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
            )
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
                .foregroundColor(.green.opacity(0.8))
                .frame(width: 24)
            
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                .font(.body)
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            !text.wrappedValue.isEmpty
                                ? LinearGradient(colors: [.green.opacity(0.5), .cyan.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
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
                .foregroundColor(.green.opacity(0.8))
                .frame(width: 24)
            
            Group {
                if showPassword {
                    TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                } else {
                    SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
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
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            !text.wrappedValue.isEmpty
                                ? LinearGradient(colors: [.green.opacity(0.5), .cyan.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: text.wrappedValue.isEmpty)
    }
    
    private var disabled: Bool { name.isEmpty || email.isEmpty || password.isEmpty || isEmailInvalid || !passwordIsStrong }
    
    private var isEmailInvalid: Bool {
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(location: 0, length: email.utf16.count)
        if email.isEmpty { return false }
        return regex?.firstMatch(in: email, options: [], range: range) == nil
    }
    
    private var passwordIsStrong: Bool {
        PasswordStrength(password: password).isStrong
    }
    
    private func registerAsync() async {
        guard !disabled else { return }
        errorMessage = nil
        isRegistering = true
        
        // Try backend registration with timeout, fallback to local-only
        do {
            // Wrap in timeout task (5 seconds)
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await APIClient.register(email: email, password: password)
                    let tokens = try await APIClient.login(email: email, password: password)
                    try KeychainStore.save(tokens.access_token, for: "access_token")
                    try KeychainStore.save(tokens.refresh_token, for: "refresh_token")
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 sec timeout
                    throw URLError(.timedOut)
                }
                // Wait for first to complete
                try await group.next()
                group.cancelAll()
            }
        } catch {
            // Backend failed or timed out - continue with local registration
            print("⚠️ Backend registration failed: \(error.localizedDescription). Using local-only mode.")
        }
        
        // Always save locally (works offline)
        await MainActor.run {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                lockManager.userName = name
                lockManager.userEmail = email
                lockManager.isRegistered = true
            }
            // Reset local stats and gamification for new account
            appContainer.userStats.reset()
            appContainer.gamification.resetForNewUser()
            // Create/update local user profile
            var profile = appContainer.userProfile ?? UserProfile()
            profile.fullName = name
            profile.email = email
            profile.preferredLanguage = appContainer.currentLocale.identifier
            appContainer.userProfile = profile
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.3)) { showConfetti = true }
        try? await Task.sleep(nanoseconds: 800_000_000) // shorter delay
        withAnimation(.easeOut(duration: 0.3)) { showConfetti = false }
        
        isRegistering = false
        dismiss()
    }
}

// Password strength helpers moved to PasswordStrength.swift (shared)
