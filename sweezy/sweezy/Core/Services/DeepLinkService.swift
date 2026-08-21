//
//  DeepLinkService.swift
//  sweezy
//
//  Created by AI Assistant on 16.10.2025.
//

import Foundation
import SwiftUI

// MARK: - Deep Link Types

enum DeepLink: Equatable {
    // Content
    case guide(id: String)
    case checklist(id: String)
    case template(id: String)
    case place(id: String)
    
    // Features
    case map(filter: String?)
    case calculator
    case appointments
    case news
    case cvBuilder
    case chat(id: String)
    
    // Settings
    case settings
    case profile
    case privacy
    case language
    
    // Auth
    case passwordReset(token: String?)
    
    // Special
    case onboarding
    case whatsNew

    var rootTabIndex: Int? {
        switch self {
        case .news, .whatsNew:
            return 0
        case .guide, .checklist, .template, .calculator, .appointments, .cvBuilder:
            return 1
        case .map, .place:
            return 2
        case .settings, .profile, .privacy, .language:
            return 0
        case .onboarding, .passwordReset, .chat:
            return nil
        }
    }
}

extension Notification.Name {
    static let openDeepLinkDestination = Notification.Name("openDeepLinkDestination")
}

// MARK: - Deep Link Service

class DeepLinkService: ObservableObject {
    @Published var activeDeepLink: DeepLink?
    @Published var shouldNavigate: Bool = false
    
    static let shared = DeepLinkService()
    
    private init() {}
    
    // MARK: - Handle URL
    
    /// Handle incoming URL (from universal link or URL scheme)
    @MainActor
    func handle(url: URL) {
        #if DEBUG
        print("🔗 Received deep link: \(url)")
        #endif
        
        guard let deepLink = parse(url: url) else {
            #if DEBUG
            print("❌ Failed to parse deep link")
            #endif
            return
        }
        
        navigate(to: deepLink)
    }
    
    /// Navigate to specific deep link
    @MainActor
    func navigate(to deepLink: DeepLink) {
        activeDeepLink = deepLink
        shouldNavigate = true
        
        #if DEBUG
        print("🧭 Navigating to: \(deepLink)")
        #endif
        
        // Optionally track analytics here if AnalyticsService is available
    }
    
    /// Clear active deep link
    @MainActor
    func clearDeepLink() {
        activeDeepLink = nil
        shouldNavigate = false
    }
    
    // MARK: - URL Parsing
    
    func parse(url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil, components.fragment == nil,
              let scheme = components.scheme?.lowercased(),
              let rawHost = components.host?.lowercased() else { return nil }
        let encodedPath = components.percentEncodedPath.lowercased()
        guard !encodedPath.contains("%2f"), !encodedPath.contains("%5c") else { return nil }
        let rawPath = components.path.split(separator: "/").map(String.init)
        let host: String
        let path: [String]
        switch scheme {
        case "https":
            guard rawHost == "sweezy.app" || rawHost == "www.sweezy.app",
                  let route = rawPath.first else { return nil }
            host = route.lowercased()
            path = Array(rawPath.dropFirst())
        case "sweezy":
            host = rawHost
            path = rawPath
        default:
            return nil
        }
        func validID(_ value: String) -> Bool {
            (1...128).contains(value.count) &&
            value.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).contains($0) }
        }
        
        // Parse based on host/path
        switch host {
        case "guide", "guides":
            if path.count == 1, let id = path.first, validID(id) {
                return .guide(id: id)
            }
            
        case "checklist", "checklists":
            if path.count == 1, let id = path.first, validID(id) {
                return .checklist(id: id)
            }
            
        case "template", "templates":
            if path.count == 1, let id = path.first, validID(id) {
                return .template(id: id)
            }
            
        case "place", "places":
            if path.count == 1, let id = path.first, validID(id) {
                return .place(id: id)
            }
            
        case "map":
            guard path.isEmpty else { return nil }
            let filter = components.queryItems?.first(where: { $0.name == "filter" })?.value
            return .map(filter: filter)
            
        case "calculator":
            guard path.isEmpty else { return nil }; return .calculator
            
        case "appointments":
            guard path.isEmpty else { return nil }; return .appointments
            
        case "news":
            guard path.isEmpty else { return nil }; return .news

        case "chat":
            if path.count == 1, let id = path.first, validID(id) { return .chat(id: id) }
            
        case "settings":
            if path == ["profile"] {
                return .profile
            } else if path == ["privacy"] {
                return .privacy
            } else if path == ["language"] {
                return .language
            }
            guard path.isEmpty else { return nil }; return .settings
        
        case "auth", "password", "reset":
            guard (host == "auth" && path == ["reset"]) ||
                    ((host == "password" || host == "reset") && path.isEmpty) else { return nil }
            // Never accept OTP/reset credentials from a URL; users enter the code in-app.
            return .passwordReset(token: nil)
            
        case "onboarding":
            guard path.isEmpty else { return nil }; return .onboarding
            
        case "whats-new":
            guard path.isEmpty else { return nil }; return .whatsNew
        
        default:
            break
        }
        
        return nil
    }
    
    // MARK: - URL Generation
    
    /// Generate shareable URL for content
    func generateURL(for deepLink: DeepLink) -> URL? {
        let baseURL = "https://sweezy.app"
        
        switch deepLink {
        case .guide(let id):
            return URL(string: "\(baseURL)/guide/\(id)")
        
        case .checklist(let id):
            return URL(string: "\(baseURL)/checklist/\(id)")
        
        case .template(let id):
            return URL(string: "\(baseURL)/template/\(id)")
        
        case .place(let id):
            return URL(string: "\(baseURL)/place/\(id)")
        
        case .map(let filter):
            if let filter = filter {
                return URL(string: "\(baseURL)/map?filter=\(filter)")
            }
            return URL(string: "\(baseURL)/map")
        
        case .calculator:
            return URL(string: "\(baseURL)/calculator")
        
        case .appointments:
            return URL(string: "\(baseURL)/appointments")
        
        case .news:
            return URL(string: "\(baseURL)/news")
        case .cvBuilder:
            return URL(string: "\(baseURL)/cv")
        case .chat(let id):
            return URL(string: "\(baseURL)/chat/\(id)")
        
        case .settings:
            return URL(string: "\(baseURL)/settings")
        
        case .profile:
            return URL(string: "\(baseURL)/settings/profile")
        
        case .privacy:
            return URL(string: "\(baseURL)/settings/privacy")
        
        case .language:
            return URL(string: "\(baseURL)/settings/language")
        
        case .passwordReset:
            return URL(string: "\(baseURL)/auth/reset")
        
        case .onboarding:
            return URL(string: "\(baseURL)/onboarding")
        
        case .whatsNew:
            return URL(string: "\(baseURL)/whats-new")
        }
    }
    
    // MARK: - Share Helper
    
    /// Create share sheet for deep link
    func share(_ deepLink: DeepLink, from view: UIView) {
        guard let url = generateURL(for: deepLink) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // For iPad
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = view.bounds
        }
        
        // Present
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - SwiftUI Environment

struct DeepLinkEnvironmentKey: EnvironmentKey {
    static let defaultValue: DeepLinkService = .shared
}

extension EnvironmentValues {
    var deepLinkService: DeepLinkService {
        get { self[DeepLinkEnvironmentKey.self] }
        set { self[DeepLinkEnvironmentKey.self] = newValue }
    }
}

// MARK: - SwiftUI Modifiers

extension View {
    /// Handle deep links in this view
    func handleDeepLinks(perform action: @escaping (DeepLink) -> Void) -> some View {
        self.modifier(DeepLinkHandler(action: action))
    }
}

struct DeepLinkHandler: ViewModifier {
    @StateObject private var deepLinkService = DeepLinkService.shared
    let action: (DeepLink) -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: deepLinkService.activeDeepLink) { oldValue, newValue in
                if let deepLink = newValue, deepLinkService.shouldNavigate {
                    action(deepLink)
                    deepLinkService.clearDeepLink()
                }
            }
            .environment(\.deepLinkService, deepLinkService)
    }
}

// MARK: - Share Button Helper

struct ShareButton: View {
    let deepLink: DeepLink
    let label: String
    
    @State private var showShareSheet = false
    
    var body: some View {
        Button(action: {
            showShareSheet = true
        }) {
            Label(label, systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = DeepLinkService.shared.generateURL(for: deepLink) {
                DeepLinkShareSheet(items: [url])
            }
        }
    }
}

struct DeepLinkShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
