import Foundation

@MainActor
final class ChatSocketService {
    var onEvent: ((ChatSocketEvent) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var shouldRun = false
    private var reconnectAttempt = 0

    func connect() {
        guard !shouldRun else { return }
        shouldRun = true
        openSocket()
    }

    func reconnect() {
        disconnect()
        connect()
    }

    func disconnect() {
        shouldRun = false
        receiveTask?.cancel()
        heartbeatTask?.cancel()
        reconnectTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        onConnectionChange?(false)
    }

    func sendTyping(conversationID: String, isTyping: Bool) {
        let payload: [String: Any] = ["type": "typing", "conversation_id": conversationID, "is_typing": isTyping]
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let text = String(data: data, encoding: .utf8) else { return }
        Task { try? await socket?.send(.string(text)) }
    }

    private func openSocket() {
        guard shouldRun, socket == nil, let request = ChatAPI.webSocketRequest() else { return }
        let task = URLSession.shared.webSocketTask(with: request)
        socket = task
        task.resume()
        receiveTask = Task { [weak self] in await self?.receiveLoop() }
        heartbeatTask = Task { [weak self] in await self?.heartbeatLoop() }
    }

    private func receiveLoop() async {
        guard let socket else { return }
        do {
            while shouldRun {
                let message = try await socket.receive()
                let data: Data
                switch message {
                case .data(let value): data = value
                case .string(let value): data = Data(value.utf8)
                @unknown default: continue
                }
                if let event = try? ChatAPI.decoder.decode(ChatSocketEvent.self, from: data) {
                    reconnectAttempt = 0
                    if event.type == "connected" { onConnectionChange?(true) }
                    onEvent?(event)
                }
            }
        } catch {
            socketDidClose()
        }
    }

    private func heartbeatLoop() async {
        while shouldRun {
            try? await Task.sleep(for: .seconds(25))
            guard shouldRun else { return }
            do {
                try await socket?.send(.string("{\"type\":\"ping\"}"))
            } catch {
                socketDidClose()
                return
            }
        }
    }

    private func socketDidClose() {
        guard shouldRun else { return }
        receiveTask?.cancel()
        heartbeatTask?.cancel()
        socket = nil
        onConnectionChange?(false)
        reconnectAttempt += 1
        let delay = min(30, pow(2, Double(min(reconnectAttempt, 5))))
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.shouldRun else { return }
            self.openSocket()
        }
    }
}
