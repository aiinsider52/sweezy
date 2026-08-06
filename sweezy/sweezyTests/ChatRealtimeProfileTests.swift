import Foundation
import Testing
@testable import sweezy

struct ChatRealtimeProfileTests {
    @Test func decodesDeliveredAndReadMessageStates() throws {
        let delivered = Data("""
        {"id":"m1","conversation_id":"c1","sender_id":"u1","client_message_id":"client-01","kind":"text","body":"Hi","created_at":"2026-08-06T12:00:00Z","delivered_at":"2026-08-06T12:00:01Z"}
        """.utf8)
        let read = Data("""
        {"id":"m1","conversation_id":"c1","sender_id":"u1","client_message_id":"client-01","kind":"text","body":"Hi","created_at":"2026-08-06T12:00:00Z","delivered_at":"2026-08-06T12:00:01Z","read_at":"2026-08-06T12:00:02Z"}
        """.utf8)

        #expect(try ChatAPI.decoder.decode(ChatMessage.self, from: delivered).deliveryState == .delivered)
        #expect(try ChatAPI.decoder.decode(ChatMessage.self, from: read).deliveryState == .read)
    }

    @Test func decodesPrivacySafeProfileAndListingNavigationIdentity() throws {
        let data = Data("""
        {"user_id":"u1","display_name":"Anna K.","initials":"AK","avatar_url":null,"registered_month":"2026-08","is_verified":true,"trust_badges":["verified"],"average_rating":4.8,"review_count":12,"active_listings":[{"id":"l1","listing_type":"service","title":"Translation","category":"translation","canton":"ZH","price_info":"CHF 50","price_chf":null,"is_free":false,"image_urls":[],"is_verified":true}],"viewer_has_blocked":false}
        """.utf8)

        let profile = try JSONDecoder().decode(PublicUserProfile.self, from: data)
        #expect(profile.displayName == "Anna K.")
        #expect(profile.activeListings.first?.id == "l1")
        #expect(profile.activeListings.first?.title == "Translation")
    }
}
