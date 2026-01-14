import SwiftUI

struct AccentSecureField: View {
    let titleKey: LocalizedStringKey
    @Binding var text: String
    @FocusState private var focused: Bool
    let icon: String?
    
    init(_ titleKey: LocalizedStringKey, text: Binding<String>, icon: String? = "lock") {
        self.titleKey = titleKey
        self._text = text
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            SecureField(titleKey, text: $text)
                .textContentType(.password)
                .textFieldStyle(.plain)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .focused($focused)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .fill(Theme.Colors.primaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .stroke(focused ? Theme.Colors.accentTurquoise : Theme.Colors.inputBorder, lineWidth: focused ? 2 : 1)
                .shadow(color: focused ? Theme.Colors.focusGlow : .clear, radius: focused ? 10 : 0)
                .allowsHitTesting(false)
        )
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        AccentSecureField("Password", text: .constant(""))
    }
    .padding()
}
