import Foundation

actor ChatCache {
    private struct Snapshot: Codable {
        var conversations: [ChatConversation]
        var messages: [String: [ChatMessage]]
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder = ChatAPI.decoder

    private func fileURL(userID: String) -> URL? {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let directory = root.appendingPathComponent("SweezyChat", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scope = String(userID.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" })
        return directory.appendingPathComponent("\(scope).json")
    }

    func load(userID: String) -> (conversations: [ChatConversation], messages: [String: [ChatMessage]]) {
        guard let fileURL = fileURL(userID: userID),
              let data = try? Data(contentsOf: fileURL),
              let snapshot = try? decoder.decode(Snapshot.self, from: data) else {
            return ([], [:])
        }
        return (snapshot.conversations, snapshot.messages)
    }

    func save(userID: String, conversations: [ChatConversation], messages: [String: [ChatMessage]]) {
        guard let fileURL = fileURL(userID: userID),
              let data = try? encoder.encode(Snapshot(conversations: conversations, messages: messages)) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func clear(userID: String) {
        guard let fileURL = fileURL(userID: userID) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
