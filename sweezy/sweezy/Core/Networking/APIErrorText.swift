import Foundation

/// Server error texts are English and written for logs. Users only ever see messages in the app
/// language: a known error `code` maps to `api.error.code.<code>`, anything else to a message for
/// the HTTP status. The original code stays available under `api.code` for program logic.
enum APIErrorText {
    static func error(domain: String, status: Int, data: Data?) -> NSError {
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message(status: status, data: data)]
        if let code = code(from: data) {
            userInfo["api.code"] = code
        }
        if let detail = detailText(from: data) {
            // Raw server wording, for matching in code only; never shown to the user.
            userInfo["api.detail"] = detail
        }
        return NSError(domain: domain, code: status, userInfo: userInfo)
    }

    static func message(status: Int, data: Data?) -> String {
        if let code = code(from: data) {
            let key = "api.error.code.\(code.lowercased())"
            let text = key.localized
            if text != key { return text }
        }
        return statusMessage(status)
    }

    static func statusMessage(_ status: Int) -> String {
        let key: String
        switch status {
        case 400, 422: key = "api.error.invalid"
        case 401: key = "api.error.unauthorized"
        case 402: key = "api.error.payment_required"
        case 403: key = "api.error.forbidden"
        case 404: key = "api.error.not_found"
        case 409: key = "api.error.conflict"
        case 413: key = "api.error.too_large"
        case 429: key = "api.error.rate_limited"
        case 500...599: key = "api.error.server"
        default: key = "api.error.generic"
        }
        return key.localized
    }

    static func detailText(from data: Data?) -> String? {
        guard let data,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = payload["detail"] as? String { return text }
        return (payload["detail"] as? [String: Any])?["message"] as? String
    }

    /// `{"detail": {"code": "..."}}` or a bare snake/upper-case code in `detail`.
    static func code(from data: Data?) -> String? {
        guard let data,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = payload["detail"] else { return nil }
        if let object = detail as? [String: Any], let code = object["code"] as? String {
            return code
        }
        if let text = detail as? String, text.range(of: #"^[A-Za-z]+(_[A-Za-z]+)+$"#, options: .regularExpression) != nil {
            return text
        }
        return nil
    }
}
