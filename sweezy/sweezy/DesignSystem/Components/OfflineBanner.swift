import SwiftUI
import Network

final class GlobalNetworkMonitor: ObservableObject {
    static let shared = GlobalNetworkMonitor()
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}

struct OfflineBanner: View {
    @ObservedObject private var networkMonitor = GlobalNetworkMonitor.shared
    
    var body: some View {
        if !networkMonitor.isOnline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                Text("offline.banner".localized)
                    .font(Theme.Typography.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.warning.opacity(0.9))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
