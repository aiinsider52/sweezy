//
//  SubscriptionLiveService.swift
//  sweezy
//
//  Lightweight SSE-style listener to refresh subscription status in near real time.
//

import Foundation

@MainActor
final class SubscriptionLiveService {
    private var task: Task<Void, Never>?
    private let session: URLSession
    private weak var subscriptionManager: SubscriptionManager?
    
    init(subscriptionManager: SubscriptionManager, session: URLSession = .shared) {
        self.subscriptionManager = subscriptionManager
        self.session = session
    }
    
    func start() {
        stop()
        task = Task { [weak self] in
            guard let self else { return }
            guard let url = URL(string: "\(APIClient.baseURL.absoluteString)/subscriptions/stream") else { return }
            var request = URLRequest(url: url)
            request.timeoutInterval = 60 * 60
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            APIClient.attachAuth(&request)
            do {
                let (bytes, _) = try await session.bytes(for: request)
                var iterator = bytes.lines.makeAsyncIterator()
                var currentEvent: String?
                while let line = try await iterator.next() {
                    if line.hasPrefix("event:") {
                        currentEvent = line.replacingOccurrences(of: "event:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        let dataLine = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                        if currentEvent == "update" {
                            // Notify UI and refresh local entitlements
                            NotificationCenter.default.post(name: .subscriptionLiveUpdated, object: nil, userInfo: ["data": dataLine])
                            await self.subscriptionManager?.load()
                        }
                    } else if line.isEmpty {
                        currentEvent = nil
                    }
                    if Task.isCancelled { break }
                }
            } catch {
                // Retry after delay on error
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if !Task.isCancelled { start() }
            }
        }
    }
    
    func stop() {
        task?.cancel()
        task = nil
    }
}

extension Notification.Name {
    static let subscriptionLiveUpdated = Notification.Name("subscription_live_updated")
}


