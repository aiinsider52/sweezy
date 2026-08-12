import Foundation
import Testing
@testable import sweezy

struct SecurityHardeningTests {
    @Test func universalLinksRequireTrustedHostAndExactPath() {
        let service = DeepLinkService.shared
        #expect(service.parse(url: URL(string: "https://sweezy.app/guide/abc-123")!) == .guide(id: "abc-123"))
        #expect(service.parse(url: URL(string: "https://evil.example/guide/abc-123")!) == nil)
        #expect(service.parse(url: URL(string: "https://sweezy.app/guide/abc-123/extra")!) == nil)
        #expect(service.parse(url: URL(string: "https://sweezy.app/guide/%2Fetc")!) == nil)
    }

    @Test func passwordResetLinkNeverPrefillsCredential() {
        let service = DeepLinkService.shared
        #expect(
            service.parse(url: URL(string: "https://sweezy.app/auth/reset?token=secret&otp=123456")!)
                == .passwordReset(token: nil)
        )
        #expect(service.generateURL(for: .passwordReset(token: "secret"))?.query == nil)
    }

    @Test func customSchemeRejectsUnknownRoutes() {
        let service = DeepLinkService.shared
        #expect(service.parse(url: URL(string: "sweezy://chat/conversation_1")!) == .chat(id: "conversation_1"))
        #expect(service.parse(url: URL(string: "sweezy://chat/conversation.1")!) == nil)
        #expect(service.parse(url: URL(string: "ftp://sweezy.app/chat/conversation_1")!) == nil)
    }

    @Test func supportedDeepLinksSelectTheirOwningTab() {
        #expect(DeepLink.guide(id: "guide-1").rootTabIndex == 1)
        #expect(DeepLink.cvBuilder.rootTabIndex == 1)
        #expect(DeepLink.map(filter: "nature").rootTabIndex == 2)
        #expect(DeepLink.place(id: "zurich").rootTabIndex == 2)
        #expect(DeepLink.profile.rootTabIndex == 4)
        #expect(DeepLink.news.rootTabIndex == 0)
        #expect(DeepLink.chat(id: "conversation_1").rootTabIndex == nil)
    }
}
