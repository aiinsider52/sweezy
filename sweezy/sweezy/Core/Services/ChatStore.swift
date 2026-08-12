import Combine
import Foundation

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var conversations: [ChatConversation] = []
    @Published private(set) var messages: [String: [ChatMessage]] = [:]
    @Published private(set) var unreadCount = 0
    @Published private(set) var isConnected = false
    @Published private(set) var isLoading = false
    @Published private(set) var loadingOlderConversationIDs: Set<String> = []
    @Published private(set) var olderMessageConversationIDs: Set<String> = []
    @Published private(set) var hasMoreActiveConversations = false
    @Published private(set) var hasMoreArchivedConversations = false
    @Published private(set) var isLoadingMoreConversations = false
    @Published private(set) var conversationLoadError: String?
    @Published var typingConversationIDs: Set<String> = []
    @Published var errorMessage: String?
    /// Currently visible conversation — suppresses in-app banners for that thread.
    @Published private(set) var activeConversationID: String?

    private let cache = ChatCache()
    private let socket = ChatSocketService()
    private var activeUserID: String?
    private var started = false
    private var nextMessageCursor: [String: String] = [:]
    private var nextConversationCursor: [Bool: String] = [:]
    private var typingExpiryTasks: [String: Task<Void, Never>] = [:]
    private var fallbackPollingTask: Task<Void, Never>?

    init() {
        socket.onConnectionChange = { [weak self] connected in self?.isConnected = connected }
        socket.onEvent = { [weak self] event in self?.handle(event) }
    }

    func start() async {
        guard let userID = KeychainStore.get("user_id"), !userID.isEmpty else {
            stop()
            return
        }
        if activeUserID != userID {
            activeUserID = userID
            let snapshot = await cache.load(userID: userID)
            conversations = snapshot.conversations
            messages = snapshot.messages
        }
        if !started {
            started = true
            socket.connect()
        }
        await refresh()
    }

    func stop() {
        started = false
        activeUserID = nil
        socket.disconnect()
        conversations = []
        messages = [:]
        nextMessageCursor = [:]
        nextConversationCursor = [:]
        olderMessageConversationIDs = []
        loadingOlderConversationIDs = []
        hasMoreActiveConversations = false
        hasMoreArchivedConversations = false
        isLoadingMoreConversations = false
        conversationLoadError = nil
        unreadCount = 0
        typingConversationIDs = []
        typingExpiryTasks.values.forEach { $0.cancel() }
        typingExpiryTasks = [:]
        fallbackPollingTask?.cancel()
        fallbackPollingTask = nil
    }

    func reconnect() {
        guard started else { return }
        socket.reconnect()
    }

    func refresh() async {
        guard activeUserID != nil else { return }
        isLoading = conversations.isEmpty
        defer { isLoading = false }
        var failed = false
        do {
            let active = try await ChatAPI.conversations()
            setNextConversationCursor(active.nextCursor, archived: false)
            replaceConversations(with: active.items, archived: false)
        } catch {
            failed = true
        }
        do {
            let archived = try await ChatAPI.conversations(archived: true)
            setNextConversationCursor(archived.nextCursor, archived: true)
            replaceConversations(with: archived.items, archived: true)
        } catch {
            failed = true
        }
        conversations.sort { ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt) }
        unreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
        conversationLoadError = failed ? "chat.error.partial_load".localized : nil
        persist()
    }

    func loadMoreConversations(archived: Bool) async {
        guard let cursor = nextConversationCursor[archived], !isLoadingMoreConversations else { return }
        isLoadingMoreConversations = true
        defer { isLoadingMoreConversations = false }
        do {
            let page = try await ChatAPI.conversations(archived: archived, cursor: cursor)
            for conversation in page.items { upsert(conversation) }
            conversations.sort { ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt) }
            setNextConversationCursor(page.nextCursor, archived: archived)
            errorMessage = nil
            persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openConversation(for listingID: String) async throws -> ChatConversation {
        if let existing = conversations.first(where: { $0.listingID == listingID && !$0.archived }) {
            return existing
        }
        let conversation = try await ChatAPI.createConversation(listingID: listingID)
        upsert(conversation)
        persist()
        return conversation
    }

    func openJobConversation(for jobID: String) async throws -> ChatConversation {
        if let existing = conversations.first(where: { $0.jobID == jobID && !$0.archived }) {
            return existing
        }
        let conversation = try await ChatAPI.createJobConversation(jobID: jobID)
        upsert(conversation)
        persist()
        return conversation
    }

    func conversation(id: String) async -> ChatConversation? {
        if let cached = conversations.first(where: { $0.id == id }) { return cached }
        do {
            let remote = try await ChatAPI.conversation(id: id)
            upsert(remote)
            persist()
            return remote
        } catch {
            await refresh()
            return conversations.first(where: { $0.id == id })
        }
    }

    func setActiveConversation(_ id: String?) {
        activeConversationID = id
        fallbackPollingTask?.cancel()
        fallbackPollingTask = nil
        guard let id else { return }
        fallbackPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.isConnected == true ? 8 : 2))
                guard !Task.isCancelled else { return }
                await self?.loadMessages(conversationID: id, force: true)
            }
        }
    }

    func loadMessages(conversationID: String, force: Bool = false) async {
        if !force, messages[conversationID]?.isEmpty == false { return }
        do {
            let page = try await ChatAPI.messages(conversationID: conversationID)
            let pending = messages[conversationID, default: []].filter {
                $0.deliveryState == .sending || $0.deliveryState == .failed
            }
            messages[conversationID] = mergedMessages(page.items + pending)
            setNextMessageCursor(page.nextCursor, conversationID: conversationID)
            errorMessage = nil
            persist()
            await markLatestRead(conversationID: conversationID)
        } catch {
            if ChatAPI.isNotFound(error) {
                removeStaleConversation(conversationID)
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadOlderMessages(conversationID: String) async {
        guard let cursor = nextMessageCursor[conversationID],
              !loadingOlderConversationIDs.contains(conversationID) else { return }
        loadingOlderConversationIDs.insert(conversationID)
        defer { loadingOlderConversationIDs.remove(conversationID) }
        do {
            let page = try await ChatAPI.messages(conversationID: conversationID, before: cursor)
            messages[conversationID] = mergedMessages(page.items + messages[conversationID, default: []])
            setNextMessageCursor(page.nextCursor, conversationID: conversationID)
            errorMessage = nil
            persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send(_ body: String, in conversationID: String, clientMessageID: String = UUID().uuidString) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let userID = activeUserID else { return }
        let localID = "local-\(clientMessageID)"
        let optimistic = ChatMessage(
            id: localID,
            conversationID: conversationID,
            senderID: userID,
            clientMessageID: clientMessageID,
            body: trimmed,
            createdAt: Date(),
            deliveryState: .sending
        )
        replaceMessage(optimistic, matchingClientID: clientMessageID)
        do {
            let sent = try await ChatAPI.send(conversationID: conversationID, clientMessageID: clientMessageID, body: trimmed)
            replaceMessage(sent, matchingClientID: clientMessageID)
            updateConversationPreview(with: sent)
            errorMessage = nil
        } catch {
            var failed = optimistic
            failed.deliveryState = .failed
            replaceMessage(failed, matchingClientID: clientMessageID)
            errorMessage = error.localizedDescription
        }
        persist()
    }

    func retry(_ message: ChatMessage) async {
        await send(message.body, in: message.conversationID, clientMessageID: message.clientMessageID)
    }

    func markLatestRead(conversationID: String) async {
        guard let userID = activeUserID,
              let latest = messages[conversationID]?.last(where: { $0.senderID != userID }) else { return }
        do {
            try await ChatAPI.markRead(conversationID: conversationID, messageID: latest.id)
            if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
                unreadCount = max(0, unreadCount - conversations[index].unreadCount)
                conversations[index].unreadCount = 0
            }
            persist()
        } catch {
            // Read receipt retries after next refresh/open. Message delivery stays unaffected.
        }
    }

    func setTyping(_ value: Bool, conversationID: String) {
        socket.sendTyping(conversationID: conversationID, isTyping: value)
    }

    func setArchived(_ archived: Bool, conversationID: String) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let previousValue = conversations[index].archived
        conversations[index].archived = archived
        errorMessage = nil
        persist()

        do {
            let updated = try await ChatAPI.update(conversationID: conversationID, archived: archived)
            upsert(updated)
            persist()
        } catch {
            if ChatAPI.isNotFound(error) {
                removeStaleConversation(conversationID)
                await refresh()
            } else {
                if let rollbackIndex = conversations.firstIndex(where: { $0.id == conversationID }) {
                    conversations[rollbackIndex].archived = previousValue
                }
                errorMessage = "chat.error.update_failed".localized
                persist()
            }
        }
    }

    func setMuted(_ muted: Bool, conversationID: String) async {
        do {
            let updated = try await ChatAPI.update(conversationID: conversationID, muted: muted)
            upsert(updated)
            persist()
        } catch { errorMessage = error.localizedDescription }
    }

    func closeDeal(conversationID: String) async throws {
        let updated = try await ChatAPI.close(conversationID: conversationID)
        upsert(updated)
        await loadMessages(conversationID: conversationID, force: true)
        persist()
    }

    func report(messageID: String, reason: String) async throws {
        try await ChatAPI.report(messageID: messageID, reason: reason)
    }

    func block(conversationID: String) async throws {
        try await ChatAPI.block(conversationID: conversationID)
        conversations.removeAll { $0.id == conversationID }
        unreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
        persist()
    }

    func review(conversationID: String, rating: Int, comment: String?) async throws {
        try await ChatAPI.review(conversationID: conversationID, rating: rating, comment: comment)
    }

    private func handle(_ event: ChatSocketEvent) {
        guard event.type != "connected" else { return }
        if let conversationID = event.conversationID,
           let messageID = event.messageID,
           event.type == "message.delivered" || event.type == "message.read" {
            var items = messages[conversationID, default: []]
            guard let receiptIndex = items.firstIndex(where: { $0.id == messageID }) else { return }
            let receiptDate = event.readAt ?? event.deliveredAt ?? Date()
            let cutoff = items[receiptIndex].createdAt
            for index in items.indices where items[index].senderID == activeUserID && items[index].createdAt <= cutoff {
                let old = items[index]
                items[index] = ChatMessage(
                    id: old.id,
                    conversationID: old.conversationID,
                    senderID: old.senderID,
                    clientMessageID: old.clientMessageID,
                    kind: old.kind,
                    body: old.body,
                    createdAt: old.createdAt,
                    deliveredAt: event.type == "message.read" ? (old.deliveredAt ?? receiptDate) : receiptDate,
                    readAt: event.type == "message.read" ? receiptDate : old.readAt,
                    editedAt: old.editedAt,
                    deletedAt: old.deletedAt,
                    deliveryState: event.type == "message.read" ? .read : .delivered
                )
            }
            messages[conversationID] = items
            persist()
            return
        }
        if let conversationID = event.conversationID, event.type == "typing" {
            typingExpiryTasks[conversationID]?.cancel()
            if event.isTyping == true {
                typingConversationIDs.insert(conversationID)
                typingExpiryTasks[conversationID] = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(6))
                    guard !Task.isCancelled else { return }
                    self?.typingConversationIDs.remove(conversationID)
                    self?.typingExpiryTasks[conversationID] = nil
                }
            } else {
                typingConversationIDs.remove(conversationID)
                typingExpiryTasks[conversationID] = nil
            }
            return
        }
        if let message = event.message {
            let alreadyKnown = messages[message.conversationID, default: []].contains {
                $0.id == message.id || $0.clientMessageID == message.clientMessageID
            }
            replaceMessage(message, matchingClientID: message.clientMessageID)
            updateConversationPreview(with: message)
            if message.senderID != activeUserID, !alreadyKnown {
                unreadCount += 1
                if let index = conversations.firstIndex(where: { $0.id == message.conversationID }) {
                    conversations[index].unreadCount += 1
                } else {
                    Task { await refresh() }
                }
                if activeConversationID != message.conversationID {
                    ChatInAppNotifier.shared.present(
                        conversationID: message.conversationID,
                        title: conversations.first(where: { $0.id == message.conversationID })?.otherUserName
                            ?? "chat.notification.title".localized,
                        body: message.body
                    )
                }
            }
            typingConversationIDs.remove(message.conversationID)
            typingExpiryTasks[message.conversationID]?.cancel()
            typingExpiryTasks[message.conversationID] = nil
            persist()
        }
        if event.type == "conversation.closed" {
            Task { await refresh() }
        }
    }

    private func updateConversationPreview(with message: ChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == message.conversationID }) else {
            Task { await refresh() }
            return
        }
        conversations[index].lastMessagePreview = message.body
        conversations[index].lastMessageSenderID = message.senderID
        conversations[index].lastMessageAt = message.createdAt
        conversations.sort { ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt) }
    }

    private func replaceMessage(_ message: ChatMessage, matchingClientID: String) {
        var items = messages[message.conversationID, default: []]
        if let index = items.firstIndex(where: { $0.clientMessageID == matchingClientID || $0.id == message.id }) {
            items[index] = message
        } else {
            items.append(message)
        }
        items.sort { $0.createdAt < $1.createdAt }
        messages[message.conversationID] = items
    }

    private func mergedMessages(_ values: [ChatMessage]) -> [ChatMessage] {
        var byIdentity: [String: ChatMessage] = [:]
        for message in values {
            let key = "\(message.senderID):\(message.clientMessageID)"
            if let existing = byIdentity[key] {
                let rank: [ChatDeliveryState: Int] = [.failed: 0, .sending: 1, .sent: 2, .delivered: 3, .read: 4]
                if rank[existing.deliveryState, default: 0] > rank[message.deliveryState, default: 0] { continue }
            }
            byIdentity[key] = message
        }
        return byIdentity.values.sorted { $0.createdAt < $1.createdAt }
    }

    private func setNextMessageCursor(_ cursor: String?, conversationID: String) {
        nextMessageCursor[conversationID] = cursor
        if cursor == nil { olderMessageConversationIDs.remove(conversationID) }
        else { olderMessageConversationIDs.insert(conversationID) }
    }

    private func setNextConversationCursor(_ cursor: String?, archived: Bool) {
        nextConversationCursor[archived] = cursor
        if archived { hasMoreArchivedConversations = cursor != nil }
        else { hasMoreActiveConversations = cursor != nil }
    }

    private func replaceConversations(with values: [ChatConversation], archived: Bool) {
        conversations.removeAll { $0.archived == archived }
        conversations.append(contentsOf: values)
    }

    private func upsert(_ conversation: ChatConversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        unreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
    }

    private func removeStaleConversation(_ conversationID: String) {
        conversations.removeAll { $0.id == conversationID }
        messages[conversationID] = nil
        nextMessageCursor[conversationID] = nil
        olderMessageConversationIDs.remove(conversationID)
        loadingOlderConversationIDs.remove(conversationID)
        typingConversationIDs.remove(conversationID)
        typingExpiryTasks[conversationID]?.cancel()
        typingExpiryTasks[conversationID] = nil
        unreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
        errorMessage = nil
        persist()
    }

    private func persist() {
        guard let userID = activeUserID else { return }
        let conversations = conversations
        let messages = messages
        Task { await cache.save(userID: userID, conversations: conversations, messages: messages) }
    }
}
