import SwiftUI

@MainActor final class FriendNetworkViewModel: ObservableObject {
  @Published var profiles: [SocialProfile] = []
  @Published var connections: [FriendConnection] = []
  @Published var events: [SocialEvent] = []
  @Published var myProfile: SocialProfile?
  @Published var loading = false
  @Published var error: String?
  @Published var query = ""
  @Published var interest: SocialInterest?
  @Published var canton: String?
  var incoming: [FriendConnection] {
    connections.filter { $0.direction == "incoming" && $0.status == "pending" }
  }
  var friends: [FriendConnection] { connections.filter { $0.status == "accepted" } }
  func load() async {
    guard !loading else { return }
    loading = true
    defer { loading = false }
    do {
      async let p = FriendsAPI.profiles(query: query, canton: canton, interest: interest)
      async let c = FriendsAPI.connections()
      async let e = FriendsAPI.events(canton: canton)
      async let m = own()
      let values = try await (p, c, e, m)
      profiles = values.0.items
      connections = values.1
      events = values.2
      myProfile = values.3
      error = nil
    } catch { self.error = error.localizedDescription }
  }
  func reload() async {
    do {
      profiles = try await FriendsAPI.profiles(query: query, canton: canton, interest: interest)
        .items
      events = try await FriendsAPI.events(canton: canton)
    } catch { self.error = error.localizedDescription }
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
      _ = try await FriendsAPI.attend(e.id, status: e.myStatus == nil ? "interested" : "going")
      await reload()
    } catch { self.error = error.localizedDescription }
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
  private let coral = Color(red: 1, green: 0.42, blue: 0.34),
    sky = Color(red: 0.32, green: 0.78, blue: 1)
  var body: some View {
    ZStack(alignment: .top) {
      JourneyVisual.black.ignoresSafeArea()
      Image("journey-place-community").resizable().scaledToFill().frame(height: 410).clipped()
        .overlay(
          LinearGradient(
            colors: [.black.opacity(0.05), .black.opacity(0.35), JourneyVisual.black],
            startPoint: .top, endPoint: .bottom)
        ).ignoresSafeArea(edges: .top)
      ScrollView(showsIndicators: false) {
        LazyVStack(spacing: 0) {
          hero
          tabs
          Group {
            switch tab {
            case 1: events
            case 2: connections
            case 3: profile
            default: discover
            }
          }.padding(.top, 18)
        }.padding(.bottom, 44)
      }.refreshable { await vm.load() }
    }
    .toolbar(.hidden, for: .navigationBar).task { await vm.load() }
    .fullScreenCover(item: $selected) {
      FriendProfileDetail(profile: $0, vm: vm, conversation: $conversation).environmentObject(
        appContainer)
    }
    .fullScreenCover(item: $conversation) {
      ChatConversationView(conversation: $0).environmentObject(appContainer)
    }
    .fullScreenCover(isPresented: $editor) { FriendProfileEditor(profile: vm.myProfile, vm: vm) }
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
          ).frame(height: 40).background(coral).clipShape(Capsule())
        }
      }
      Spacer()
      Text("SWEEZY FRIENDS").font(.caption.bold()).tracking(2.5).foregroundColor(coral)
      Text("Знайди своїх\nу Швейцарії").font(.system(size: 42, weight: .black, design: .rounded))
        .lineSpacing(-4).foregroundColor(.white)
      Text("Спільні інтереси, події та живі зустрічі — без випадкових знайомств.").font(
        .subheadline.weight(.medium)
      ).foregroundColor(.white.opacity(0.72)).frame(maxWidth: 340, alignment: .leading)
    }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 18).frame(height: 350)
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
          ).frame(height: 50).background(tab == i ? coral : .clear).clipShape(Capsule())
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
        ProgressView().tint(coral).frame(maxWidth: .infinity).padding(60)
      } else if vm.profiles.isEmpty {
        empty("Немає збігів", "Зміни інтерес або кантон — нові люди з’являються щодня.")
      } else {
        LazyVStack(spacing: 13) {
          ForEach(vm.profiles) { p in
            Button {
              selected = p
            } label: {
              FriendCard(profile: p, accent: coral)
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
          colors: [
            Color(red: 0.10, green: 0.06, blue: 0.10), Color(red: 0.04, green: 0.10, blue: 0.12),
          ], startPoint: .topLeading, endPoint: .bottomTrailing))
      HStack {
        VStack(alignment: .leading, spacing: 6) {
          Text("INTEREST ORBIT").font(.caption2.bold()).tracking(1.7).foregroundColor(coral)
          Text("\(vm.profiles.count) збігів поруч").font(.title3.bold()).foregroundColor(.white)
          Text("Люди, з якими вже є про що поговорити").font(.caption).foregroundColor(
            .white.opacity(0.55))
        }
        Spacer()
        ZStack {
          Circle().stroke(coral.opacity(0.25)).frame(width: 92, height: 92)
          Circle().stroke(sky.opacity(0.35)).frame(width: 58, height: 58)
          Circle().fill(coral).frame(width: 15, height: 15).offset(x: 34, y: -24)
          Circle().fill(sky).frame(width: 11, height: 11).offset(x: -22, y: 18)
        }
      }.padding(20)
    }.frame(height: 145).overlay(RoundedRectangle(cornerRadius: 28).stroke(coral.opacity(0.35)))
  }
  private var search: some View {
    VStack(spacing: 10) {
      HStack {
        Image(systemName: "magnifyingglass").foregroundColor(coral)
        TextField("Ім’я, місто або інтерес", text: $vm.query).foregroundColor(.white).submitLabel(
          .search
        ).onSubmit { Task { await vm.reload() } }
      }.padding(.horizontal, 16).frame(height: 56).background(.white.opacity(0.07)).clipShape(
        RoundedRectangle(cornerRadius: 18)
      ).overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1)))
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
              Text("\(e.attendeeCount)").font(.headline.bold()).foregroundColor(coral)
            }
            HStack {
              Button {
                Task { await vm.attend(e) }
              } label: {
                Label(
                  e.myStatus == nil ? "Цікаво" : "Я йду",
                  systemImage: e.myStatus == nil ? "plus.circle.fill" : "checkmark.circle.fill"
                ).font(.subheadline.bold()).foregroundColor(.black).padding(.horizontal, 16).frame(
                  height: 42
                ).background(coral).clipShape(Capsule())
              }
              if e.myStatus != nil {
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
        Text("НОВІ ЗАПИТИ").font(.caption.bold()).tracking(1.5).foregroundColor(coral)
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
            .background(coral).clipShape(Circle())
        }
      } else if let id = c.conversationID {
        Button {
          Task {
            do { conversation = try await ChatAPI.conversation(id: id) } catch {
              vm.error = error.localizedDescription
            }
          }
        } label: {
          Image(systemName: "message.fill").foregroundColor(coral)
        }
      }
    }.padding(14).background(.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 20))
  }
  private var profile: some View {
    VStack(alignment: .leading, spacing: 18) {
      if let p = vm.myProfile {
        HStack(spacing: 15) {
          avatar(p).scaleEffect(1.25)
          VStack(alignment: .leading) {
            Text(p.displayName).font(.title2.bold()).foregroundColor(.white)
            Text("\(p.city) · \(p.canton)").foregroundColor(.white.opacity(0.55))
          }
        }
        Text(p.bio).foregroundColor(.white.opacity(0.75))
        FlowLayout(spacing: 8) {
          ForEach(p.interests) { i in
            Label(i.title, systemImage: i.icon).font(.caption.bold()).foregroundColor(.white)
              .padding(.horizontal, 11).padding(.vertical, 8).background(coral.opacity(0.16))
              .clipShape(Capsule())
          }
        }
        Button {
          editor = true
        } label: {
          Text("Редагувати профіль").font(.headline).foregroundColor(.black).frame(
            maxWidth: .infinity, minHeight: 54
          ).background(coral).clipShape(RoundedRectangle(cornerRadius: 18))
        }
        Text("Твої контакти не публікуються. Видимість участі у подіях контролюється окремо.").font(
          .caption
        ).foregroundColor(.white.opacity(0.45))
      } else {
        empty(
          "Створи профіль для друзів",
          "Обери інтереси та формат зустрічей. Професійний профіль залишиться окремим.")
        Button {
          editor = true
        } label: {
          Text("Створити профіль").font(.headline).foregroundColor(.black).frame(
            maxWidth: .infinity, minHeight: 54
          ).background(coral).clipShape(RoundedRectangle(cornerRadius: 18))
        }
      }
    }.padding(.horizontal, 18)
  }
  private func title(_ text: String, sub: String, count: Int) -> some View {
    HStack {
      VStack(alignment: .leading) {
        Text(text).font(.title2.bold()).foregroundColor(.white)
        Text(sub).font(.caption).foregroundColor(.white.opacity(0.48))
      }
      Spacer()
      Text("\(count)").font(.headline.bold()).foregroundColor(.black).frame(width: 38, height: 38)
        .background(coral).clipShape(Circle())
    }
  }
  private func empty(_ t: String, _ s: String) -> some View {
    VStack(spacing: 10) {
      Image(systemName: "person.2.wave.2.fill").font(.largeTitle).foregroundColor(coral)
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
      ).frame(height: 40).background(active ? coral : .white.opacity(0.07)).clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1)))
    }
  }
  private func avatar(_ p: SocialProfile) -> some View {
    Text(p.initials).font(.headline.bold()).foregroundColor(.black).frame(width: 48, height: 48)
      .background(
        LinearGradient(colors: [coral, sky], startPoint: .topLeading, endPoint: .bottomTrailing)
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
        LinearGradient(colors: [accent, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
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
          Text("\(profile.matchScore)% збіг").font(.caption.bold()).foregroundColor(.orange)
          Text(profile.displayName).font(.system(size: 38, weight: .black, design: .rounded))
            .foregroundColor(.white)
          Text("\(profile.city) · \(profile.canton)").foregroundColor(.white.opacity(0.55))
          Text(profile.bio).foregroundColor(.white.opacity(0.76))
          Text("СПІЛЬНІ ІНТЕРЕСИ").font(.caption.bold()).tracking(1.5).foregroundColor(.orange)
          FlowLayout(spacing: 8) {
            ForEach(profile.sharedInterests) { i in
              Label(i.title, systemImage: i.icon).font(.caption.bold()).foregroundColor(.white)
                .padding(10).background(.orange.opacity(0.16)).clipShape(Capsule())
            }
          }
          if profile.connectionState == "accepted", let id = profile.conversationID {
            Button {
              Task { conversation = try? await ChatAPI.conversation(id: id) }
            } label: {
              Text("Відкрити чат").font(.headline).foregroundColor(.black).frame(
                maxWidth: .infinity, minHeight: 56
              ).background(.orange).clipShape(RoundedRectangle(cornerRadius: 18))
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
              ).background(.orange).clipShape(RoundedRectangle(cornerRadius: 18))
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

private struct FriendProfileEditor: View {
  @Environment(\.dismiss) var dismiss
  let profile: SocialProfile?
  @ObservedObject var vm: FriendNetworkViewModel
  @State var d: SocialProfileDraft
  init(profile: SocialProfile?, vm: FriendNetworkViewModel) {
    self.profile = profile
    self.vm = vm
    _d = State(initialValue: profile.map(SocialProfileDraft.init) ?? SocialProfileDraft())
  }
  var body: some View {
    NavigationStack {
      Form {
        Section("Про тебе") {
          TextField("Ім’я", text: $d.displayName)
          TextField("Місто", text: $d.city)
          TextField("Кантон", text: $d.canton)
          TextField("Кілька слів про себе", text: $d.bio, axis: .vertical).lineLimit(4...7)
        }
        Section("Інтереси — мінімум 2") {
          ForEach(SocialInterest.allCases) { i in
            Toggle(
              isOn: Binding(
                get: { d.interests.contains(i) },
                set: { on in
                  if on {
                    if !d.interests.contains(i) { d.interests.append(i) }
                  } else {
                    d.interests.removeAll { $0 == i }
                  }
                })
            ) { Label(i.title, systemImage: i.icon) }
          }
        }
        Section("Формат зустрічі") {
          ForEach(MeetupFormat.allCases) { f in
            Toggle(
              f.title,
              isOn: Binding(
                get: { d.meetupFormats.contains(f) },
                set: { on in
                  if on { d.meetupFormats.append(f) } else { d.meetupFormats.removeAll { $0 == f } }
                }))
          }
        }
        Section("Безпека") {
          Toggle("Показувати профіль", isOn: $d.isVisible)
          Toggle("Відкритий до нових друзів", isOn: $d.openToFriends)
          Toggle("Приймаю правила спільноти", isOn: $d.guidelinesAccepted)
        }
      }.scrollContentBackground(.hidden).background(JourneyVisual.black).navigationTitle(
        profile == nil ? "Профіль друзів" : "Редагувати"
      ).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Зберегти") { Task { if await vm.save(d) { dismiss() } } }.disabled(
            d.displayName.count < 2 || d.bio.count < 30 || d.interests.count < 2)
        }
      }
    }
  }
}
