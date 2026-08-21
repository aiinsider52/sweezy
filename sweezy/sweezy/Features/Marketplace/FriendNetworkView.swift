import PhotosUI
import SwiftUI
import UIKit

@MainActor final class FriendNetworkViewModel: ObservableObject {
  @Published var profiles: [SocialProfile] = []
  @Published var connections: [FriendConnection] = []
  @Published var events: [SocialEvent] = []
  @Published var myProfile: SocialProfile?
  @Published var loading = false
  @Published var error: String?
  @Published var loadErrors: [Int: String] = [:]
  @Published var query = ""
  @Published var interest: SocialInterest?
  @Published var canton: String?
  @Published var language: String?
  @Published var ageBand: String?
  @Published var residency: String?
  @Published var maxDistanceKM: Int?
  @Published var nearby = false
  @Published var searchMeta: SocialProfilePage?
  @Published var visitors: [SocialProfileVisitor] = []
  @Published var isShowingDemoProfiles = false
  @Published var swipeProfiles: [SocialProfile] = []
  @Published var swipeDeckMeta: SocialSwipeDeck?
  @Published var swipeBusy = false
  @Published var swipeNeedsPlus = false
  @Published var lastPassedProfile: SocialProfile?
  var incoming: [FriendConnection] {
    connections.filter { $0.direction == "incoming" && $0.status == "pending" }
  }
  var friends: [FriendConnection] { connections.filter { $0.status == "accepted" } }
  private func friendResult<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
    do { return .success(try await operation()) }
    catch { return .failure(error) }
  }
  private func loadIssue(_ title: String, _ error: Error) -> String {
    let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    return detail.isEmpty ? title : "\(title) \(detail)"
  }
  func load() async {
    guard !loading else { return }
    loading = true
    defer { loading = false }
    async let p = friendResult { try await FriendsAPI.profiles(query: self.query, canton: self.canton, interest: self.interest) }
    async let c = friendResult { try await FriendsAPI.connections() }
    async let e = friendResult { try await FriendsAPI.events(canton: self.canton) }
    async let m = friendResult { try await self.own() }
    async let s = friendResult { try await FriendsAPI.swipeDeck(canton: self.canton, interest: self.interest) }
    let values = await (p, c, e, m, s)
    var failures: [Int: String] = [:]
    switch values.0 { case .success(let page): profiles = page.items; searchMeta = page; case .failure(let issue): failures[0] = loadIssue("Не вдалося завантажити людей.", issue) }
    switch values.1 { case .success(let value): connections = value; case .failure(let issue): failures[2] = loadIssue("Не вдалося завантажити зв’язки.", issue) }
    switch values.2 { case .success(let value): events = value; case .failure(let issue): failures[1] = loadIssue("Не вдалося завантажити події.", issue) }
    switch values.3 { case .success(let value): myProfile = value; case .failure(let issue): failures[3] = loadIssue("Не вдалося завантажити твій Social Passport.", issue) }
    switch values.4 {
    case .success(let value): swipeProfiles = value.items; swipeDeckMeta = value
    case .failure(let issue):
      if myProfile?.moderationStatus == "approved" {
        failures[0] = loadIssue("Не вдалося завантажити картки знайомств.", issue)
      }
    }
    loadErrors = failures
    #if DEBUG
    if profiles.isEmpty { applyDemoProfiles() }
    #endif
  }
  func reload() async {
    async let page = friendResult {
      try await FriendsAPI.profiles(
        query: self.query, canton: self.canton, interest: self.interest,
        language: self.language, ageBand: self.ageBand, residency: self.residency,
        maxDistanceKM: self.maxDistanceKM, nearby: self.nearby)
    }
    async let eventPage = friendResult { try await FriendsAPI.events(canton: self.canton) }
    async let deck = friendResult {
      try await FriendsAPI.swipeDeck(
        canton: self.canton, interest: self.interest, language: self.language, nearby: self.nearby)
    }
    let values = await (page, eventPage, deck)
    var failures = loadErrors
    switch values.0 { case .success(let value): profiles = value.items; searchMeta = value; failures[0] = nil; case .failure(let issue): failures[0] = loadIssue("Не вдалося оновити людей.", issue) }
    switch values.1 { case .success(let value): events = value; failures[1] = nil; case .failure(let issue): failures[1] = loadIssue("Не вдалося оновити події.", issue) }
    switch values.2 { case .success(let value): swipeProfiles = value.items; swipeDeckMeta = value; case .failure(let issue): failures[0] = loadIssue("Не вдалося оновити картки знайомств.", issue) }
    loadErrors = failures
    #if DEBUG
    if !failures.isEmpty || profiles.isEmpty { applyDemoProfiles() }
    #endif
  }
  func own() async throws -> SocialProfile? {
    do { return try await FriendsAPI.myProfile() } catch  where (error as NSError).code == 404 {
      return nil
    }
  }
  func save(_ d: SocialProfileDraft) async -> Bool {
    error = nil
    do {
      myProfile = try await FriendsAPI.save(d)
      await load()
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  func connect(_ p: SocialProfile, message: String, eventID: String? = nil) async -> Bool {
    do {
      let c = try await FriendsAPI.connect(
        p.id, message: message.isEmpty ? nil : message, eventID: eventID)
      connections.insert(c, at: 0)
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  func decide(_ c: FriendConnection, accept: Bool) async -> FriendConnection? {
    do {
      let x = try await FriendsAPI.decide(c.id, accept: accept)
      if let i = connections.firstIndex(where: { $0.id == x.id }) { connections[i] = x }
      return x
    } catch {
      self.error = error.localizedDescription
      return nil
    }
  }
  func attend(_ e: SocialEvent) async {
    do {
      _ = try await FriendsAPI.attend(e.id, status: e.myStatus == "going" ? "interested" : "going")
      await reload()
    } catch { self.error = error.localizedDescription }
  }
  func boost() async -> Bool {
    do {
      myProfile = try await FriendsAPI.boostProfile()
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  func loadVisitors() async {
    do { visitors = try await FriendsAPI.visitors() }
    catch { self.error = error.localizedDescription }
  }
  func swipe(_ profile: SocialProfile, decision: String) async -> SocialSwipeResult? {
    guard !swipeBusy else { return nil }
    swipeBusy = true
    swipeNeedsPlus = false
    let originalIndex = swipeProfiles.firstIndex(where: { $0.id == profile.id }) ?? 0
    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
      swipeProfiles.removeAll { $0.id == profile.id }
    }
    defer { swipeBusy = false }
    #if DEBUG
    if profile.id.hasPrefix("preview-") {
      if decision == "pass" { lastPassedProfile = profile }
      return SocialSwipeResult(
        targetID: profile.id, decision: decision, isMatch: false,
        connectionID: nil, conversationID: nil, likesRemaining: swipeDeckMeta?.likesRemaining)
    }
    #endif
    do {
      let result = try await FriendsAPI.swipe(profile.id, decision: decision)
      if decision == "pass" { lastPassedProfile = profile } else { lastPassedProfile = nil }
      if let remaining = result.likesRemaining, let meta = swipeDeckMeta {
        swipeDeckMeta = SocialSwipeDeck(
          items: swipeProfiles, likesRemaining: remaining, weeklyLimit: meta.weeklyLimit,
          isPremium: meta.isPremium, resetAt: meta.resetAt)
      }
      if result.isMatch {
        connections = (try? await FriendsAPI.connections()) ?? connections
      }
      await refillSwipeDeckIfNeeded()
      return result
    } catch {
      withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
        swipeProfiles.insert(profile, at: min(originalIndex, swipeProfiles.count))
      }
      swipeNeedsPlus = (error as NSError).code == 402
      self.error = error.localizedDescription
      return nil
    }
  }
  func undoLastPass() async {
    guard let profile = lastPassedProfile, !swipeBusy else { return }
    swipeBusy = true
    defer { swipeBusy = false }
    #if DEBUG
    if profile.id.hasPrefix("preview-") {
      swipeProfiles.insert(profile, at: 0)
      lastPassedProfile = nil
      return
    }
    #endif
    do {
      try await FriendsAPI.undoPass(profile.id)
      withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
        swipeProfiles.insert(profile, at: 0)
      }
      lastPassedProfile = nil
    } catch { self.error = error.localizedDescription }
  }
  private func refillSwipeDeckIfNeeded() async {
    guard swipeProfiles.count <= 4 else { return }
    guard let deck = try? await FriendsAPI.swipeDeck(
      canton: canton, interest: interest, language: language, nearby: nearby) else { return }
    let known = Set(swipeProfiles.map(\.id))
    swipeProfiles.append(contentsOf: deck.items.filter { !known.contains($0.id) })
    swipeDeckMeta = SocialSwipeDeck(
      items: swipeProfiles, likesRemaining: deck.likesRemaining, weeklyLimit: deck.weeklyLimit,
      isPremium: deck.isPremium, resetAt: deck.resetAt)
  }
  #if DEBUG
  func applyDemoProfiles() {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    profiles = SocialFriendPreviewFixtures.profiles.filter { profile in
      let matchesQuery = normalizedQuery.isEmpty || [profile.displayName, profile.city, profile.bio]
        .joined(separator: " ").lowercased().contains(normalizedQuery)
      let matchesCanton = canton == nil || profile.canton == canton
      let matchesInterest = interest.map { profile.interests.contains($0) } ?? true
      return matchesQuery && matchesCanton && matchesInterest
    }
    searchMeta = SocialProfilePage(
      items: profiles, total: profiles.count, page: 1, perPage: 40, pages: 1,
      isLimited: false, visibleLimit: nil, advancedFiltersAvailable: true,
      requestsRemaining: 5)
    swipeProfiles = profiles
    swipeDeckMeta = SocialSwipeDeck(
      items: profiles, likesRemaining: 15, weeklyLimit: 15, isPremium: false,
      resetAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()))
    isShowingDemoProfiles = true
  }
  #endif
}

private struct FriendSwipeDeck: View {
  private struct CardLayer: Identifiable {
    let index: Int
    let profile: SocialProfile
    var id: String { profile.id }
  }

  let profiles: [SocialProfile]
  let cardHeight: CGFloat
  let busy: Bool
  let canUndo: Bool
  let onDecision: (SocialProfile, String) -> Void
  let onUndo: () -> Void
  let onDetails: (SocialProfile) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dragOffset: CGSize = .zero
  @State private var committing = false

  private var topProfile: SocialProfile? { profiles.first }
  private var cardLayers: [CardLayer] {
    Array(profiles.prefix(3).enumerated())
      .map { CardLayer(index: $0.offset, profile: $0.element) }
      .reversed()
  }

  var body: some View {
    VStack(spacing: 11) {
      cardStack
      swipeCue
      actionControls
      Text("Like приватний до взаємного вибору")
        .font(.caption2.weight(.semibold))
        .foregroundColor(.white.opacity(0.42))
        .accessibilityHidden(true)
    }
  }

  private var cardStack: some View {
    ZStack {
      ForEach(cardLayers) { layer in
        swipeCard(layer)
      }
    }
    .frame(height: cardHeight + 34)
  }

  private func swipeCard(_ layer: CardLayer) -> some View {
    let isTop = layer.index == 0
    let profile = layer.profile
    return FriendSwipeCard(
      profile: profile,
      dragProgress: isTop ? min(1, abs(dragOffset.width) / 120) : 0,
      direction: isTop ? dragOffset.width : 0)
      .frame(maxWidth: .infinity)
      .frame(height: cardHeight)
      .scaleEffect(isTop ? 0.97 : 0.97 - CGFloat(layer.index) * 0.025)
      .offset(
        x: isTop ? dragOffset.width : -CGFloat(layer.index) * 12,
        y: isTop ? 10 + dragOffset.height * 0.12 : 10 + CGFloat(layer.index) * 13)
      .rotationEffect(
        .degrees(
          isTop
            ? 1.6 + Double(dragOffset.width / 34)
            : layer.index == 1 ? -2.2 : -4.2))
      .zIndex(Double(3 - layer.index))
      .shadow(color: .black.opacity(isTop ? 0.5 : 0.26), radius: 25, y: 15)
      .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
      .onTapGesture { if isTop && !committing { onDetails(profile) } }
      .gesture(swipeGesture, including: isTop ? .all : .none)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isButton)
      .accessibilityIdentifier("friends.profile.\(profile.id)")
      .accessibilityLabel(accessibilityLabel(profile))
      .accessibilityHint("Свайп праворуч — Like, ліворуч — пропустити")
      .accessibilityAction(named: "Like") { commit(profile, decision: "like") }
      .accessibilityAction(named: "Пропустити") { commit(profile, decision: "pass") }
      .accessibilityAction(named: "Відкрити профіль") { onDetails(profile) }
  }

  private var swipeCue: some View {
    HStack(spacing: 16) {
      Text("PASS").foregroundColor(.white.opacity(0.42))
      Image(systemName: "arrow.left")
      Text("СВАЙП").foregroundColor(JourneyVisual.lime)
      Image(systemName: "arrow.right")
      Text("LIKE").foregroundColor(JourneyVisual.lime)
    }
    .font(.caption.bold())
    .tracking(1.4)
    .accessibilityHidden(true)
  }

  private var actionControls: some View {
    GeometryReader { proxy in
      let scale = min(1, max(0.78, (proxy.size.width - 26) / 302))
      HStack(alignment: .top, spacing: 13 * scale) {
        swipeActionButton(
          label: "PASS", icon: "xmark", size: 106 * scale, primary: false,
          enabled: topProfile != nil && !busy, identifier: "friends.swipe.pass"
        ) {
          if let topProfile { commit(topProfile, decision: "pass") }
        }
        VStack(spacing: 10 * scale) {
          actionButton(
            icon: "info", size: 48 * scale, enabled: topProfile != nil && !busy,
            identifier: "friends.swipe.details"
          ) {
            if let topProfile { onDetails(topProfile) }
          }
          if canUndo {
            actionButton(
              icon: "arrow.uturn.backward", size: 40 * scale, enabled: !busy,
              identifier: "friends.swipe.undo", action: onUndo)
              .transition(.scale.combined(with: .opacity))
          }
        }
        .padding(.top, 35 * scale)
        swipeActionButton(
          label: "LIKE", icon: "heart.fill", size: 122 * scale, primary: true,
          enabled: topProfile != nil && !busy, identifier: "friends.swipe.like"
        ) {
          if let topProfile { commit(topProfile, decision: "like") }
        }
      }
      .frame(maxWidth: .infinity)
    }
    .frame(height: 154)
  }

  private func swipeActionButton(
    label: String, icon: String, size: CGFloat, primary: Bool, enabled: Bool,
    identifier: String,
    action: @escaping () -> Void
  ) -> some View {
    VStack(spacing: 8) {
      Text(label)
        .font(.caption.bold()).tracking(2)
        .foregroundColor(primary ? JourneyVisual.lime : .white.opacity(0.48))
      actionButton(
        icon: icon, size: size, primary: primary, enabled: enabled, identifier: identifier,
        action: action)
    }
  }

  private var swipeGesture: some Gesture {
    DragGesture(minimumDistance: 10, coordinateSpace: .local)
      .onChanged { value in
        guard !busy, !committing else { return }
        guard abs(value.translation.width) > abs(value.translation.height) * 0.72 else { return }
        dragOffset = CGSize(width: value.translation.width, height: value.translation.height)
      }
      .onEnded { value in
        guard let topProfile, !busy, !committing else { resetDrag(); return }
        let projected = value.predictedEndTranslation.width
        let effective = abs(projected) > abs(value.translation.width) ? projected : value.translation.width
        if abs(effective) >= 105 {
          commit(topProfile, decision: effective > 0 ? "like" : "pass")
        } else {
          resetDrag()
        }
      }
  }

  private func commit(_ profile: SocialProfile, decision: String) {
    guard !busy, !committing, profile.id == topProfile?.id else { return }
    committing = true
    UIImpactFeedbackGenerator(style: decision == "like" ? .medium : .light).impactOccurred()
    let destination: CGFloat = decision == "like" ? 620 : -620
    withAnimation(reduceMotion ? nil : .easeIn(duration: 0.18)) {
      dragOffset = CGSize(width: destination, height: 18)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.16)) {
      onDecision(profile, decision)
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) { dragOffset = .zero }
      committing = false
    }
  }

  private func resetDrag() {
    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.76)) {
      dragOffset = .zero
    }
  }

  private func actionButton(
    icon: String, size: CGFloat, primary: Bool = false, enabled: Bool,
    identifier: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: size * 0.31, weight: .bold))
        .foregroundColor(primary ? .black : .white.opacity(enabled ? 0.9 : 0.28))
        .frame(width: size, height: size)
        .background(primary ? JourneyVisual.lime : Color.white.opacity(0.08))
        .clipShape(Circle())
        .overlay(Circle().stroke(primary ? JourneyVisual.lime : Color.white.opacity(0.14)))
        .shadow(color: primary ? JourneyVisual.lime.opacity(0.24) : .clear, radius: 16)
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.45)
    .accessibilityIdentifier(identifier ?? "")
  }

  private func accessibilityLabel(_ profile: SocialProfile) -> String {
    let distance = profile.distanceKM.map { ", \($0) кілометрів" } ?? ""
    return "\(profile.displayName), \(profile.city), \(profile.canton), \(profile.matchScore) відсотків збігу\(distance). \(profile.bio)"
  }
}

private struct FriendSwipeCard: View {
  let profile: SocialProfile
  let dragProgress: CGFloat
  let direction: CGFloat

  private let lime = JourneyVisual.lime

  var body: some View {
    ZStack {
      profileImage
      LinearGradient(
        colors: [.black.opacity(0.04), .clear, .black.opacity(0.15), .black.opacity(0.98)],
        startPoint: .top, endPoint: .bottom)
      VStack(alignment: .leading, spacing: 0) {
        locationBadge
        Spacer()
        if profile.residencyStage == "newcomer" {
          Label("НОВИЙ У ШВЕЙЦАРІЇ", systemImage: "sparkles")
            .font(.system(size: 10, weight: .black)).tracking(1.1)
            .foregroundColor(.black).padding(.horizontal, 10).padding(.vertical, 7)
            .background(lime).clipShape(Capsule())
            .padding(.bottom, 10)
        }
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(profile.displayName)
            .font(.system(size: 33, weight: .black, design: .rounded))
            .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.72)
          if profile.isVerified {
            Image(systemName: "checkmark.seal.fill").foregroundColor(lime)
          }
        }
        if let ageBand = profile.ageBand, !ageBand.isEmpty {
          Text(ageBand.replacingOccurrences(of: "-", with: "–"))
            .font(.title3.bold()).foregroundColor(.white)
            .padding(.top, 2)
        }
        Text(profile.bio)
          .font(.subheadline.weight(.medium)).foregroundColor(.white.opacity(0.76))
          .lineLimit(2).fixedSize(horizontal: false, vertical: true)
          .padding(.top, 5)
        HStack(spacing: 7) {
          ForEach(Array(profile.sharedInterests.prefix(3))) { interest in
            Label(interest.title, systemImage: interest.icon)
              .font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.92))
              .lineLimit(1).minimumScaleFactor(0.72)
              .padding(.horizontal, 9).padding(.vertical, 8)
              .background(Color.black.opacity(0.48)).clipShape(Capsule())
              .overlay(Capsule().stroke(Color.white.opacity(0.24)))
          }
        }
        .padding(.top, 12)
      }
      .padding(18)

      VStack {
        HStack(alignment: .top) {
          Spacer()
          verticalMatchScore.padding(.top, 72).padding(.trailing, 16)
        }
        Spacer()
      }

      if dragProgress > 0.08 {
        swipeStamp
          .opacity(Double(dragProgress))
          .scaleEffect(0.86 + dragProgress * 0.14)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 30).stroke(lime, lineWidth: 1.5))
  }

  @ViewBuilder private var profileImage: some View {
    if let previewImageName {
      Image(previewImageName).resizable().scaledToFill()
    } else if let raw = profile.avatarURL, let url = APIClient.resolveMediaURL(raw) {
      CachedAsyncImage(url: url) { fallback }
    } else {
      fallback
    }
  }

  private var previewImageName: String? {
    switch profile.id {
    case "preview-anna": return "friend-preview-anna"
    case "preview-dmytro": return "friend-preview-dmytro"
    case "preview-sofia": return "friend-preview-sofia"
    default: return nil
    }
  }

  private var fallback: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.04, green: 0.15, blue: 0.11), Color(red: 0.01, green: 0.025, blue: 0.022)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
      Circle().stroke(lime.opacity(0.12), lineWidth: 1).frame(width: 330, height: 330).offset(x: 110, y: -160)
      Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).frame(width: 210, height: 210).offset(x: 90, y: -150)
      Text(profile.initials)
        .font(.system(size: 102, weight: .black, design: .rounded))
        .foregroundStyle(LinearGradient(colors: [lime, Color.white.opacity(0.7)], startPoint: .top, endPoint: .bottom))
        .offset(y: -55)
    }
  }

  private var locationBadge: some View {
    HStack(spacing: 6) {
      Image(systemName: "mappin.and.ellipse")
      Text("\(profile.city) · \(profile.canton)")
      if let distance = profile.distanceKM { Text("· \(distance) км") }
    }
    .font(.caption.bold()).foregroundColor(.white)
    .padding(.horizontal, 11).padding(.vertical, 8)
    .background(.black.opacity(0.42)).clipShape(Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.16)))
  }

  private var verticalMatchScore: some View {
    VStack(spacing: -3) {
      Text("\(profile.matchScore)")
        .font(.system(size: 58, weight: .black, design: .rounded))
        .minimumScaleFactor(0.7)
      Text("M\nA\nT\nC\nH")
        .font(.system(size: 13, weight: .black, design: .rounded))
        .tracking(1.2)
        .multilineTextAlignment(.center)
        .lineSpacing(-1)
    }
    .foregroundColor(lime)
    .shadow(color: .black.opacity(0.45), radius: 8)
  }

  private var swipeStamp: some View {
    VStack {
      HStack {
        if direction > 0 { Spacer() }
        Text(direction > 0 ? "ЦІКАВО" : "ДАЛІ")
          .font(.system(size: 25, weight: .black, design: .rounded)).tracking(1.1)
          .foregroundColor(direction > 0 ? .black : .white)
          .padding(.horizontal, 18).padding(.vertical, 10)
          .background(direction > 0 ? lime : Color.black.opacity(0.72))
          .clipShape(RoundedRectangle(cornerRadius: 13))
          .overlay(RoundedRectangle(cornerRadius: 13).stroke(direction > 0 ? lime : .white, lineWidth: 2))
        if direction <= 0 { Spacer() }
      }
      Spacer()
    }
    .padding(24)
  }
}

private struct FriendMatchCelebration: View {
  let profile: SocialProfile
  let canOpenChat: Bool
  let close: () -> Void
  let openChat: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false

  var body: some View {
    ZStack {
      JourneyVisual.black.ignoresSafeArea()
      RadialGradient(
        colors: [JourneyVisual.lime.opacity(0.19), .clear], center: .top, startRadius: 20, endRadius: 420)
        .ignoresSafeArea()
      VStack(spacing: 24) {
        Spacer()
        ZStack {
          Circle().stroke(JourneyVisual.lime.opacity(0.18), lineWidth: 1).frame(width: 270, height: 270)
          Circle().stroke(JourneyVisual.lime.opacity(0.34), lineWidth: 1).frame(width: 220, height: 220)
          FriendMatchAvatar(profile: profile)
            .frame(width: 174, height: 174)
            .clipShape(Circle())
            .overlay(Circle().stroke(JourneyVisual.lime, lineWidth: 3))
          Image(systemName: "heart.fill")
            .font(.title2).foregroundColor(.black).frame(width: 54, height: 54)
            .background(JourneyVisual.lime).clipShape(Circle()).offset(x: 76, y: 70)
        }
        .scaleEffect(appeared ? 1 : 0.72)
        .opacity(appeared ? 1 : 0)
        VStack(spacing: 10) {
          Text("ВЗАЄМНИЙ ВИБІР").font(.caption.bold()).tracking(2.2).foregroundColor(JourneyVisual.lime)
          Text("Ви знайшли\nодне одного")
            .font(.system(size: 39, weight: .black, design: .rounded)).foregroundColor(.white)
            .multilineTextAlignment(.center).lineSpacing(-3)
          Text("Ти та \(profile.displayName) обрали Like. Контакти залишаються приватними — почніть з чату Sweezy.")
            .font(.subheadline).foregroundColor(.white.opacity(0.62)).multilineTextAlignment(.center)
            .padding(.horizontal, 26)
        }
        Spacer()
        if canOpenChat {
          Button(action: openChat) {
            HStack {
              Image(systemName: "message.fill")
              Text("Написати \(profile.displayName.split(separator: " ").first.map(String.init) ?? "")")
              Spacer()
              Image(systemName: "arrow.right")
            }
            .font(.headline).foregroundColor(.black).padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 58).background(JourneyVisual.lime)
            .clipShape(RoundedRectangle(cornerRadius: 19))
          }
        }
        Button("Продовжити знайомства", action: close)
          .font(.subheadline.bold()).foregroundColor(.white.opacity(0.72)).frame(minHeight: 48)
      }
      .padding(.horizontal, 22).padding(.bottom, 22)
    }
    .onAppear {
      withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.68)) { appeared = true }
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
  }
}

private struct FriendMatchAvatar: View {
  let profile: SocialProfile
  var body: some View {
    Group {
      if let raw = profile.avatarURL, let url = APIClient.resolveMediaURL(raw) {
        CachedAsyncImage(url: url) { fallback }
      } else { fallback }
    }
  }
  private var fallback: some View {
    ZStack {
      LinearGradient(colors: [JourneyVisual.lime, Color(red: 0.14, green: 0.64, blue: 0.48)], startPoint: .topLeading, endPoint: .bottomTrailing)
      Text(profile.initials).font(.system(size: 48, weight: .black, design: .rounded)).foregroundColor(.black)
    }
  }
}

private struct SocialMatchPresentation: Identifiable {
  let profile: SocialProfile
  let conversationID: String?
  var id: String { profile.id }
}

struct FriendNetworkView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var appContainer: AppContainer
  @EnvironmentObject private var lockManager: AppLockManager
  @EnvironmentObject private var sessionManager: SessionManager
  let showsDismissButton: Bool
  @StateObject private var vm = FriendNetworkViewModel()
  @State private var tab = 0
  @State private var editor = false
  @State private var selected: SocialProfile?
  @State private var event: SocialEvent?
  @State private var conversation: ChatConversation?
  @State private var filters = false
  @State private var paywall = false
  @State private var eventChat: SocialEvent?
  @State private var showVisitors = false
  @State private var showAuth = false
  @State private var showsDemoCatalog = false
  @State private var showPeopleCatalog = false
  @State private var activeMatch: SocialMatchPresentation?
  @AppStorage("friends.invisibleBrowsing") private var invisibleBrowsing = false
  @StateObject private var subscription = SubscriptionManager.shared
  private let limeAccent = JourneyVisual.lime
  private let forest = Color(red: 0.035, green: 0.105, blue: 0.075)
  private let mintGlow = Color(red: 0.63, green: 0.93, blue: 0.62)

  init(showsDismissButton: Bool = true) {
    self.showsDismissButton = showsDismissButton
  }

  var body: some View {
    Group {
      if sessionManager.isAuthenticated || isUITestPreview || showsDemoCatalog {
        friendsContent
      } else {
        accessGate
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $showAuth) {
      AuthEntryView(showsCloseButton: true) { showAuth = false }
        .environmentObject(appContainer)
        .environmentObject(lockManager)
        .environmentObject(sessionManager)
    }
    .onChange(of: sessionManager.isAuthenticated) { _, authenticated in
      if authenticated {
        showAuth = false
        showsDemoCatalog = false
        Task { await vm.load() }
      }
    }
  }
  private var friendsContent: some View {
    GeometryReader { geometry in
      ZStack(alignment: .top) {
        JourneyVisual.black.ignoresSafeArea()
        if tab != 0 {
          Image("journey-place-community")
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: 410)
            .clipped()
            .overlay(
              LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.35), JourneyVisual.black],
                startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea(edges: .top)
            .accessibilityHidden(true)
        }
        ScrollView(showsIndicators: false) {
          LazyVStack(spacing: 0) {
            if tab == 0 {
              peopleTopBar
            } else {
              hero
            }
            tabs
            if tab == 0 { peopleMetrics }
            if let loadError = vm.loadErrors[tab] {
              networkIssue(message: loadError)
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
            if let actionError = vm.error {
              actionIssue(message: actionError)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            Group {
              switch tab {
              case 1: events
              case 2: connections
              case 3: profile
              default: discover(screenHeight: geometry.size.height)
              }
            }.padding(.top, 18)
          }
          .frame(width: geometry.size.width)
          .padding(.bottom, 44)
        }
        .frame(width: geometry.size.width)
        .refreshable { await vm.load() }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .task {
      if isProfileUITestPreview { tab = 3 }
      if isEditorUITestPreview {
        tab = 3
        editor = true
      }
      if isPeopleCatalogPreview || showsDemoCatalog {
        loadPeopleCatalogPreview()
      } else if !isUITestPreview && sessionManager.isAuthenticated {
        await vm.load()
      }
    }
    .accessibilityIdentifier("friends.screen")
    .fullScreenCover(item: $selected) {
      FriendProfileDetail(profile: $0, vm: vm, conversation: $conversation).environmentObject(
        appContainer)
    }
    .fullScreenCover(item: $conversation) {
      ChatConversationView(conversation: $0).environmentObject(appContainer)
    }
    .fullScreenCover(isPresented: $editor) { FriendProfileEditor(profile: vm.myProfile, vm: vm) }
    .sheet(isPresented: $filters) { FriendSearchFilters(vm: vm, showPaywall: $paywall) }
    .fullScreenCover(isPresented: $paywall) { SubscriptionView(source: .profile) }
    .sheet(item: $eventChat) { SocialEventChatView(event: $0, friends: vm.friends, vm: vm) }
    .sheet(item: $event) { EventDetailView(eventId: $0.id) }
    .sheet(isPresented: $showVisitors) { FriendVisitorsView(visitors: vm.visitors) }
    .fullScreenCover(item: $activeMatch) { match in
      FriendMatchCelebration(profile: match.profile, canOpenChat: match.conversationID != nil) {
        activeMatch = nil
      } openChat: {
        guard let id = match.conversationID else { activeMatch = nil; return }
        Task {
          conversation = try? await ChatAPI.conversation(id: id)
          activeMatch = nil
        }
      }
    }
  }
  private var accessGate: some View {
    GeometryReader { geometry in
      ZStack {
        Image("journey-place-community")
          .resizable()
          .scaledToFill()
          .frame(width: geometry.size.width, height: geometry.size.height)
          .clipped()
          .ignoresSafeArea()
          .accessibilityHidden(true)
        Color.black.opacity(0.68).ignoresSafeArea()
        VStack(alignment: .leading, spacing: 16) {
          if showsDismissButton {
            Button { dismiss() } label: {
              Image(systemName: "xmark")
                .font(.title2.bold()).foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.34)).clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18)))
            }
          }
          Spacer(minLength: 24)
          Text("SWEEZY CIRCLE · CH")
            .font(.caption.bold()).tracking(2).foregroundColor(limeAccent)
          Text("Знайди своїх\nу Швейцарії")
            .font(.system(size: min(38, max(31, geometry.size.width * 0.095)), weight: .black, design: .rounded))
            .foregroundColor(.white).lineSpacing(-3)
          Text("Увійди, щоб створити social passport, надсилати заявки та спілкуватися без публікації контактів.")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.72))
            .fixedSize(horizontal: false, vertical: true)
          Button { showAuth = true } label: {
            Text("Увійти та продовжити")
              .font(.headline).foregroundColor(.black)
              .frame(maxWidth: .infinity, minHeight: 56)
              .background(limeAccent).clipShape(RoundedRectangle(cornerRadius: 18))
          }
          .accessibilityIdentifier("friends.accessGate.signIn")
          #if DEBUG
          Button {
            showsDemoCatalog = true
            loadPeopleCatalogPreview()
          } label: {
            Text("Переглянути демо-профілі")
              .font(.subheadline.bold()).foregroundColor(.white)
              .frame(maxWidth: .infinity, minHeight: 50)
              .background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 17))
              .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.16)))
          }
          .accessibilityIdentifier("friends.accessGate.demo")
          #endif
        }
        .frame(
          width: max(0, geometry.size.width - 40),
          height: max(0, geometry.size.height - 24),
          alignment: .leading)
        .padding(.horizontal, 20).padding(.vertical, 12)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
  }
  private func networkIssue(message: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "wifi.exclamationmark").foregroundColor(limeAccent)
      Text(message).font(.footnote.weight(.medium)).foregroundColor(.white.opacity(0.75))
      Spacer(minLength: 8)
      Button("common.retry".localized) { Task { await vm.load() } }
        .font(.footnote.bold()).foregroundColor(.black)
        .padding(.horizontal, 12).frame(height: 34).background(limeAccent).clipShape(Capsule())
    }
    .padding(12).background(Color.white.opacity(0.07))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
  private func actionIssue(message: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundColor(limeAccent)
      Text(message).font(.footnote.weight(.medium)).foregroundColor(.white.opacity(0.75))
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 8)
      Button { vm.error = nil } label: {
        Image(systemName: "xmark").font(.footnote.bold()).foregroundColor(.white.opacity(0.7))
          .frame(width: 32, height: 32).background(Color.white.opacity(0.08)).clipShape(Circle())
      }
      .accessibilityLabel("Закрити повідомлення")
    }
    .padding(12).background(Color.white.opacity(0.07))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
  private var hero: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        if showsDismissButton {
          Button {
            dismiss()
          } label: {
            Image(systemName: "chevron.left").font(.title2.bold()).foregroundColor(.white).frame(
              width: 52, height: 52
            ).background(.black.opacity(0.38)).clipShape(Circle()).overlay(
              Circle().stroke(.white.opacity(0.2)))
          }
        }
        Spacer()
        if !vm.incoming.isEmpty {
          Text("\(vm.incoming.count) нових").font(.caption.bold()).foregroundColor(.black).padding(
            .horizontal, 14
          ).frame(height: 40).background(limeAccent).clipShape(Capsule())
        }
      }
      Spacer()
      Text("SWEEZY CIRCLE · CH").font(.caption.bold()).tracking(2.5).foregroundColor(limeAccent)
      Text("Знайди своїх\nу Швейцарії").font(.system(size: 42, weight: .black, design: .rounded))
        .lineSpacing(-4).foregroundColor(.white)
        .minimumScaleFactor(0.78)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("friends.heroTitle")
      Text("Спільні інтереси, події та живі зустрічі — без випадкових знайомств.").font(
        .subheadline.weight(.medium)
      ).foregroundColor(.white.opacity(0.72)).frame(maxWidth: 340, alignment: .leading)
    }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 18).frame(height: 350)
  }
  private var peopleTopBar: some View {
    HStack(spacing: 12) {
      if showsDismissButton {
        Button { dismiss() } label: {
          Image(systemName: "chevron.left")
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .frame(width: 38, height: 38)
            .background(.white.opacity(0.07))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.13)))
        }
        .accessibilityLabel("Назад")
      }
      Text("SWEEZY CIRCLE")
        .font(.system(size: 15, weight: .black))
        .tracking(3.2)
        .foregroundColor(limeAccent)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityIdentifier("friends.people.title")
      Spacer(minLength: 8)
      Button { filters = true } label: {
        Image(systemName: "slider.horizontal.3")
          .font(.headline)
          .foregroundColor(.white)
          .frame(width: 48, height: 48)
          .background(Color.white.opacity(0.055))
          .clipShape(Circle())
          .overlay(Circle().stroke(limeAccent.opacity(0.58), lineWidth: 1))
      }
      .accessibilityLabel("Фільтри знайомств")
      .accessibilityIdentifier("friends.people.filters")
    }
    .padding(.horizontal, 18)
    .padding(.top, 10)
    .padding(.bottom, 10)
  }
  private var isUITestPreview: Bool {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains("--preview-friends-people")
        || (ProcessInfo.processInfo.environment["UITESTS"] == "1"
        && (ProcessInfo.processInfo.arguments.contains("--ui-test-friends")
          || ProcessInfo.processInfo.arguments.contains("--ui-test-friends-profile"))
        )
    #else
      false
    #endif
  }
  private var isPeopleCatalogPreview: Bool {
    #if DEBUG
      ProcessInfo.processInfo.arguments.contains("--preview-friends-people")
        || (ProcessInfo.processInfo.environment["UITESTS"] == "1"
        && ProcessInfo.processInfo.arguments.contains("--ui-test-friends"))
    #else
      false
    #endif
  }
  private func loadPeopleCatalogPreview() {
    #if DEBUG
      vm.applyDemoProfiles()
    #endif
  }
  private var isProfileUITestPreview: Bool {
    #if DEBUG
      ProcessInfo.processInfo.environment["UITESTS"] == "1"
        && ProcessInfo.processInfo.arguments.contains("--ui-test-friends-profile")
    #else
      false
    #endif
  }
  private var isEditorUITestPreview: Bool {
    #if DEBUG
      ProcessInfo.processInfo.environment["UITESTS"] == "1"
        && ProcessInfo.processInfo.arguments.contains("--ui-test-friends-editor")
    #else
      false
    #endif
  }
  private var tabs: some View {
    HStack(spacing: 0) {
      ForEach(
        Array(
          [
            ("Люди", "sparkles"), ("Події", "calendar"), ("Друзі", "person.2.fill"),
            ("Я", "person.crop.circle"),
          ].enumerated()), id: \.offset
      ) { i, x in
        Button {
          withAnimation(.easeInOut(duration: 0.2)) { tab = i }
        } label: {
          VStack(spacing: 10) {
            Text(x.0)
              .font(.system(size: 16, weight: tab == i ? .bold : .semibold))
            Capsule()
              .fill(tab == i ? limeAccent : Color.clear)
              .frame(width: 44, height: 3)
          }
          .foregroundColor(tab == i ? .white : .white.opacity(0.53))
          .frame(maxWidth: .infinity)
          .frame(height: 54)
        }
      }
    }
    .padding(.horizontal, 18)
    .overlay(alignment: .bottom) {
      Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
    }
  }
  private var peopleMetrics: some View {
    HStack(spacing: 10) {
      peopleMetric(
        icon: "mappin.and.ellipse",
        text: "\(max(vm.swipeProfiles.count, vm.profiles.count)) збігів поруч")
        .accessibilityIdentifier("friends.people.nearbyCount")
      Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: 24)
      peopleMetric(icon: "sparkles", text: peopleLikesText)
    }
    .padding(.horizontal, 18)
    .padding(.top, 18)
  }
  private func peopleMetric(icon: String, text: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon).foregroundColor(limeAccent)
      Text(text).lineLimit(1).minimumScaleFactor(0.72)
    }
    .font(.caption.weight(.semibold))
    .foregroundColor(.white.opacity(0.82))
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, minHeight: 42)
    .background(Color(red: 0.025, green: 0.075, blue: 0.06))
    .clipShape(Capsule())
  }
  private var peopleLikesText: String {
    if vm.swipeDeckMeta?.isPremium == true { return "Like без ліміту" }
    if let remaining = vm.swipeDeckMeta?.likesRemaining { return "\(remaining) Like доступно" }
    return "Приватні Like"
  }
  private func discover(screenHeight: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 15) {
      if vm.loading && vm.swipeProfiles.isEmpty {
        ProgressView().tint(limeAccent).frame(maxWidth: .infinity).padding(60)
      } else if let own = vm.myProfile, own.moderationStatus != "approved", !vm.isShowingDemoProfiles {
        swipeProfileGate(
          title: "Профіль на перевірці",
          text: "Після схвалення social passport тут з’являться персональні знайомства.",
          icon: "checkmark.shield")
      } else if vm.myProfile == nil && !vm.isShowingDemoProfiles {
        swipeProfileGate(
          title: "Створи social passport",
          text: "Інтереси, мови й кантон потрібні, щоб Sweezy знайшов сильні збіги.",
          icon: "person.crop.circle.badge.plus")
      } else if vm.swipeProfiles.isEmpty {
        empty("Нові профілі скоро", "Ти переглянув доступні збіги. Зміни фільтри або повернися завтра.")
      } else {
        FriendSwipeDeck(
          profiles: vm.swipeProfiles,
          cardHeight: min(570, max(420, screenHeight * 0.59)),
          busy: vm.swipeBusy,
          canUndo: vm.lastPassedProfile != nil,
          onDecision: handleSwipe,
          onUndo: { Task { await vm.undoLastPass() } },
          onDetails: openProfile)
      }
      Button {
        withAnimation(.easeInOut(duration: 0.24)) { showPeopleCatalog.toggle() }
      } label: {
        HStack {
          Label(showPeopleCatalog ? "Сховати каталог" : "Пошук і каталог", systemImage: "rectangle.grid.1x2")
          Spacer()
          Image(systemName: showPeopleCatalog ? "chevron.up" : "chevron.down")
        }
        .font(.subheadline.bold()).foregroundColor(.white)
        .padding(.horizontal, 16).frame(height: 52)
        .background(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.1)))
      }
      if showPeopleCatalog {
        search
        title("Усі профілі", sub: "Пошук за ім’ям, містом та інтересом", count: vm.profiles.count)
        LazyVStack(spacing: 13) {
          ForEach(vm.profiles) { profile in
            Button { openProfile(profile) } label: {
              FriendCard(profile: profile, accent: limeAccent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("friends.profile.\(profile.id)")
          }
        }
      }
    }.padding(.horizontal, 18)
  }
  private var swipeHeader: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        Text("ТВОЇ ЗБІГИ").font(.caption2.bold()).tracking(1.9).foregroundColor(limeAccent)
        Text("Люди, з якими є спільне").font(.title2.bold()).foregroundColor(.white)
        Text("Like приватний. Чат відкриється тільки після взаємного вибору.")
          .font(.caption).foregroundColor(.white.opacity(0.52))
      }
      Spacer(minLength: 6)
      Button { filters = true } label: {
        Image(systemName: "slider.horizontal.3")
          .font(.headline).foregroundColor(limeAccent)
          .frame(width: 48, height: 48).background(.white.opacity(0.08)).clipShape(Circle())
          .overlay(Circle().stroke(.white.opacity(0.12)))
      }
      .accessibilityLabel("Фільтри знайомств")
    }
  }
  private var swipeGuidance: some View {
    HStack(spacing: 10) {
      Image(systemName: vm.swipeDeckMeta?.isPremium == true ? "infinity" : "bolt.heart.fill")
        .foregroundColor(limeAccent)
      Text(swipeAllowanceText).font(.caption.bold()).foregroundColor(.white.opacity(0.7))
      Spacer()
      Text("← PASS   LIKE →").font(.caption2.bold()).tracking(0.8).foregroundColor(.white.opacity(0.38))
    }
  }
  private var swipeAllowanceText: String {
    if vm.swipeDeckMeta?.isPremium == true { return "Plus · безлімітні Like" }
    if let remaining = vm.swipeDeckMeta?.likesRemaining { return "Ще \(remaining) Like цього тижня" }
    return "Взаємні знайомства без відкритих контактів"
  }
  private func swipeProfileGate(title: String, text: String, icon: String) -> some View {
    VStack(spacing: 14) {
      Image(systemName: icon).font(.system(size: 34, weight: .semibold)).foregroundColor(limeAccent)
      Text(title).font(.title3.bold()).foregroundColor(.white)
      Text(text).font(.subheadline).foregroundColor(.white.opacity(0.58)).multilineTextAlignment(.center)
      Button { editor = true } label: {
        Text(vm.myProfile == nil ? "Створити профіль" : "Переглянути профіль")
          .font(.headline).foregroundColor(.black).frame(maxWidth: .infinity, minHeight: 52)
          .background(limeAccent).clipShape(RoundedRectangle(cornerRadius: 17))
      }
    }
    .padding(24).frame(maxWidth: .infinity)
    .background(.white.opacity(0.065)).clipShape(RoundedRectangle(cornerRadius: 26))
    .overlay(RoundedRectangle(cornerRadius: 26).stroke(limeAccent.opacity(0.24)))
  }
  private func openProfile(_ profile: SocialProfile) {
    if !profile.id.hasPrefix("preview-") {
      Task { try? await FriendsAPI.recordVisit(profile.id, invisible: subscription.isPremium && invisibleBrowsing) }
    }
    selected = profile
  }
  private func handleSwipe(_ profile: SocialProfile, _ decision: String) {
    Task {
      let result = await vm.swipe(profile, decision: decision)
      if vm.swipeNeedsPlus { paywall = true; return }
      if result?.isMatch == true {
        activeMatch = SocialMatchPresentation(profile: profile, conversationID: result?.conversationID)
      }
    }
  }
  private var demoNotice: some View {
    HStack(spacing: 10) {
      Image(systemName: "sparkles")
      VStack(alignment: .leading, spacing: 2) {
        Text("Демо-каталог").font(.subheadline.bold())
        Text("Тестові профілі для перегляду дизайну").font(.caption)
      }
      Spacer()
    }
    .foregroundColor(limeAccent)
    .padding(13)
    .background(limeAccent.opacity(0.09))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(limeAccent.opacity(0.22)))
  }
  private var orbit: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 28).fill(
        LinearGradient(
          colors: [forest, Color(red: 0.015, green: 0.025, blue: 0.022)],
          startPoint: .topLeading, endPoint: .bottomTrailing))
      HStack {
        VStack(alignment: .leading, spacing: 6) {
          Text("SWISS CIRCLE").font(.caption2.bold()).tracking(1.7).foregroundColor(limeAccent)
          Text("\(vm.profiles.count) збігів поруч").font(.title3.bold()).foregroundColor(.white)
          Text("Люди, з якими вже є про що поговорити").font(.caption).foregroundColor(
            .white.opacity(0.55))
        }
        Spacer()
        ZStack {
          Circle().stroke(limeAccent.opacity(0.22), lineWidth: 1).frame(width: 92, height: 92)
          Circle().stroke(mintGlow.opacity(0.28), lineWidth: 1).frame(width: 58, height: 58)
          Circle().fill(limeAccent).frame(width: 15, height: 15).offset(x: 34, y: -24)
          Circle().fill(mintGlow).frame(width: 11, height: 11).offset(x: -22, y: 18)
          Text("CH").font(.caption.bold()).foregroundColor(.white.opacity(0.82))
        }
      }.padding(20)
    }.frame(height: 145).overlay(
      RoundedRectangle(cornerRadius: 28).stroke(limeAccent.opacity(0.28)))
  }
  private var search: some View {
    VStack(spacing: 10) {
      HStack {
        Image(systemName: "magnifyingglass").foregroundColor(limeAccent)
        TextField("Ім’я, місто або інтерес", text: $vm.query).foregroundColor(.white).submitLabel(
          .search
        ).onSubmit { Task { await vm.reload() } }
      }.padding(.horizontal, 16).frame(height: 56).background(.white.opacity(0.07)).clipShape(
        RoundedRectangle(cornerRadius: 18)
      ).overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1)))
      HStack {
        Button {
          filters = true
        } label: {
          Label("Фільтри", systemImage: "slider.horizontal.3").font(.subheadline.bold())
        }
        Spacer()
        if let remaining = vm.searchMeta?.requestsRemaining {
          Text("\(remaining) запитів цього тижня").font(.caption).foregroundColor(
            .white.opacity(0.5))
        } else if vm.searchMeta?.advancedFiltersAvailable == true {
          Label("PLUS", systemImage: "star.fill").font(.caption.bold()).foregroundColor(limeAccent)
        }
      }.foregroundColor(.white)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          chip("Усі", active: vm.interest == nil) { vm.interest = nil }
          ForEach(SocialInterest.allCases) { i in
            chip(i.title, icon: i.icon, active: vm.interest == i) {
              vm.interest = vm.interest == i ? nil : i
            }
          }
        }
      }.onChange(of: vm.interest) { _, _ in Task { await vm.reload() } }
      if vm.searchMeta?.isLimited == true {
        Button {
          paywall = true
        } label: {
          HStack {
            Label("Показати всі збіги", systemImage: "star.fill")
            Spacer()
            Image(systemName: "arrow.right")
          }
          .font(.subheadline.bold()).foregroundColor(.black).padding(.horizontal, 16).frame(
            height: 48
          )
          .background(limeAccent).clipShape(RoundedRectangle(cornerRadius: 16))
        }
      }
      HStack(spacing: 10) {
        Button {
          guard subscription.isPremium else { paywall = true; return }
          vm.interest = .travel; vm.nearby = true
          Task { await vm.reload() }
        } label: {
          Label("Travel buddy", systemImage: "airplane").frame(maxWidth: .infinity, minHeight: 44)
        }
        Button {
          guard subscription.isPremium else { paywall = true; return }
          vm.interest = .sports; vm.nearby = true
          Task { await vm.reload() }
        } label: {
          Label("Activity buddy", systemImage: "figure.run").frame(maxWidth: .infinity, minHeight: 44)
        }
      }.font(.caption.bold()).foregroundColor(limeAccent).background(limeAccent.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 15))
    }
  }
  private var events: some View {
    VStack(alignment: .leading, spacing: 16) {
      title("Зустрінемось там", sub: "Події, де легко почати розмову", count: vm.events.count)
      if vm.events.isEmpty {
        empty("Подій поки немає", "Спробуй інший кантон або повернися пізніше.")
      } else {
        ForEach(vm.events) { e in
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              VStack(alignment: .leading, spacing: 5) {
                Text(e.title).font(.headline).foregroundColor(.white)
                Text("\(e.city) · \(e.startsAt.formatted(date:.abbreviated,time:.shortened))").font(
                  .caption
                ).foregroundColor(.white.opacity(0.55))
              }
              Spacer()
              Text("\(e.attendeeCount)").font(.headline.bold()).foregroundColor(limeAccent)
            }
            HStack {
              Button {
                Task { await vm.attend(e) }
              } label: {
                Label(
                  e.myStatus == "going" ? "Я йду" : "Піти",
                  systemImage: e.myStatus == "going" ? "checkmark.circle.fill" : "plus.circle.fill"
                ).font(.subheadline.bold()).foregroundColor(.black).padding(.horizontal, 16).frame(
                  height: 42
                ).background(limeAccent).clipShape(Capsule())
              }
              if e.myStatus == "going" {
                Button {
                  Task {
                    do {
                      vm.profiles = try await FriendsAPI.profiles(eventID: e.id).items
                      tab = 0
                    } catch { vm.error = error.localizedDescription }
                  }
                } label: {
                  Text("Хто буде").font(.subheadline.bold()).foregroundColor(.white)
                }
                if e.groupChatAvailable {
                  Button {
                    eventChat = e
                  } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill").foregroundColor(
                      limeAccent)
                  }
                }
              }
              Spacer()
              Button {
                event = e
              } label: {
                Image(systemName: "arrow.up.right").foregroundColor(.white)
              }
            }
          }.padding(17).background(.white.opacity(0.065)).clipShape(
            RoundedRectangle(cornerRadius: 22)
          ).overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.1)))
        }
      }
    }.padding(.horizontal, 18)
  }
  private var connections: some View {
    VStack(alignment: .leading, spacing: 18) {
      title("Твоє коло", sub: "Заявки та активні друзі", count: vm.friends.count)
      if !vm.incoming.isEmpty {
        Text("НОВІ ЗАПИТИ").font(.caption.bold()).tracking(1.5).foregroundColor(limeAccent)
        ForEach(vm.incoming) { c in connectionRow(c, incoming: true) }
      }
      if !vm.friends.isEmpty {
        Text("ДРУЗІ").font(.caption.bold()).tracking(1.5).foregroundColor(.white.opacity(0.5))
        ForEach(vm.friends) { c in connectionRow(c, incoming: false) }
      }
      if vm.incoming.isEmpty && vm.friends.isEmpty {
        empty(
          "Коло ще формується",
          "Знайди людину зі спільними інтересами та надішли коротке привітання.")
      }
    }.padding(.horizontal, 18)
  }
  private func connectionRow(_ c: FriendConnection, incoming: Bool) -> some View {
    HStack(spacing: 12) {
      avatar(c.otherProfile)
      VStack(alignment: .leading) {
        Text(c.otherProfile.displayName).font(.headline).foregroundColor(.white)
        Text(c.sharedInterests.map { $0.title }.joined(separator: " · ")).font(.caption)
          .foregroundColor(.white.opacity(0.5)).lineLimit(1)
      }
      Spacer()
      if incoming {
        Button {
          Task { _ = await vm.decide(c, accept: true) }
        } label: {
          Image(systemName: "checkmark").foregroundColor(.black).frame(width: 40, height: 40)
            .background(limeAccent).clipShape(Circle())
        }
        HStack(spacing: 10) {
          Button {
            guard subscription.isPremium else { paywall = true; return }
            Task { await vm.loadVisitors(); showVisitors = true }
          } label: {
            Label("Гості профілю", systemImage: "eye.fill").frame(maxWidth: .infinity, minHeight: 50)
          }
          Toggle(isOn: Binding(get: { invisibleBrowsing }, set: { value in
            if subscription.isPremium { invisibleBrowsing = value } else { paywall = true }
          })) { Label("Невидимий", systemImage: "eye.slash.fill") }
          .toggleStyle(.button).frame(maxWidth: .infinity, minHeight: 50)
        }.font(.caption.bold()).foregroundColor(limeAccent)
      } else if let id = c.conversationID {
        Button {
          Task {
            do { conversation = try await ChatAPI.conversation(id: id) } catch {
              vm.error = error.localizedDescription
            }
          }
        } label: {
          Image(systemName: "message.fill").foregroundColor(limeAccent)
        }
      }
    }.padding(14).background(.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 20))
  }
  private var profile: some View {
    VStack(alignment: .leading, spacing: 18) {
      if let p = vm.myProfile {
        VStack(alignment: .leading, spacing: 18) {
          moderationBanner(status: p.moderationStatus, reason: p.moderationReason)
          HStack(spacing: 15) {
            avatar(p).scaleEffect(1.2)
            VStack(alignment: .leading, spacing: 4) {
              Text("SOCIAL PASSPORT").font(.caption2.bold()).tracking(1.8).foregroundColor(
                limeAccent)
              Text(p.displayName).font(.title2.bold()).foregroundColor(.white)
              Text("\(p.city) · \(p.canton)").font(.subheadline).foregroundColor(
                .white.opacity(0.58))
            }
            Spacer()
            Image(systemName: "checkmark.shield.fill").font(.title2).foregroundColor(limeAccent)
          }
          Text(p.bio).foregroundColor(.white.opacity(0.75))
          FlowLayout(spacing: 8) {
            ForEach(p.interests) { i in
              Label(i.title, systemImage: i.icon).font(.caption.bold()).foregroundColor(.white)
                .padding(.horizontal, 11).padding(.vertical, 8).background(
                  limeAccent.opacity(0.12)
                ).clipShape(Capsule()).overlay(Capsule().stroke(limeAccent.opacity(0.2)))
            }
          }
        }.padding(20).background(
          LinearGradient(
            colors: [forest, .white.opacity(0.035)], startPoint: .topLeading,
            endPoint: .bottomTrailing)
        ).clipShape(RoundedRectangle(cornerRadius: 28)).overlay(
          RoundedRectangle(cornerRadius: 28).stroke(limeAccent.opacity(0.25)))
        Button {
          editor = true
        } label: {
          HStack {
            Text("Редагувати social passport").font(.headline)
            Spacer()
            Image(systemName: "arrow.up.right")
          }.foregroundColor(.black).padding(.horizontal, 20).frame(
            maxWidth: .infinity, minHeight: 58
          )
          .background(limeAccent).clipShape(RoundedRectangle(cornerRadius: 19))
        }
        Text("Твої контакти не публікуються. Видимість участі у подіях контролюється окремо.").font(
          .caption
        ).foregroundColor(.white.opacity(0.45))
        Button {
          if subscription.isPremium {
            Task { if await vm.boost() {} }
          } else {
            paywall = true
          }
        } label: {
          HStack {
            Label("Підняти профіль на 7 днів", systemImage: "bolt.fill")
            Spacer()
            Text("PLUS").font(.caption.bold())
          }
          .foregroundColor(limeAccent).padding(16).background(limeAccent.opacity(0.08)).clipShape(
            RoundedRectangle(cornerRadius: 18)
          ).overlay(RoundedRectangle(cornerRadius: 18).stroke(limeAccent.opacity(0.2)))
        }
      } else {
        profileLaunchCard
      }
    }.padding(.horizontal, 18)
  }
  private func moderationBanner(status: String, reason: String?) -> some View {
    let pending = status == "pending"
    let rejected = status == "rejected"
    return HStack(alignment: .top, spacing: 11) {
      Image(systemName: pending ? "clock.badge.checkmark" : rejected ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
      VStack(alignment: .leading, spacing: 3) {
        Text(pending ? "Профіль на перевірці" : rejected ? "Профіль потребує змін" : "Профіль схвалено").font(.subheadline.bold())
        Text(rejected ? (reason ?? "Відредагуй дані та надішли профіль повторно.") : pending ? "Після схвалення профіль з’явиться у пошуку людей." : "Профіль видимий у каталозі.").font(.caption)
      }
      Spacer()
    }
    .foregroundColor(rejected ? .orange : limeAccent)
    .padding(14).background((rejected ? Color.orange : limeAccent).opacity(0.09))
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
  private var profileLaunchCard: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 7) {
          Text("ТВІЙ КРУГ У ШВЕЙЦАРІЇ").font(.caption2.bold()).tracking(1.9).foregroundColor(
            limeAccent)
          Text("Створи свій\nsocial passport").font(
            .system(size: 29, weight: .black, design: .rounded)
          )
          .lineSpacing(-2).foregroundColor(.white)
          Text("Знайомства за інтересами, подіями та кантоном.").font(.subheadline)
            .foregroundColor(.white.opacity(0.58)).fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 10)
        ZStack {
          Circle().stroke(limeAccent.opacity(0.18), lineWidth: 1).frame(width: 94, height: 94)
          Circle().stroke(limeAccent.opacity(0.45), lineWidth: 1).frame(width: 66, height: 66)
          Circle().fill(limeAccent.opacity(0.12)).frame(width: 52, height: 52)
          Text("CH").font(.headline.bold()).foregroundColor(limeAccent)
          Circle().fill(limeAccent).frame(width: 10, height: 10).offset(x: 33, y: -27)
        }
      }
      VStack(spacing: 0) {
        profileStep("sparkles", "Інтереси", "Обери теми, які тебе захоплюють")
        Divider().overlay(.white.opacity(0.08)).padding(.leading, 46)
        profileStep("person.2.fill", "Формат зустрічей", "Прогулянки, спорт, кава або події")
        Divider().overlay(.white.opacity(0.08)).padding(.leading, 46)
        profileStep("lock.shield.fill", "Приватність", "Контакти приховані, контроль завжди твій")
      }.padding(.horizontal, 14).background(.black.opacity(0.24)).clipShape(
        RoundedRectangle(cornerRadius: 20))
      Button {
        editor = true
      } label: {
        HStack {
          Text("Створити social passport").font(.headline)
          Spacer()
          Image(systemName: "arrow.right").font(.headline.bold())
        }.foregroundColor(.black).padding(.horizontal, 20).frame(maxWidth: .infinity, minHeight: 58)
          .background(limeAccent).clipShape(RoundedRectangle(cornerRadius: 19))
      }
      Label("Професійний профіль залишається окремим", systemImage: "checkmark.shield.fill")
        .font(.caption).foregroundColor(.white.opacity(0.5)).frame(maxWidth: .infinity)
    }.padding(20).background(
      LinearGradient(
        colors: [forest, Color(red: 0.012, green: 0.024, blue: 0.02)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    ).clipShape(RoundedRectangle(cornerRadius: 30)).overlay(
      RoundedRectangle(cornerRadius: 30).stroke(limeAccent.opacity(0.3))
    )
    .shadow(color: limeAccent.opacity(0.09), radius: 28, y: 12)
  }
  private func profileStep(_ icon: String, _ title: String, _ subtitle: String) -> some View {
    HStack(spacing: 13) {
      Image(systemName: icon).font(.subheadline.bold()).foregroundColor(limeAccent).frame(
        width: 34, height: 34
      ).background(limeAccent.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 11))
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.bold()).foregroundColor(.white)
        Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.48)).lineLimit(2)
      }
      Spacer(minLength: 0)
    }.padding(.vertical, 11)
  }
  private func title(_ text: String, sub: String, count: Int) -> some View {
    HStack {
      VStack(alignment: .leading) {
        Text(text).font(.title2.bold()).foregroundColor(.white)
        Text(sub).font(.caption).foregroundColor(.white.opacity(0.48))
      }
      Spacer()
      Text("\(count)").font(.headline.bold()).foregroundColor(.black).frame(width: 38, height: 38)
        .background(limeAccent).clipShape(Circle())
    }
  }
  private func empty(_ t: String, _ s: String) -> some View {
    VStack(spacing: 10) {
      Image(systemName: "person.2.wave.2.fill").font(.largeTitle).foregroundColor(limeAccent)
      Text(t).font(.headline).foregroundColor(.white)
      Text(s).font(.subheadline).multilineTextAlignment(.center).foregroundColor(
        .white.opacity(0.55))
    }.frame(maxWidth: .infinity).padding(34).background(.white.opacity(0.05)).clipShape(
      RoundedRectangle(cornerRadius: 24))
  }
  private func chip(_ text: String, icon: String? = nil, active: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      HStack {
        if let icon { Image(systemName: icon) }
        Text(text)
      }.font(.caption.bold()).foregroundColor(active ? .black : .white.opacity(0.65)).padding(
        .horizontal, 14
      ).frame(height: 40).background(active ? limeAccent : .white.opacity(0.07)).clipShape(
        Capsule()
      )
      .overlay(Capsule().stroke(.white.opacity(0.1)))
    }
  }
  private func avatar(_ p: SocialProfile) -> some View {
    Text(p.initials).font(.headline.bold()).foregroundColor(.black).frame(width: 48, height: 48)
      .background(
        LinearGradient(
          colors: [limeAccent, mintGlow], startPoint: .topLeading, endPoint: .bottomTrailing)
      ).clipShape(Circle())
  }
}

private struct FriendVisitorsView: View {
  @Environment(\.dismiss) private var dismiss
  let visitors: [SocialProfileVisitor]
  var body: some View {
    NavigationStack {
      ZStack {
        JourneyVisual.black.ignoresSafeArea()
        ScrollView {
          LazyVStack(spacing: 12) {
            if visitors.isEmpty {
              ContentUnavailableView("Гостей ще немає", systemImage: "eye", description: Text("Тут з’являться люди, які відкривали твій social passport."))
            } else {
              ForEach(visitors) { item in
                HStack(spacing: 13) {
                  Text(item.profile.initials).font(.headline.bold()).foregroundStyle(.black).frame(width: 48, height: 48).background(JourneyVisual.lime).clipShape(Circle())
                  VStack(alignment: .leading, spacing: 3) { Text(item.profile.displayName).font(.headline).foregroundStyle(.white); Text("\(item.profile.city) · \(item.visitCount) переглядів").font(.caption).foregroundStyle(.white.opacity(0.55)) }
                  Spacer(); Text(item.lastVisitedAt, style: .relative).font(.caption2).foregroundStyle(.white.opacity(0.45))
                }.padding(14).background(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 18))
              }
            }
          }.padding(18)
        }
      }.navigationTitle("Гості профілю").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } } }
    }
  }
}

private struct FriendCard: View {
  let profile: SocialProfile
  let accent: Color
  var body: some View {
    HStack(spacing: 14) {
      Text(profile.initials).font(.title3.bold()).foregroundColor(.black).frame(
        width: 58, height: 58
      ).background(
        LinearGradient(
          colors: [accent, Color(red: 0.63, green: 0.93, blue: 0.62)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      ).clipShape(Circle())
      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Text(profile.displayName).font(.headline).foregroundColor(.white)
          if profile.isVerified { Image(systemName: "checkmark.seal.fill").foregroundColor(accent) }
        }
        Text("\(profile.city) · \(profile.canton)").font(.caption).foregroundColor(
          .white.opacity(0.48))
        Text(profile.sharedInterests.prefix(3).map { $0.title }.joined(separator: " · ")).font(
          .caption.bold()
        ).foregroundColor(.white.opacity(0.75)).lineLimit(1)
      }
      Spacer()
      VStack {
        Text("\(profile.matchScore)%").font(.headline.bold()).foregroundColor(accent)
        Text("збіг").font(.caption2).foregroundColor(.white.opacity(0.4))
      }
    }.padding(15).background(.white.opacity(0.065)).clipShape(RoundedRectangle(cornerRadius: 22))
      .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.1)))
  }
}

private struct FriendProfileDetail: View {
  @Environment(\.dismiss) var dismiss
  let profile: SocialProfile
  @ObservedObject var vm: FriendNetworkViewModel
  @Binding var conversation: ChatConversation?
  @State var message = ""
  private var isDemo: Bool { profile.id.hasPrefix("preview-") }
  var body: some View {
    ZStack {
      JourneyVisual.black.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack {
            Button {
              dismiss()
            } label: {
              Image(systemName: "xmark").foregroundColor(.white).frame(width: 48, height: 48)
                .background(.white.opacity(0.1)).clipShape(Circle())
            }
            Spacer()
            if !isDemo { Menu {
              Button("Поскаржитися", role: .destructive) {
                Task {
                  do {
                    try await FriendsAPI.report(profile.id)
                  } catch {
                    vm.error = error.localizedDescription
                  }
                }
              }
              Button("Заблокувати", role: .destructive) {
                Task {
                  do {
                    try await FriendsAPI.block(profile.id)
                    dismiss()
                  } catch {
                    vm.error = error.localizedDescription
                  }
                }
              }
            } label: {
              Image(systemName: "ellipsis").foregroundColor(.white)
            } }
          }
          Text("\(profile.matchScore)% збіг").font(.caption.bold()).foregroundColor(
            JourneyVisual.lime)
          Text(profile.displayName).font(.system(size: 38, weight: .black, design: .rounded))
            .foregroundColor(.white)
          Text("\(profile.city) · \(profile.canton)").foregroundColor(.white.opacity(0.55))
          Text(profile.bio).foregroundColor(.white.opacity(0.76))
          Text("СПІЛЬНІ ІНТЕРЕСИ").font(.caption.bold()).tracking(1.5).foregroundColor(
            JourneyVisual.lime)
          FlowLayout(spacing: 8) {
            ForEach(profile.sharedInterests) { i in
              Label(i.title, systemImage: i.icon).font(.caption.bold()).foregroundColor(.white)
                .padding(10).background(JourneyVisual.lime.opacity(0.12)).clipShape(Capsule())
                .overlay(Capsule().stroke(JourneyVisual.lime.opacity(0.2)))
            }
          }
          if isDemo {
            Label("Демо-профіль · дії вимкнені", systemImage: "sparkles")
              .font(.subheadline.bold()).foregroundColor(JourneyVisual.lime)
              .frame(maxWidth: .infinity, minHeight: 52)
              .background(JourneyVisual.lime.opacity(0.1))
              .clipShape(RoundedRectangle(cornerRadius: 17))
          } else if profile.connectionState == "accepted", let id = profile.conversationID {
            Button {
              Task { conversation = try? await ChatAPI.conversation(id: id) }
            } label: {
              Text("Відкрити чат").font(.headline).foregroundColor(.black).frame(
                maxWidth: .infinity, minHeight: 56
              ).background(JourneyVisual.lime).clipShape(RoundedRectangle(cornerRadius: 18))
            }
          } else if profile.connectionState == "none" {
            TextField("Коротко привітайся…", text: $message, axis: .vertical).padding().background(
              .white.opacity(0.08)
            ).clipShape(RoundedRectangle(cornerRadius: 16)).foregroundColor(.white)
            Button {
              Task { if await vm.connect(profile, message: message) { dismiss() } }
            } label: {
              Text("Запропонувати дружбу").font(.headline).foregroundColor(.black).frame(
                maxWidth: .infinity, minHeight: 56
              ).background(JourneyVisual.lime).clipShape(RoundedRectangle(cornerRadius: 18))
            }
          } else {
            Text(
              profile.connectionState == "incoming"
                ? "Заявка очікує твоєї відповіді" : "Заявку надіслано"
            ).foregroundColor(.white.opacity(0.6))
          }
          Text("Зустрічайся у публічному місці. Не надсилай гроші або документи незнайомим людям.")
            .font(.caption).foregroundColor(.white.opacity(0.4))
        }.padding(20)
      }
    }
  }
}

private struct FriendSearchFilters: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var vm: FriendNetworkViewModel
  @Binding var showPaywall: Bool
  @StateObject private var subscription = SubscriptionManager.shared
  private let lime = JourneyVisual.lime
  private let languages = ["UK", "DE", "FR", "IT", "EN", "RU"]
  var body: some View {
    NavigationStack {
      ZStack {
        JourneyVisual.black.ignoresSafeArea()
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            header("Локація", icon: "mappin.and.ellipse")
            Menu {
              Button("Усі кантони") { vm.canton = nil }
              ForEach(SwissCanton.all, id: \.code) { c in
                Button("\(c.name) · \(c.code)") { vm.canton = c.code }
              }
            } label: {
              filterRow("Кантон", value: vm.canton ?? "Усі")
            }
            plusSection("Радіус", icon: "location.circle.fill") {
              Picker("Радіус", selection: $vm.maxDistanceKM) {
                Text("Будь-який").tag(Int?.none)
                ForEach([10, 25, 50, 100], id: \.self) { Text("до \($0) км").tag(Optional($0)) }
              }.pickerStyle(.segmented)
            }
            plusSection("Мова", icon: "character.bubble.fill") {
              chipRow(languages, selected: vm.language) {
                vm.language = vm.language == $0 ? nil : $0
              }
            }
            plusSection("Вік", icon: "person.2.fill") {
              chipRow(SocialAgeBand.allCases.map(\.rawValue), selected: vm.ageBand) {
                vm.ageBand = vm.ageBand == $0 ? nil : $0
              }
            }
            plusSection("Досвід у Швейцарії", icon: "flag.fill") {
              chipRow(
                ["Нові мешканці", "Давно тут"],
                selected: vm.residency == "newcomer"
                  ? "Нові мешканці" : vm.residency == "established" ? "Давно тут" : nil
              ) { vm.residency = $0 == "Нові мешканці" ? "newcomer" : "established" }
            }
            plusSection("Нові люди поруч", icon: "dot.radiowaves.left.and.right") {
              Toggle("Показати профілі в радіусі 25 км", isOn: $vm.nearby).tint(lime)
                .foregroundColor(.white)
            }
          }.padding(20).padding(.bottom, 30)
        }
      }.navigationTitle("Пошук людей").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Застосувати") {
              Task {
                await vm.reload()
                dismiss()
              }
            }.foregroundColor(lime)
          }
        }
        .task { await subscription.load() }
    }
  }
  private func header(_ text: String, icon: String) -> some View {
    Label(text, systemImage: icon).font(.headline).foregroundColor(.white)
  }
  private func filterRow(_ title: String, value: String) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text(value).foregroundColor(lime)
      Image(systemName: "chevron.down")
    }.foregroundColor(.white).padding().background(.white.opacity(0.065)).clipShape(
      RoundedRectangle(cornerRadius: 18))
  }
  @ViewBuilder private func plusSection<Content: View>(
    _ title: String, icon: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        header(title, icon: icon)
        Spacer()
        Text("PLUS").font(.caption2.bold()).foregroundColor(.black).padding(.horizontal, 9).padding(
          .vertical, 5
        ).background(lime).clipShape(Capsule())
      }
      if subscription.isPremium {
        content()
      } else {
        Button {
          dismiss()
          showPaywall = true
        } label: {
          HStack {
            Image(systemName: "lock.fill")
            Text("Відкрити розширений фільтр")
            Spacer()
            Image(systemName: "arrow.right")
          }.foregroundColor(.white).padding().background(.white.opacity(0.065)).clipShape(
            RoundedRectangle(cornerRadius: 18))
        }
      }
    }
  }
  private func chipRow(_ items: [String], selected: String?, action: @escaping (String) -> Void)
    -> some View
  {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(items, id: \.self) { item in
          Button(item) { action(item) }.font(.caption.bold()).foregroundColor(
            selected == item ? .black : .white
          ).padding(.horizontal, 13).frame(height: 40).background(
            selected == item ? lime : .white.opacity(0.08)
          ).clipShape(Capsule())
        }
      }
    }
  }
}

private struct SocialEventChatView: View {
  @Environment(\.dismiss) private var dismiss
  let event: SocialEvent
  let friends: [FriendConnection]
  @ObservedObject var vm: FriendNetworkViewModel
  @State private var messages: [SocialEventMessage] = []
  @State private var text = ""
  @State private var invitePicker = false
  private let lime = JourneyVisual.lime
  var body: some View {
    NavigationStack {
      ZStack {
        JourneyVisual.black.ignoresSafeArea()
        VStack(spacing: 0) {
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(messages) { message in
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(message.senderName).font(.caption.bold()).foregroundColor(lime)
                    Text(message.body).foregroundColor(.white)
                  }.padding(12).background(.white.opacity(0.07)).clipShape(
                    RoundedRectangle(cornerRadius: 16))
                  Spacer(minLength: 45)
                }
              }
            }.padding()
          }
          HStack {
            TextField("Повідомлення групі", text: $text).foregroundColor(.white).padding(13)
              .background(.white.opacity(0.08)).clipShape(Capsule())
            Button {
              Task { await send() }
            } label: {
              Image(systemName: "arrow.up").foregroundColor(.black).frame(width: 46, height: 46)
                .background(lime).clipShape(Circle())
            }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }.padding()
        }
      }.navigationTitle(event.title).navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } }
        ToolbarItem(placement: .primaryAction) {
          Button {
            invitePicker = true
          } label: {
            Image(systemName: "person.badge.plus")
          }
        }
      }.task {
        while !Task.isCancelled {
          await load()
          try? await Task.sleep(for: .seconds(5))
        }
      }.sheet(isPresented: $invitePicker) {
        NavigationStack {
          List(friends) { friend in
            Button(friend.otherProfile.displayName) {
              Task {
                do {
                  _ = try await FriendsAPI.invite(
                    eventID: event.id, friendID: friend.otherProfile.id)
                  invitePicker = false
                } catch { vm.error = error.localizedDescription }
              }
            }
          }.navigationTitle("Запросити друга")
        }
      }
    }
  }
  private func load() async {
    do { messages = try await FriendsAPI.eventMessages(event.id) } catch {
      vm.error = error.localizedDescription
    }
  }
  private func send() async {
    let body = text
    text = ""
    do { messages.append(try await FriendsAPI.sendEventMessage(event.id, body: body)) } catch {
      vm.error = error.localizedDescription
    }
  }
}

private struct FriendProfileEditor: View {
  private enum Step: Int, CaseIterable {
    case identity, interests, languages, meetups, availability, photo, safety, preview
  }
  @Environment(\.dismiss) private var dismiss
  let profile: SocialProfile?
  @ObservedObject var vm: FriendNetworkViewModel
  @State private var d: SocialProfileDraft
  @State private var step: Step = .identity
  @State private var photoItem: PhotosPickerItem?
  @State private var photo: UIImage?
  @State private var uploading = false
  @State private var saving = false
  @State private var error: String?
  @StateObject private var locationService = LocationService()
  private let lime = JourneyVisual.lime

  init(profile: SocialProfile?, vm: FriendNetworkViewModel) {
    self.profile = profile
    self.vm = vm
    _d = State(initialValue: profile.map(SocialProfileDraft.init) ?? SocialProfileDraft())
  }

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient(
          colors: [Color(red: 0.02, green: 0.08, blue: 0.055), JourneyVisual.black],
          startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
        VStack(spacing: 0) {
          progress
          ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
              heading
              content
            }
            .padding(.horizontal, 20).padding(.vertical, 22).padding(.bottom, 110)
          }
        }
      }.safeAreaInset(edge: .bottom) { controls }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Закрити") { dismiss() }.foregroundColor(.white)
          }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(
          "Social Passport",
          isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(error ?? "")
        }
        .onChange(of: photoItem) { _, item in Task { await loadPhoto(item) } }
        .onChange(of: locationService.currentLocation) { _, location in
          d.latitude = location?.coordinate.latitude
          d.longitude = location?.coordinate.longitude
          locationService.stopLocationUpdates()
        }
    }
  }

  private var progress: some View {
    VStack(spacing: 8) {
      HStack {
        Text("SOCIAL PASSPORT · CH").font(.caption2.bold()).tracking(1.8)
        Spacer()
        Text("\(step.rawValue + 1)/8").font(.caption.bold())
      }
      .foregroundColor(lime)
      GeometryReader { g in
        ZStack(alignment: .leading) {
          Capsule().fill(.white.opacity(0.1))
          Capsule().fill(lime).frame(width: g.size.width * CGFloat(step.rawValue + 1) / 8)
        }
      }.frame(height: 4)
    }.padding(.horizontal, 20).padding(.vertical, 12).background(.black.opacity(0.3))
  }

  private var heading: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(stepTitle).font(.system(size: 32, weight: .black, design: .rounded)).foregroundColor(
        .white)
      Text(stepSubtitle).font(.subheadline).foregroundColor(.white.opacity(0.56))
    }
  }

  @ViewBuilder private var content: some View {
    switch step {
    case .identity: identity
    case .interests:
      choiceGrid(
        SocialInterest.allCases, selected: d.interests, title: { $0.title }, icon: { $0.icon }
      ) { toggle($0, in: &d.interests) }
    case .languages: languages
    case .meetups:
      choiceGrid(
        MeetupFormat.allCases, selected: d.meetupFormats, title: { $0.title },
        icon: { _ in "person.2.fill" }
      ) { toggle($0, in: &d.meetupFormats) }
    case .availability: availability
    case .photo: photoStep
    case .safety: safety
    case .preview: preview
    }
  }

  private var identity: some View {
    VStack(spacing: 13) {
      field("person.fill", "Ім’я", text: $d.displayName)
      field("building.2.fill", "Місто", text: $d.city)
      Menu {
        ForEach(SwissCanton.all, id: \.code) { c in
          Button("\(c.name) · \(c.code)") { d.canton = c.code }
        }
      } label: {
        row("mappin.and.ellipse", "Кантон", value: d.canton)
      }
      Menu {
        Button("Не вказувати") { d.ageBand = nil }
        ForEach(SocialAgeBand.allCases) { band in
          Button(band.rawValue) { d.ageBand = band.rawValue }
        }
      } label: {
        row("person.2.fill", "Вікова група", value: d.ageBand ?? "Не вказано")
      }
      Stepper(
        value: Binding(get: { d.arrivalYear ?? 2026 }, set: { d.arrivalYear = $0 }),
        in: 1950...Calendar.current.component(.year, from: Date())
      ) {
        HStack {
          Image(systemName: "flag.fill").foregroundColor(lime)
          Text("У Швейцарії з")
          Spacer()
          Text(String(d.arrivalYear ?? 2026)).foregroundColor(lime)
        }
      }.tint(lime).padding().background(.white.opacity(0.07)).clipShape(
        RoundedRectangle(cornerRadius: 18))
      Text(
        "Радіус пошуку можна увімкнути після дозволу геолокації. Точні координати іншим не показуються."
      )
      .font(.caption).foregroundColor(.white.opacity(0.45))
      Button {
        locationService.requestLocationPermission()
        locationService.startLocationUpdates()
      } label: {
        Label(
          locationService.currentLocation == nil ? "Додати приблизну локацію" : "Локацію додано",
          systemImage: locationService.currentLocation == nil
            ? "location.fill" : "checkmark.circle.fill"
        ).font(.subheadline.bold()).foregroundColor(
          locationService.currentLocation == nil ? .black : lime
        )
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(locationService.currentLocation == nil ? lime : lime.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
      }
      TextField("Розкажи про себе — мінімум 30 символів", text: $d.bio, axis: .vertical).lineLimit(
        4...7
      )
      .padding().background(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 18))
      .foregroundColor(.white)
    }
  }

  private var languages: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      ForEach(["UK", "DE", "FR", "IT", "EN", "RU"], id: \.self) { language in
        let active = d.languages.contains(language)
        Button {
          toggle(language, in: &d.languages)
        } label: {
          VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "character.bubble.fill").font(.title2)
            Text(language).font(.subheadline.bold())
          }.foregroundColor(active ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading).padding(14)
            .background(active ? lime : .white.opacity(0.065))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
      }
    }
  }

  private var availability: some View {
    choiceGrid(
      SocialAvailability.allCases, selected: d.availability, title: { $0.title }, icon: { $0.icon }
    ) { toggle($0, in: &d.availability) }
  }

  private var photoStep: some View {
    VStack(spacing: 20) {
      ZStack {
        Circle().fill(lime.opacity(0.12)).frame(width: 180, height: 180)
        if let photo {
          Image(uiImage: photo).resizable().scaledToFill().frame(width: 170, height: 170).clipShape(
            Circle())
        } else {
          Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 76))
            .foregroundColor(lime)
        }
      }.overlay(Circle().stroke(lime.opacity(0.35), lineWidth: 2))
      PhotosPicker(selection: $photoItem, matching: .images) {
        Label(photo == nil ? "Додати фото" : "Замінити фото", systemImage: "photo.fill").font(
          .headline
        )
        .foregroundColor(.black).padding(.horizontal, 22).frame(height: 52).background(lime)
        .clipShape(Capsule())
      }
      Text("Фото перевіряється разом з описом. Контакти та документи на фото заборонені.")
        .font(.caption).multilineTextAlignment(.center).foregroundColor(.white.opacity(0.48))
    }.frame(maxWidth: .infinity).padding(24).background(.white.opacity(0.045)).clipShape(
      RoundedRectangle(cornerRadius: 28))
  }

  private var safety: some View {
    VStack(spacing: 12) {
      safetyToggle(
        "Показувати профіль", "Профіль бере участь у пошуку", icon: "eye.fill", value: $d.isVisible)
      safetyToggle(
        "Відкритий до знайомств", "Інші можуть надіслати запит", icon: "person.badge.plus",
        value: $d.openToFriends)
      safetyToggle(
        "Правила спільноти", "Без продажів, переслідувань та небезпечних зустрічей",
        icon: "checkmark.shield.fill", value: $d.guidelinesAccepted)
      Label(
        "Контакти не публікуються. Точна геолокація не показується іншим.", systemImage: "lock.fill"
      )
      .font(.caption).foregroundColor(.white.opacity(0.5)).padding(.top, 6)
    }
  }

  private var preview: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 14) {
        Group {
          if let photo {
            Image(uiImage: photo).resizable().scaledToFill()
          } else {
            Text(initials).font(.title.bold()).foregroundColor(.black)
          }
        }
        .frame(width: 76, height: 76).background(lime).clipShape(Circle())
        VStack(alignment: .leading, spacing: 4) {
          Text(d.displayName).font(.title2.bold())
          Text("\(d.city) · \(d.canton)").foregroundColor(.white.opacity(0.55))
          Label("Email підтверджено", systemImage: "checkmark.seal.fill").font(.caption)
            .foregroundColor(lime)
        }
      }
      Text(d.bio).foregroundColor(.white.opacity(0.76))
      FlowLayout(spacing: 8) {
        ForEach(d.interests) { i in
          Label(i.title, systemImage: i.icon).font(.caption.bold()).padding(10).background(
            lime.opacity(0.12)
          ).clipShape(Capsule())
        }
      }
      Label("Профіль буде надіслано на перевірку адміністратору", systemImage: "shield.lefthalf.filled")
        .font(.caption).foregroundColor(.white.opacity(0.5))
    }.foregroundColor(.white).padding(20).background(
      LinearGradient(
        colors: [Color(red: 0.03, green: 0.13, blue: 0.09), .black], startPoint: .topLeading,
        endPoint: .bottomTrailing)
    ).clipShape(RoundedRectangle(cornerRadius: 28)).overlay(
      RoundedRectangle(cornerRadius: 28).stroke(lime.opacity(0.3)))
  }

  private var controls: some View {
    HStack(spacing: 12) {
      if step != .identity {
        Button {
          step = Step(rawValue: step.rawValue - 1)!
        } label: {
          Image(systemName: "arrow.left").frame(width: 52, height: 56).background(
            .white.opacity(0.08)
          ).clipShape(RoundedRectangle(cornerRadius: 18))
        }
      }
      Button {
        advance()
      } label: {
        HStack {
          if saving || uploading { ProgressView().tint(.black) }
          Text(step == .preview ? "Опублікувати профіль" : "Продовжити").font(.headline)
          Spacer()
          Image(systemName: step == .preview ? "checkmark" : "arrow.right")
        }
        .foregroundColor(.black).padding(.horizontal, 20).frame(maxWidth: .infinity, minHeight: 56)
        .background(canContinue ? lime : .gray).clipShape(RoundedRectangle(cornerRadius: 18))
      }.disabled(!canContinue || saving || uploading)
    }.padding(16).background(.ultraThinMaterial)
  }

  private var canContinue: Bool {
    switch step {
    case .identity: return d.displayName.count >= 2 && d.city.count >= 2 && d.bio.count >= 30
    case .interests: return d.interests.count >= 2
    case .languages: return !d.languages.isEmpty
    case .meetups: return !d.meetupFormats.isEmpty
    case .availability: return !d.availability.isEmpty
    case .safety: return d.guidelinesAccepted
    default: return true
    }
  }
  private var stepTitle: String {
    [
      "Хто ти", "Твої інтереси", "Мови спілкування", "Як зустрічаємось", "Коли ти вільний",
      "Твоє фото", "Безпека", "Перевір профіль",
    ][step.rawValue]
  }
  private var stepSubtitle: String {
    [
      "Створимо основу social passport.", "Обери мінімум дві теми.",
      "Вкажи мови для комфортного спілкування.", "Обери один або кілька форматів.",
      "Допоможи знайти зручний час.", "Живе фото підвищує довіру.",
      "Ти контролюєш видимість і контакти.", "Так тебе побачать інші люди.",
    ][step.rawValue]
  }
  private var initials: String {
    d.displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
      .uppercased()
  }

  private func advance() {
    if step == .preview {
      Task { await save() }
    } else if let next = Step(rawValue: step.rawValue + 1) {
      withAnimation { step = next }
    }
  }
  private func save() async {
    saving = true
    error = nil
    vm.error = nil
    defer { saving = false }
    do {
      if let photo, d.avatarURL.isEmpty {
        uploading = true
        defer { uploading = false }
        if let data = photo.jpegData(compressionQuality: 0.82) {
          d.avatarURL = try await APIClient.uploadMarketplaceImage(
            data: data, filename: "social-\(UUID().uuidString).jpg")
        }
      }
      if await vm.save(d) {
        dismiss()
      } else {
        error = vm.error ?? "Профіль не опубліковано. Дані збережені на екрані — перевір причину та спробуй ще раз."
        vm.error = nil
      }
    } catch { self.error = error.localizedDescription }
  }
  private func loadPhoto(_ item: PhotosPickerItem?) async {
    guard let data = try? await item?.loadTransferable(type: Data.self),
      let image = UIImage(data: data)
    else { return }
    photo = image
  }
  private func toggle<T: Equatable>(_ item: T, in items: inout [T]) {
    if let i = items.firstIndex(of: item) { items.remove(at: i) } else { items.append(item) }
  }
  private func field(_ icon: String, _ placeholder: String, text: Binding<String>) -> some View {
    HStack {
      Image(systemName: icon).foregroundColor(lime)
      TextField(placeholder, text: text).foregroundColor(.white)
    }.padding().background(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 18))
  }
  private func row(_ icon: String, _ title: String, value: String) -> some View {
    HStack {
      Image(systemName: icon).foregroundColor(lime)
      Text(title).foregroundColor(.white)
      Spacer()
      Text(value).foregroundColor(lime)
      Image(systemName: "chevron.down").foregroundColor(.white.opacity(0.4))
    }.padding().background(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 18))
  }
  private func safetyToggle(_ title: String, _ subtitle: String, icon: String, value: Binding<Bool>)
    -> some View
  {
    HStack(spacing: 13) {
      Image(systemName: icon).foregroundColor(lime).frame(width: 38, height: 38).background(
        lime.opacity(0.1)
      ).clipShape(RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading) {
        Text(title).font(.headline).foregroundColor(.white)
        Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.48))
      }
      Spacer()
      Toggle("", isOn: value).labelsHidden().tint(lime)
    }.padding(15).background(.white.opacity(0.055)).clipShape(RoundedRectangle(cornerRadius: 20))
  }
  private func choiceGrid<T: Identifiable & Equatable>(
    _ items: [T], selected: [T], title: @escaping (T) -> String,
    icon: @escaping (T) -> String, action: @escaping (T) -> Void
  ) -> some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      ForEach(items) { item in
        let active = selected.contains(item)
        Button {
          action(item)
        } label: {
          VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon(item)).font(.title2)
            Text(title(item)).font(.subheadline.bold()).lineLimit(2)
          }.foregroundColor(active ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading).padding(14)
            .background(active ? lime : .white.opacity(0.065))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(active ? lime : .white.opacity(0.1)))
        }
      }
    }
  }
}
