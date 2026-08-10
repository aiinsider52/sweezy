import SwiftUI

struct ChatInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @State private var selectedConversation: ChatConversation?
    @State private var showArchived = false

    private var visibleConversations: [ChatConversation] {
        appContainer.chatStore.conversations.filter { $0.archived == showArchived }
    }

    var body: some View {
        ZStack {
            JourneyVisual.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                connectionStatus
                if appContainer.chatStore.isLoading && visibleConversations.isEmpty {
                    loadingState
                } else if visibleConversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
        }
        .task { await appContainer.chatStore.start() }
        .fullScreenCover(item: $selectedConversation) { conversation in
            ChatConversationView(conversation: conversation)
                .environmentObject(appContainer)
        }
        .alert("chat.inbox.title".localized, isPresented: Binding(
            get: { appContainer.chatStore.errorMessage != nil },
            set: { if !$0 { appContainer.chatStore.errorMessage = nil } }
        )) {
            Button("common.ok".localized, role: .cancel) { appContainer.chatStore.errorMessage = nil }
        } message: {
            Text(appContainer.chatStore.errorMessage ?? "")
        }
        .interactiveSwipeBackEnabled()
    }

    private var header: some View {
        VStack(spacing: 18) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 46, height: 46)
                        .background(Color.white.opacity(0.09))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(spacing: 2) {
                    Text("chat.inbox.title".localized)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("chat.inbox.subtitle".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.52))
                }
                Spacer()
                Button { Task { await appContainer.chatStore.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 46, height: 46)
                        .background(Color.white.opacity(0.09))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                inboxSegment("chat.inbox.active".localized, selected: !showArchived) { showArchived = false }
                inboxSegment("chat.inbox.archive".localized, selected: showArchived) { showArchived = true }
            }
            .padding(4)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func inboxSegment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(selected ? .black : .white.opacity(0.68))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(selected ? JourneyVisual.lime : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var connectionStatus: some View {
        if !appContainer.chatStore.isConnected {
            HStack(spacing: 7) {
                ProgressView().tint(JourneyVisual.lime).controlSize(.small)
                Text("chat.connection.reconnecting".localized)
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.64))
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
    }

    private var conversationList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(visibleConversations) { conversation in
                    HStack(spacing: 8) {
                        Button { selectedConversation = conversation } label: {
                            ChatConversationRow(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                        Menu {
                            Button {
                                Task { await appContainer.chatStore.setArchived(!showArchived, conversationID: conversation.id) }
                            } label: {
                                Label(showArchived ? "chat.action.restore".localized : "chat.action.archive".localized,
                                      systemImage: showArchived ? "tray.and.arrow.up" : "archivebox")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.65))
                                .frame(width: 38, height: 66)
                                .background(Color.white.opacity(0.065))
                                .clipShape(Capsule())
                        }
                    }
                }
                if showArchived ? appContainer.chatStore.hasMoreArchivedConversations : appContainer.chatStore.hasMoreActiveConversations {
                    Button {
                        Task { await appContainer.chatStore.loadMoreConversations(archived: showArchived) }
                    } label: {
                        HStack(spacing: 8) {
                            if appContainer.chatStore.isLoadingMoreConversations {
                                ProgressView().tint(JourneyVisual.lime).controlSize(.small)
                            }
                            Text("chat.action.show_more".localized)
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(JourneyVisual.lime)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(JourneyVisual.lime.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(appContainer.chatStore.isLoadingMoreConversations)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 34)
        }
        .refreshable { await appContainer.chatStore.refresh() }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(JourneyVisual.lime)
            Text("chat.inbox.loading".localized)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: showArchived ? "archivebox" : "bubble.left.and.bubble.right.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundColor(JourneyVisual.lime)
            Text(showArchived ? "chat.inbox.empty_archive.title".localized : "chat.inbox.empty.title".localized)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(showArchived
                 ? "chat.inbox.empty_archive.body".localized
                 : "chat.inbox.empty.body".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ChatConversationRow: View {
    let conversation: ChatConversation

    var body: some View {
        HStack(spacing: 13) {
            listingImage
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(conversation.otherUserName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(relativeDate)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.45))
                }
                Text(conversation.listingTitle)
                    .font(.caption.bold())
                    .foregroundColor(JourneyVisual.lime)
                    .lineLimit(1)
                HStack {
                    Text(conversation.lastMessagePreview ?? "chat.conversation.new".localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(conversation.unreadCount > 0 ? 0.88 : 0.55))
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(min(conversation.unreadCount, 99))")
                            .font(.caption2.bold())
                            .foregroundColor(.black)
                            .frame(minWidth: 24, minHeight: 24)
                            .background(JourneyVisual.lime)
                            .clipShape(Circle())
                    } else if conversation.muted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.38))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private var listingImage: some View {
        if let raw = conversation.listingImageURL, let url = APIClient.resolveMediaURL(raw) {
            CachedAsyncImage(url: url) { fallback }
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        } else { fallback }
    }

    private var fallback: some View {
        ZStack {
            JourneyVisual.lime.opacity(0.14)
            Image(systemName: conversation.listingType == "item" ? "shippingbox.fill" : "person.2.fill")
                .foregroundColor(JourneyVisual.lime)
        }
        .frame(width: 66, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var relativeDate: String {
        guard let date = conversation.lastMessageAt else { return "" }
        return date.formatted(.relative(presentation: .named))
    }
}

struct ChatConversationView: View {
    let conversation: ChatConversation

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @State private var draft = ""
    @State private var typingTask: Task<Void, Never>?
    @State private var selectedReportMessage: ChatMessage?
    @State private var showReportDialog = false
    @State private var showBlockConfirmation = false
    @State private var showReview = false
    @State private var showProfile = false
    @State private var actionMessage: String?

    private var currentConversation: ChatConversation {
        appContainer.chatStore.conversations.first(where: { $0.id == conversation.id }) ?? conversation
    }

    private var threadMessages: [ChatMessage] {
        appContainer.chatStore.messages[conversation.id] ?? []
    }

    private var currentUserID: String { KeychainStore.get("user_id") ?? "" }

    var body: some View {
        ZStack {
            JourneyVisual.black.ignoresSafeArea()
            VStack(spacing: 0) {
                conversationHeader
                listingContext
                messagesList
                if !currentConversation.isClosed { quickReplies }
                composer
            }
        }
        .task {
            appContainer.chatStore.setActiveConversation(conversation.id)
            await appContainer.chatStore.loadMessages(conversationID: conversation.id, force: true)
            if !appContainer.chatStore.conversations.contains(where: { $0.id == conversation.id }) {
                dismiss()
            }
        }
        .onChange(of: threadMessages.count) { _, _ in
            Task { await appContainer.chatStore.markLatestRead(conversationID: conversation.id) }
        }
        .onDisappear {
            typingTask?.cancel()
            appContainer.chatStore.setTyping(false, conversationID: conversation.id)
            if appContainer.chatStore.activeConversationID == conversation.id {
                appContainer.chatStore.setActiveConversation(nil)
            }
        }
        .confirmationDialog("chat.report.title".localized, isPresented: $showReportDialog) {
            Button("chat.report.fraud".localized) { report(reason: "fraud") }
            Button("chat.report.harassment".localized) { report(reason: "harassment") }
            Button("chat.report.spam".localized) { report(reason: "spam") }
            Button("chat.report.unsafe".localized) { report(reason: "unsafe") }
            Button("common.cancel".localized, role: .cancel) {}
        }
        .confirmationDialog("chat.block.title".localized, isPresented: $showBlockConfirmation) {
            Button("chat.action.block".localized, role: .destructive) { blockUser() }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("chat.block.body".localized)
        }
        .sheet(isPresented: $showReview) {
            ChatReviewSheet(conversationID: conversation.id)
                .environmentObject(appContainer)
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showProfile) {
            PublicProfileView(
                userID: currentConversation.otherUserID,
                listingID: currentConversation.listingID,
                conversationID: currentConversation.id
            )
            .environmentObject(appContainer)
        }
        .alert("Sweezy", isPresented: Binding(
            get: { actionMessage != nil },
            set: { if !$0 { actionMessage = nil } }
        )) {
            Button("common.ok".localized, role: .cancel) { actionMessage = nil }
        } message: { Text(actionMessage ?? "") }
        .interactiveSwipeBackEnabled()
    }

    private var conversationHeader: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Button { showProfile = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(currentConversation.otherUserName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                Text(appContainer.chatStore.typingConversationIDs.contains(conversation.id)
                     ? "chat.status.typing".localized
                     : (appContainer.chatStore.isConnected ? "chat.status.secure".localized : "chat.status.connecting".localized))
                    .font(.caption)
                    .foregroundColor(appContainer.chatStore.typingConversationIDs.contains(conversation.id) ? JourneyVisual.lime : .white.opacity(0.48))
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Menu {
                Button {
                    Task { await appContainer.chatStore.setMuted(!currentConversation.muted, conversationID: conversation.id) }
                } label: {
                    Label(currentConversation.muted ? "chat.action.unmute".localized : "chat.action.mute".localized,
                          systemImage: currentConversation.muted ? "bell" : "bell.slash")
                }
                Button {
                    Task { await appContainer.chatStore.setArchived(true, conversationID: conversation.id); dismiss() }
                } label: { Label("chat.action.archive".localized, systemImage: "archivebox") }
                if currentConversation.isSeller && !currentConversation.isClosed {
                    Button { closeDeal() } label: { Label("chat.action.close_deal".localized, systemImage: "checkmark.seal") }
                }
                if currentConversation.isClosed {
                    Button { showReview = true } label: { Label("chat.action.review".localized, systemImage: "star") }
                }
                Button(role: .destructive) { showBlockConfirmation = true } label: {
                    Label("chat.action.block".localized, systemImage: "person.crop.circle.badge.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var listingContext: some View {
        HStack(spacing: 12) {
            ZStack {
                JourneyVisual.lime.opacity(0.14)
                Image(systemName: currentConversation.listingType == "item" ? "shippingbox.fill" : "person.2.fill")
                    .foregroundColor(JourneyVisual.lime)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(currentConversation.listingTitle)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 7) {
                    if let price = currentConversation.listingPrice {
                        Text(price).foregroundColor(JourneyVisual.lime)
                    }
                    if currentConversation.isListingUnavailable {
                        Text("chat.listing.closed".localized).foregroundColor(.orange)
                    }
                }
                .font(.caption.bold())
            }
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(JourneyVisual.lime)
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 9) {
                    if appContainer.chatStore.olderMessageConversationIDs.contains(conversation.id) {
                        Button {
                            Task { await appContainer.chatStore.loadOlderMessages(conversationID: conversation.id) }
                        } label: {
                            HStack(spacing: 8) {
                                if appContainer.chatStore.loadingOlderConversationIDs.contains(conversation.id) {
                                    ProgressView().tint(JourneyVisual.lime).controlSize(.small)
                                } else {
                                    Image(systemName: "clock.arrow.circlepath")
                                }
                                Text("chat.action.load_older".localized)
                            }
                            .font(.caption.bold())
                            .foregroundColor(JourneyVisual.lime)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(JourneyVisual.lime.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(appContainer.chatStore.loadingOlderConversationIDs.contains(conversation.id))
                    }
                    safetyBanner
                    ForEach(threadMessages) { message in
                        ChatMessageBubble(message: message, isMine: message.senderID == currentUserID) {
                            Task { await appContainer.chatStore.retry(message) }
                        }
                        .id(message.id)
                        .contextMenu {
                            if message.senderID != currentUserID && message.kind == "text" {
                                Button(role: .destructive) {
                                    selectedReportMessage = message
                                    showReportDialog = true
                                } label: { Label("chat.action.report".localized, systemImage: "exclamationmark.bubble") }
                            }
                        }
                    }
                    if appContainer.chatStore.typingConversationIDs.contains(conversation.id) {
                        TypingBubble()
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: threadMessages.last?.id) { _, _ in
                if let last = threadMessages.last {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var safetyBanner: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "shield.lefthalf.filled").foregroundColor(JourneyVisual.lime)
            Text("chat.safety.body".localized)
                .font(.caption)
                .foregroundColor(.white.opacity(0.62))
        }
        .padding(12)
        .background(JourneyVisual.lime.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var quickReplies: some View {
        if threadMessages.filter({ $0.kind == "text" }).count < 3 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["chat.quick.available".localized, "chat.quick.when".localized, "chat.quick.delivery".localized], id: \.self) { text in
                        Button(text) { draft = text }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 7)
        }
    }

    @ViewBuilder
    private var composer: some View {
        if currentConversation.isClosed {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundColor(JourneyVisual.lime)
                Text("chat.deal.closed.title".localized)
                    .font(.subheadline.bold())
                Spacer()
                Button("chat.action.review_short".localized) { showReview = true }
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(JourneyVisual.lime)
                    .clipShape(Capsule())
            }
            .foregroundColor(.white)
            .padding(14)
            .background(.ultraThinMaterial)
        } else {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("chat.composer.placeholder".localized, text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onChange(of: draft) { _, value in typingChanged(!value.isEmpty) }
                Button { sendDraft() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.black)
                        .frame(width: 46, height: 46)
                        .background(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : JourneyVisual.lime)
                        .clipShape(Circle())
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    private func sendDraft() {
        let body = draft
        draft = ""
        appContainer.chatStore.setTyping(false, conversationID: conversation.id)
        Task { await appContainer.chatStore.send(body, in: conversation.id) }
    }

    private func typingChanged(_ isTyping: Bool) {
        typingTask?.cancel()
        appContainer.chatStore.setTyping(isTyping, conversationID: conversation.id)
        guard isTyping else { return }
        typingTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            appContainer.chatStore.setTyping(false, conversationID: conversation.id)
        }
    }

    private func report(reason: String) {
        guard let selectedReportMessage else { return }
        Task {
            do {
                try await appContainer.chatStore.report(messageID: selectedReportMessage.id, reason: reason)
                actionMessage = "chat.report.sent".localized
            } catch { actionMessage = error.localizedDescription }
        }
    }

    private func blockUser() {
        Task {
            do {
                try await appContainer.chatStore.block(conversationID: conversation.id)
                dismiss()
            } catch { actionMessage = error.localizedDescription }
        }
    }

    private func closeDeal() {
        Task {
            do {
                try await appContainer.chatStore.closeDeal(conversationID: conversation.id)
                actionMessage = "chat.deal.closed.confirmation".localized
            } catch { actionMessage = error.localizedDescription }
        }
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let retry: () -> Void

    var body: some View {
        if message.kind == "system" {
            Text("chat.deal.closed.system".localized)
                .font(.caption.bold())
                .foregroundColor(JourneyVisual.lime)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(JourneyVisual.lime.opacity(0.08))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
        } else {
            HStack {
                if isMine { Spacer(minLength: 54) }
                VStack(alignment: isMine ? .trailing : .leading, spacing: 5) {
                    Text(message.body)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(isMine ? .black : .white)
                        .textSelection(.enabled)
                    HStack(spacing: 5) {
                        Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                        if isMine {
                            deliveryIndicator
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(isMine ? .black.opacity(0.52) : .white.opacity(0.42))
                    if message.deliveryState == .failed {
                        Button("common.retry".localized, action: retry)
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isMine ? JourneyVisual.lime : Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                if !isMine { Spacer(minLength: 54) }
            }
        }
    }

    @ViewBuilder
    private var deliveryIndicator: some View {
        switch message.deliveryState {
        case .sending:
            ProgressView().controlSize(.mini).tint(.black.opacity(0.52))
        case .sent:
            Image(systemName: "checkmark").foregroundStyle(.black.opacity(0.52))
        case .delivered:
            Image(systemName: "checkmark.checkmark").foregroundStyle(.black.opacity(0.52))
        case .read:
            Image(systemName: "checkmark.checkmark").foregroundStyle(JourneyVisual.lime)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        }
    }
}

private struct TypingBubble: View {
    @State private var activeDot = 0

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white.opacity(activeDot == index ? 0.9 : 0.3))
                        .frame(width: 7, height: 7)
                        .offset(y: activeDot == index ? -2 : 0)
                }
            }
            .padding(.horizontal, 15).frame(height: 38)
            .background(Color.white.opacity(0.09)).clipShape(Capsule())
            Spacer()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(280))
                withAnimation(.easeInOut(duration: 0.2)) { activeDot = (activeDot + 1) % 3 }
            }
        }
    }
}

private struct ChatReviewSheet: View {
    let conversationID: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    @State private var rating = 5
    @State private var comment = ""
    @State private var isSending = false
    @State private var error: String?

    var body: some View {
        ZStack {
            JourneyVisual.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("chat.review.title".localized)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { value in
                        Button { rating = value } label: {
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundColor(JourneyVisual.lime)
                        }
                    }
                }
                TextField("chat.review.placeholder".localized, text: $comment, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(14)
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                if let error { Text(error).font(.caption).foregroundColor(.red) }
                Button {
                    Task { await submit() }
                } label: {
                    if isSending { ProgressView().tint(.black) }
                    else { Text("chat.review.submit".localized).font(.headline) }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(JourneyVisual.lime)
                .clipShape(Capsule())
                .disabled(isSending)
            }
            .padding(22)
        }
    }

    private func submit() async {
        isSending = true
        defer { isSending = false }
        do {
            try await appContainer.chatStore.review(
                conversationID: conversationID,
                rating: rating,
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment
            )
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
