import SwiftUI
import os.log

/// Universal safe root wrapper that ensures the app always shows something visible.
/// Shows a loading indicator immediately and fades it out once the content view appears.
struct SafeRootContainer<Content: View>: View {
    let content: () -> Content
    @State private var contentAppeared = false
    @State private var showFallback = true
    private let logger = Logger(subsystem: "app.sweezy", category: "SafeRoot")
    private let timeoutSeconds: Double = 4.0
    
    var body: some View {
        ZStack {
            // Always show a visible background first
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if showFallback {
                // Loading indicator while content is being prepared
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.secondary)
                    Text("Завантаження...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
            
            // Build content lazily to avoid doing heavy work before fallback is visible
            content()
                .opacity(contentAppeared ? 1 : 0)
                .onAppear {
                    contentAppeared = true
                    withAnimation(.easeOut(duration: 0.25)) {
                        showFallback = false
                    }
                    logger.debug("SafeRoot: content appeared")
                }
        }
        .task {
            // Watchdog: if nothing appears within timeout, keep fallback on screen (prevents white screen)
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            if !contentAppeared {
                logger.error("SafeRoot: content did not appear within \(self.timeoutSeconds, privacy: .public)s. Keeping fallback visible.")
                showFallback = true
            }
        }
    }
}

/// Public helper to wrap any root view.
@ViewBuilder
func safeRoot<Content: View>(_ view: @autoclosure @escaping () -> Content) -> some View {
    SafeRootContainer(content: view)
}
