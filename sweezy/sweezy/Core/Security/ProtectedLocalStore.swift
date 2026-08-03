import Foundation

enum ProtectedLocalStore {
    private static let directoryName = "ProtectedData"

    static func data(for key: String, migratingFrom defaultsKey: String? = nil) -> Data? {
        let url = fileURL(for: key)
        if let data = try? Data(contentsOf: url) {
            ensureProtection(at: url)
            return data
        }
        guard let defaultsKey, let legacy = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        do {
            try write(legacy, for: key)
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            return legacy
        } catch {
            return legacy // Soft migration: never discard the only readable copy.
        }
    }

    static func write(_ data: Data, for key: String) throws {
        let url = fileURL(for: key)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        ensureProtection(at: url)
    }

    static func remove(_ key: String, legacyDefaultsKey: String? = nil) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
        if let legacyDefaultsKey { UserDefaults.standard.removeObject(forKey: legacyDefaultsKey) }
    }

    static func fileURL(for key: String) -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let safeKey = key.map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" }
        return root.appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(String(safeKey), isDirectory: false)
    }

    static func protectExistingFile(at url: URL) {
        ensureProtection(at: url)
    }

    private static func ensureProtection(at url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }
}
