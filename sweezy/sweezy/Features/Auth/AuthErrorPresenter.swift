import Foundation

enum AuthErrorPresenter {
    static func message(for error: Error, fallbackKey: String) -> String {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            switch URLError.Code(rawValue: nsError.code) {
            case .notConnectedToInternet, .networkConnectionLost:
                return "auth.error.network".localized
            case .timedOut:
                return "auth.error.timeout".localized
            default:
                return "auth.error.unavailable".localized
            }
        }

        if let code = nsError.userInfo["api.code"] as? String {
            switch code {
            case "INVALID_CREDENTIALS":
                return "auth.error.invalid_credentials".localized
            case "INVALID_CODE", "CODE_NOT_FOUND":
                return "auth.verify.error.invalid".localized
            case "CODE_EXPIRED":
                return "auth.verify.error.expired".localized
            case "TOO_MANY_ATTEMPTS":
                return "auth.verify.error.too_many_attempts".localized
            case "EMAIL_NOT_VERIFIED":
                return "auth.verify.error.not_verified".localized
            case "EMAIL_DELIVERY_FAILED":
                return "auth.error.email_delivery".localized
            default:
                break
            }
        }

        if nsError.code == 429 {
            return "auth.error.rate_limited".localized
        }

        let rawMessage = nsError.localizedDescription.lowercased()
        if rawMessage.contains("invalid credentials") {
            return "auth.error.invalid_credentials".localized
        }
        if rawMessage.contains("invalid or expired code") {
            return "auth.verify.error.invalid_or_expired".localized
        }
        if rawMessage.contains("email already registered") {
            return "auth.registration.error.already_registered".localized
        }
        if rawMessage.contains("transactional email") || rawMessage.contains("email provider") {
            return "auth.error.email_delivery".localized
        }

        return fallbackKey.localized
    }
}
