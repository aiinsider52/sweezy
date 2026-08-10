import Combine
import SwiftUI

struct EmailVerificationSheet: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    private let email: String
    private let initialName: String?
    private let onVerified: (() -> Void)?

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var verificationComplete = false
    @State private var resendAvailableAt = Date().addingTimeInterval(60)
    @State private var resendSecondsRemaining = 60
    @FocusState private var codeIsFocused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(initialEmail: String, initialName: String? = nil, onVerified: (() -> Void)? = nil) {
        self.email = initialEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.initialName = initialName
        self.onVerified = onVerified
    }

    private var sanitizedCode: String {
        String(code.filter(\.isNumber).prefix(6))
    }

    private var canSubmit: Bool {
        sanitizedCode.count == 6 && !isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(
                    imageName: "cityhub-zurich-oldtown",
                    blurRadius: 3,
                    darkness: 0.76
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        topBar

                        if verificationComplete {
                            successContent
                        } else {
                            verificationContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled(isLoading)
        .onAppear {
            refreshResendCountdown()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                codeIsFocused = true
            }
        }
        .onReceive(timer) { _ in
            refreshResendCountdown()
        }
        .onChange(of: code) { _, newValue in
            let filtered = String(newValue.filter(\.isNumber).prefix(6))
            if filtered != newValue {
                code = filtered
            }
            if errorMessage != nil {
                errorMessage = nil
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: verificationComplete ? "checkmark.shield.fill" : "envelope.badge.shield.half.filled")
                    .foregroundStyle(JourneyVisual.lime)
                Text("auth.verify.step_label".localized)
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.72))
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
            .disabled(isLoading)
            .accessibilityLabel("common.close".localized)
        }
    }

    private var verificationContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("auth.verify.editorial_title".localized)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("auth.verify.editorial_subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            emailCard
            codeCard
        }
    }

    private var emailCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("auth.verify.sent_to".localized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                Text(email)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 4)

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(14)
        .background(Color.black.opacity(0.66), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("auth.verify.code_label".localized)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("auth.verify.latest_code_hint".localized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }

            otpField

            if let infoMessage {
                feedbackRow(icon: "checkmark.circle.fill", color: JourneyVisual.lime, text: infoMessage)
            }

            if let errorMessage {
                feedbackRow(icon: "exclamationmark.triangle.fill", color: .orange, text: errorMessage)
            }

            Button {
                codeIsFocused = false
                Task { await verifyEmail() }
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text("auth.verify.confirm".localized)
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
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.45)
            .accessibilityIdentifier("auth.verify.submit")

            Button {
                Task { await resendCode() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.clockwise")
                    Text(resendButtonTitle)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(resendSecondsRemaining == 0 ? JourneyVisual.lime : .white.opacity(0.46))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(isLoading || resendSecondsRemaining > 0)
            .accessibilityIdentifier("auth.verify.resend")

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.white.opacity(0.48))
                Text("auth.verify.resend_warning".localized)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(Color.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
    }

    private var otpField: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($codeIsFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .accessibilityLabel("auth.verify.code_label".localized)
                .accessibilityHint("auth.verify.code_placeholder".localized)
                .accessibilityIdentifier("auth.verify.code")

            HStack(spacing: 7) {
                ForEach(0..<6, id: \.self) { index in
                    otpCell(at: index)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(height: 64)
        .contentShape(Rectangle())
        .onTapGesture { codeIsFocused = true }
    }

    private func otpCell(at index: Int) -> some View {
        let characters = Array(sanitizedCode)
        let hasValue = index < characters.count
        let isCurrent = min(characters.count, 5) == index && codeIsFocused && characters.count < 6

        return Text(hasValue ? String(characters[index]) : "")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Color.white.opacity(hasValue ? 0.1 : 0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        hasValue || isCurrent ? JourneyVisual.lime.opacity(0.82) : .white.opacity(0.12),
                        lineWidth: hasValue || isCurrent ? 1.4 : 1
                    )
            )
    }

    private var successContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 64, height: 64)
                .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("auth.verify.success.title".localized)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("auth.verify.success.body".localized)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                dismiss()
                onVerified?()
            } label: {
                HStack {
                    Text("auth.verify.success.continue".localized)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func feedbackRow(icon: String, color: Color, text: String) -> some View {
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
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var resendButtonTitle: String {
        guard resendSecondsRemaining > 0 else {
            return "auth.verify.resend".localized
        }
        return String(format: "auth.verify.resend_countdown".localized, resendSecondsRemaining)
    }

    private func refreshResendCountdown() {
        resendSecondsRemaining = max(0, Int(ceil(resendAvailableAt.timeIntervalSinceNow)))
    }

    private func resetResendCountdown() {
        resendAvailableAt = Date().addingTimeInterval(60)
        refreshResendCountdown()
    }

    private func verifyEmail() async {
        guard canSubmit else { return }
        errorMessage = nil
        infoMessage = nil
        isLoading = true

        do {
            let tokens = try await APIClient.confirmEmailVerification(email: email, code: sanitizedCode)
            try await MainActor.run {
                try AuthSessionBootstrapper.finishAuthenticatedSession(
                    email: email,
                    name: resolvedDisplayName,
                    tokens: tokens,
                    appContainer: appContainer,
                    lockManager: lockManager,
                    sessionManager: sessionManager
                )
                isLoading = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                    verificationComplete = true
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = AuthErrorPresenter.message(
                    for: error,
                    fallbackKey: "auth.verify.error.invalid_or_expired"
                )
                codeIsFocused = true
            }
        }
    }

    private func resendCode() async {
        guard !isLoading, resendSecondsRemaining == 0 else { return }
        errorMessage = nil
        infoMessage = nil
        isLoading = true

        do {
            _ = try await APIClient.requestEmailVerification(email: email)
            await MainActor.run {
                isLoading = false
                code = ""
                infoMessage = "auth.verify.resent".localized
                resetResendCountdown()
                codeIsFocused = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = AuthErrorPresenter.message(
                    for: error,
                    fallbackKey: "auth.verify.error.resend_failed"
                )
            }
        }
    }

    private var resolvedDisplayName: String? {
        let trimmedInitialName = initialName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedInitialName.isEmpty { return trimmedInitialName }

        let storedName = lockManager.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedName.isEmpty { return storedName }

        let localPart = email.split(separator: "@").first.map(String.init) ?? ""
        return localPart.isEmpty ? nil : localPart.capitalized
    }
}
