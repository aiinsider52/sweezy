//
//  CrashReporterService.swift
//  sweezy
//
//  Abstraction over crash reporting to avoid hard dependency at compile time.
//

import Foundation

@MainActor
protocol CrashReporterServiceProtocol {
    func start()
    func setUser(id: String?, email: String?, username: String?)
    func addBreadcrumb(_ message: String, data: [String: String]?)
    func capture(error: Error, context: [String: String]?)
    func capture(message: String, level: String)
}

@MainActor
final class CrashReporterService: CrashReporterServiceProtocol {
    private let dsn: String?
    
    init(dsn: String? = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String) {
        self.dsn = dsn
    }
    
    func start() {
        #if canImport(Sentry)
        if let dsn = dsn {
            SentrySDK.start { options in
                options.dsn = dsn
                options.enableAutoBreadcrumbTracking = true
                options.enableAppHangTracking = true
                options.enableSwizzling = true
            }
        }
        #else
        // No-op fallback
        #endif
    }
    
    func setUser(id: String?, email: String?, username: String?) {
        #if canImport(Sentry)
        let user = User(userId: id)
        user.email = email
        user.username = username
        SentrySDK.setUser(user)
        #endif
    }
    
    func addBreadcrumb(_ message: String, data: [String: String]? = nil) {
        #if canImport(Sentry)
        let crumb = Breadcrumb()
        crumb.message = message
        data?.forEach { crumb.setData(value: $0.value, key: $0.key) }
        SentrySDK.addBreadcrumb(crumb)
        #endif
    }
    
    func capture(error: Error, context: [String: String]? = nil) {
        #if canImport(Sentry)
        SentrySDK.capture(error: error) { scope in
            context?.forEach { scope.setContext(value: [$0.key: $0.value], key: "ctx") }
        }
        #endif
    }
    
    func capture(message: String, level: String = "info") {
        #if canImport(Sentry)
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level == "error" ? .error : .info)
        }
        #endif
    }
}


