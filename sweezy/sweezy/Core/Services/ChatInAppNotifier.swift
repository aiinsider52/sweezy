import Foundation
import UserNotifications

/// Foreground/local banners for chat while remote APNs may still be disabled.
@MainActor
final class ChatInAppNotifier {
    static let shared = ChatInAppNotifier()

    private init() {}

    func present(conversationID: String, title: String, body: String) {
        guard NotificationPreference.isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = Self.preview(body)
        content.sound = .default
        content.userInfo = [
            "type": "chat_message",
            "conversation_id": conversationID,
        ]
        let request = UNNotificationRequest(
            identifier: "chat-\(conversationID)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private static func preview(_ body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "chat.notification.body_fallback".localized }
        return trimmed.count > 120 ? String(trimmed.prefix(117)) + "…" : trimmed
    }
}
