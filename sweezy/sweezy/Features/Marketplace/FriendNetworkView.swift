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
  @Published var loadError: String?
  @Published var query = ""
  @Published var interest: SocialInterest?
  @Published var canton: String?
  @Published var language: String?
  @Published var ageBand: String?
  @Published var residency: String?
  @Published var maxDistanceKM: Int?
  @Published var nearby = false
  @Published var searchMeta: SocialProfilePage?
  var incoming: [FriendConnection] {
    connections.filter { $0.direction == "incoming" && $0.status == "pending" }
  }
  var friends: [FriendConnection] { connections.filter { $0.status == "accepted" } }
  private func friendResult<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
    do { return .success(try await operation()) }
    catch { return .failure(error) }
  }
  func load() async {
    guard !loading else { return }
    loading = true
    defer { loading = false }
    async let p = friendResult { try await FriendsAPI.profiles(query: self.query, canton: self.canton, interest: self.interest) }
    async let c = friendResult { try await FriendsAPI.connections() }
    async let e = friendResult { try await FriendsAPI.events(canton: self.canton) }
    async let m = friendResult { try await self.own() }
    let values = await (p, c, e, m)
    var failures: [Error] = []
    switch values.0 { case .success(let page): profiles = page.items; searchMeta = page; case .failure(let issue): failures.append(issue) }
    switch values.1 { case .success(let value): connections = value; case .failure(let issue): failures.append(issue) }
    switch values.2 { case .success(let value): events = value; case .failure(let issue): failures.append(issue) }
    switch values.3 { case .success(let value): myProfile = value; case .failure(let issue): failures.append(issue) }
    loadError = failures.isEmpty ? nil : "friends.error.partial".localized
  }
  func reload() async {
    async let page = friendResult {
      try await FriendsAPI.profiles(
        query: self.query, canton: self.canton, interest: self.interest,
        language: self.language, ageBand: self.ageBand, residency: self.residency,
        maxDistanceKM: self.maxDistanceKM, nearby: self.nearby)
    }
    async let eventPage = friendResult { try await FriendsAPI.events(canton: self.canton) }
    let values = await (page, eventPage)
    var failed = false
    switch values.0 { case .success(let value): profiles = value.items; searchMeta = value; case .failure: failed = true }
    switch values.1 { case .success(let value): events = value; case .failure: failed = true }
    loadError = failed ? "friends.error.partial".localized : nil
  }
  func own() async throws -> SocialProfile? {
    do { return try await FriendsAPI.myProfile() } catch  where (error as NSError).code == 404 {
      return nil
    }
  }
  func save(_ d: SocialProfileDraft) async -> Bool {
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
}

struct FriendNetworkView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var appContainer: AppContainer
  @StateObject private var vm = FriendNetworkViewModel()
  @State private var tab = 0
  @State private var editor = false
  @State private var selected: SocialProfile?
  @State private var event: SocialEvent?
  @State private var conversation: ChatConversation?
  @State private var filters = false
  @State private var paywall = false
  @State private var eventChat: SocialEvent?
  @StateObject private var subscription = SubscriptionManager.shared
  private let limeAccent = JourneyVisual.lime
  private let forest = Color(red: 0.035, green: 0.105, blue: 0.075)
  private let mintGlow = Color(red: 0.63, green: 0.93, blue: 0.62)
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .top) {
        JourneyVisual.black.ignoresSafeArea()
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
        ScrollView(showsIndicators: false) {
          LazyVStack(spacing: 0) {
            hero
            tabs
            if let loadError = vm.loadError {
              networkIssue(message: loadError)
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
            Group {
              switch tab {
              case 1: events
              case 2: connections
              case 3: profile
              default: discover
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
    .toolbar(.hidden, for: .navigationBar).task {
      if isProfileUITestPreview { tab = 3 }
      if isEditorUITestPreview {
        tab = 3
        editor = true
      }
      if !isUITestPreview { await vm.load() }
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
    .alert(
      "Sweezy Friends",
      isPresented: Binding(get: { vm.error != nil }, set: { if !$0 { vm.error = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(vm.error ?? "")
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
  private var hero: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Button {
          dismiss()
        } label: {
          Image(systemName: "chevron.left").font(.title2.bold()).foregroundColor(.white).frame(
            width: 52, height: 52
          ).background(.black.opacity(0.38)).clipShape(Circle()).overlay(
            Circle().stroke(.white.opacity(0.2)))
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
  private var isUITestPreview: Bool {
    #if DEBUG
      ProcessInfo.processInfo.environment["UITESTS"] == "1"
        && (ProcessInfo.processInfo.arguments.contains("--ui-test-friends")
          || ProcessInfo.processInfo.arguments.contains("--ui-test-friends-profile"))
    #else
      false
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
    HStack(spacing: 4) {
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
          VStack(spacing: 3) {
            Image(systemName: x.1)
            Text(x.0)
          }.font(.caption.bold()).foregroundColor(tab == i ? .black : .white.opacity(0.58)).frame(
            maxWidth: .infinity
          ).frame(height: 50).background(tab == i ? limeAccent : .clear).clipShape(Capsule())
        }
      }
    }.padding(5).background(.white.opacity(0.07)).clipShape(Capsule()).overlay(
      Capsule().stroke(.white.opacity(0.12))
    ).padding(.horizontal, 18)
  }
  private var discover: some View {
    VStack(alignment: .leading, spacing: 18) {
      orbit
      search
      title("Твої люди", sub: "За інтересами, мовою та кантоном", count: vm.profiles.count)
      if vm.loading && vm.profiles.isEmpty {
        ProgressView().tint(limeAccent).frame(maxWidth: .infinity).padding(60)
      } else if vm.profiles.isEmpty {
        empty("Немає збігів", "Зміни інтерес або кантон — нові люди з’являються щодня.")
      } else {
        LazyVStack(spacing: 13) {
          ForEach(vm.profiles) { p in
            Button {
              selected = p
            } label: {
              FriendCard(profile: p, accent: limeAccent)
            }.buttonStyle(.plain)
          }
        }
      }
    }.padding(.horizontal, 18)
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
            Menu {
              Button("Поскаржитися", role: .destructive) {
                Task { try? await FriendsAPI.report(profile.id) }
              }
              Button("Заблокувати", role: .destructive) {
                Task {
                  try? await FriendsAPI.block(profile.id)
                  dismiss()
                }
              }
            } label: {
              Image(systemName: "ellipsis").foregroundColor(.white)
            }
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
          if profile.connectionState == "accepted", let id = profile.conversationID {
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
      Label("Профіль пройде автоматичну safety-перевірку", systemImage: "shield.lefthalf.filled")
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
      if await vm.save(d) { dismiss() }
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
