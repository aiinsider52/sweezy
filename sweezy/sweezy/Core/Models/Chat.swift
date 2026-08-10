import Foundation

enum ChatDeliveryState: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

struct ChatConversation: Codable, Identifiable, Equatable {
    let id: String
    let listingID: String?
    let jobID: String?
    let networkProfileID: String?
    let socialProfileID: String?
    let listingType: String
    let listingTitle: String
    let listingImageURL: String?
    let listingPrice: String?
    let listingStatus: String
    let otherUserID: String
    let otherUserName: String
    let isSeller: Bool
    let status: String
    var lastMessagePreview: String?
    var lastMessageSenderID: String?
    var lastMessageAt: Date?
    var unreadCount: Int
    var muted: Bool
    var archived: Bool
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, status, muted, archived
        case listingID = "listing_id"
        case jobID = "job_id"
        case networkProfileID = "network_profile_id"
        case socialProfileID = "social_profile_id"
        case listingType = "listing_type"
        case listingTitle = "listing_title"
        case listingImageURL = "listing_image_url"
        case listingPrice = "listing_price"
        case listingStatus = "listing_status"
        case otherUserID = "other_user_id"
        case otherUserName = "other_user_name"
        case isSeller = "is_seller"
        case lastMessagePreview = "last_message_preview"
        case lastMessageSenderID = "last_message_sender_id"
        case lastMessageAt = "last_message_at"
        case unreadCount = "unread_count"
        case createdAt = "created_at"
    }

    var isClosed: Bool { status == "closed" }
    var isListingUnavailable: Bool { ["removed", "sold", "completed"].contains(listingStatus) }
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let conversationID: String
    let senderID: String
    let clientMessageID: String
    let kind: String
    let body: String
    let createdAt: Date
    let deliveredAt: Date?
    let readAt: Date?
    let editedAt: Date?
    let deletedAt: Date?
    var deliveryState: ChatDeliveryState

    init(
        id: String,
        conversationID: String,
        senderID: String,
        clientMessageID: String,
        kind: String = "text",
        body: String,
        createdAt: Date,
        deliveredAt: Date? = nil,
        readAt: Date? = nil,
        editedAt: Date? = nil,
        deletedAt: Date? = nil,
        deliveryState: ChatDeliveryState = .sent
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.clientMessageID = clientMessageID
        self.kind = kind
        self.body = body
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.readAt = readAt
        self.editedAt = editedAt
        self.deletedAt = deletedAt
        self.deliveryState = deliveryState
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, body
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case clientMessageID = "client_message_id"
        case createdAt = "created_at"
        case deliveredAt = "delivered_at"
        case readAt = "read_at"
        case editedAt = "edited_at"
        case deletedAt = "deleted_at"
        case deliveryState = "delivery_state"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        conversationID = try container.decode(String.self, forKey: .conversationID)
        senderID = try container.decode(String.self, forKey: .senderID)
        clientMessageID = try container.decode(String.self, forKey: .clientMessageID)
        kind = try container.decode(String.self, forKey: .kind)
        body = try container.decode(String.self, forKey: .body)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        deliveryState = try container.decodeIfPresent(ChatDeliveryState.self, forKey: .deliveryState)
            ?? (readAt != nil ? .read : (deliveredAt != nil ? .delivered : .sent))
    }
}

struct ChatConversationPage: Decodable {
    let items: [ChatConversation]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct ChatMessagePage: Decodable {
    let items: [ChatMessage]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct ChatSocketEvent: Decodable {
    let type: String
    let conversationID: String?
    let message: ChatMessage?
    let messageID: String?
    let readerID: String?
    let deliveredAt: Date?
    let readAt: Date?
    let isTyping: Bool?

    private enum CodingKeys: String, CodingKey {
        case type, message
        case conversationID = "conversation_id"
        case messageID = "message_id"
        case readerID = "reader_id"
        case deliveredAt = "delivered_at"
        case readAt = "read_at"
        case isTyping = "is_typing"
    }
}
