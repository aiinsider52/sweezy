import SwiftUI

// MARK: - Shared Password Strength Model
struct PasswordStrength {
    let password: String
    var hasMinLength: Bool { password.count >= 8 }
    var hasUpper: Bool { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    var hasLower: Bool { password.range(of: "[a-z]", options: .regularExpression) != nil }
    var hasDigit: Bool { password.range(of: "[0-9]", options: .regularExpression) != nil }
    var hasSpecial: Bool { password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil }
    var noSpaces: Bool { password.range(of: "\\s", options: .regularExpression) == nil }
    var isStrong: Bool { hasMinLength && hasUpper && hasLower && hasDigit && hasSpecial && noSpaces }
}

// MARK: - Shared Password Checklist View
struct PasswordChecklist: View {
    let password: String
    private var strength: PasswordStrength { PasswordStrength(password: password) }
    
    private struct ChecklistRule: Identifiable {
        let id: String
        let text: String
        let isOk: Bool
    }
    
    private var rules: [ChecklistRule] {
        [
            ChecklistRule(id: "length", text: "Не менше 8 символів", isOk: strength.hasMinLength),
            ChecklistRule(id: "upper", text: "Щонайменше 1 велика літера", isOk: strength.hasUpper),
            ChecklistRule(id: "lower", text: "Щонайменше 1 мала літера", isOk: strength.hasLower),
            ChecklistRule(id: "digit", text: "Щонайменше 1 цифра", isOk: strength.hasDigit),
            ChecklistRule(id: "special", text: "Щонайменше 1 спецсимвол", isOk: strength.hasSpecial),
            ChecklistRule(id: "spaces", text: "Без пробілів", isOk: strength.noSpaces)
        ]
    }
    
    var body: some View {
        Group {
            // Підказки з'являються тільки після того, як користувач почав вводити пароль
            if password.isEmpty {
                EmptyView()
            } else {
                // Невиконані правила зверху, виконані плавно «переїжджають» вниз
                let ordered = rules.sorted { lhs, rhs in
                    if lhs.isOk == rhs.isOk {
                        return lhs.id < rhs.id
                    }
                    return !lhs.isOk && rhs.isOk
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ordered) { rule in
                        row(for: rule)
                    }
                }
                .padding(.top, 2)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Плавна анімація появи та перестановки пунктів при зміні паролю
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: password)
    }
    
    @ViewBuilder
    private func row(for rule: ChecklistRule) -> some View {
        HStack(spacing: 6) {
            Image(systemName: rule.isOk ? "checkmark.circle.fill" : "circle")
                .foregroundColor(rule.isOk ? .green : Theme.Colors.tertiaryText)
                .font(.system(size: 12))
            Text(rule.text)
                .font(Theme.Typography.caption)
                .foregroundColor(rule.isOk ? Theme.Colors.secondaryText : Theme.Colors.tertiaryText)
                .strikethrough(rule.isOk)
        }
    }
}


