import SwiftUI

/// Shared frame for login and registration: the story scene runs edge to edge at the top,
/// and a paper sheet with the heading and the form slides over its lower edge.
struct AuthScaffold<Content: View>: View {
    let scene: String
    let eyebrow: String
    let title: String
    let subtitle: String
    var closeIdentifier = "auth.close"
    let onClose: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            JourneyVisual.pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    sheet
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(JourneyVisual.primaryText)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            }
            .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94, hapticStyle: .light))
            .padding(.top, 8)
            .padding(.trailing, 18)
            .accessibilityLabel("common.close".localized)
            .accessibilityIdentifier(closeIdentifier)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.86)) {
                appeared = true
            }
        }
    }

    private var hero: some View {
        FocusedSceneImage(name: "story-\(scene)", focusY: 0.38)
            .frame(height: 320)
            .frame(maxWidth: .infinity)
            .scaleEffect(appeared || reduceMotion ? 1 : 1.08)
            .clipped()
            .overlay(alignment: .top) {
                // Keeps the status bar readable over bright sky.
                LinearGradient(colors: [JourneyVisual.pageBackground.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 90)
            }
            .accessibilityHidden(true)
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(JourneyVisual.lime).frame(width: 7, height: 7)
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.1)
                        .foregroundColor(JourneyVisual.accentText)
                }
                Text(title)
                    .font(.system(size: 31, weight: .bold))
                    .tracking(-0.4)
                    .foregroundColor(JourneyVisual.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(JourneyVisual.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)

            content
                .opacity(appeared || reduceMotion ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 22)
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                .fill(JourneyVisual.pageBackground)
                .shadow(color: .black.opacity(0.08), radius: 18, y: -6)
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.top, -36)
    }
}

/// Labelled input: the caption sits inside the field, the icon chip turns lime on focus.
struct AuthField<Field: Hashable>: View {
    let label: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var focus: FocusState<Field?>.Binding
    let field: Field
    var isSecure = false
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .never
    var submitLabel: SubmitLabel = .next
    var identifier: String? = nil
    var onSubmit: () -> Void = {}

    @State private var revealed = false

    private var isFocused: Bool { focus.wrappedValue == field }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isFocused ? .black : JourneyVisual.accentText)
                .frame(width: 36, height: 36)
                .background(isFocused ? JourneyVisual.lime : JourneyVisual.softSurface, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isFocused ? JourneyVisual.accentText : JourneyVisual.secondaryText)
                input
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(JourneyVisual.primaryText)
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
                    .focused(focus, equals: field)
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
                    .accessibilityIdentifier(identifier ?? label)
            }

            if isSecure {
                Button { revealed.toggle() } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(JourneyVisual.secondaryText)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(revealed ? "auth.password.hide".localized : "auth.password.show".localized)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, isSecure ? 6 : 14)
        .frame(height: 64)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isFocused ? JourneyVisual.accentStrong : JourneyVisual.softBorder, lineWidth: isFocused ? 1.5 : 1)
        )
        .shadow(color: isFocused ? JourneyVisual.lime.opacity(0.28) : .black.opacity(0.03), radius: isFocused ? 12 : 6, y: 3)
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = field }
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }

    @ViewBuilder
    private var input: some View {
        if isSecure && !revealed {
            SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(JourneyVisual.secondaryText.opacity(0.7)))
        } else {
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(JourneyVisual.secondaryText.opacity(0.7)))
        }
    }
}

/// Lime call to action with the arrow in a black disc.
struct AuthPrimaryButton: View {
    let title: String
    var isLoading = false
    var isEnabled = true
    var identifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                ZStack {
                    Circle().fill(Color.black)
                    if isLoading {
                        ProgressView().tint(JourneyVisual.lime).scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(JourneyVisual.lime)
                    }
                }
                .frame(width: 40, height: 40)
            }
            .foregroundColor(.black)
            .padding(.leading, 22)
            .padding(.trailing, 8)
            .frame(height: 56)
            .background(JourneyVisual.lime, in: Capsule())
            .shadow(color: JourneyVisual.lime.opacity(isEnabled ? 0.45 : 0), radius: 16, y: 6)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(ScaleButtonStyle(scaleAmount: 0.98, hapticStyle: .medium))
        .disabled(!isEnabled || isLoading)
        .accessibilityIdentifier(identifier ?? title)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

/// Inline message under the form: errors in coral, hints in neutral.
struct AuthNotice: View {
    let text: String
    var icon = "exclamationmark.circle.fill"
    var tint = Color(red: 0.86, green: 0.36, blue: 0.27)

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(JourneyVisual.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.22), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// "Already have an account? Sign in" style row.
struct AuthSwitchRow: View {
    let prompt: String
    let action: String
    var identifier: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Text(prompt).foregroundColor(JourneyVisual.secondaryText)
                Text(action)
                    .fontWeight(.bold)
                    .foregroundColor(JourneyVisual.primaryText)
                    .underline(color: JourneyVisual.lime)
            }
            .font(.system(size: 15))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? action)
    }
}

/// Small print with a shield: where the account data lives.
struct AuthSecurityNote: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(JourneyVisual.accentText)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(JourneyVisual.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}
