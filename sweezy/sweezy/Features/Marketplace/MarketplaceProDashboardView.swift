import SwiftUI

struct MarketplaceProDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer
    let dashboard: MarketplaceProDashboard?
    let listings: [ServiceListing]
    let workspace: BusinessWorkspace?
    let onPromoted: (ServiceListing) -> Void
    @StateObject private var model: BusinessProViewModel
    @State private var tab: ProTab = .today
    @State private var editor: ProSheet?
    @State private var selectedConversation: ChatConversation?

    init(
        dashboard: MarketplaceProDashboard?,
        listings: [ServiceListing],
        workspace: BusinessWorkspace? = nil,
        onPromoted: @escaping (ServiceListing) -> Void
    ) {
        self.dashboard = dashboard
        self.listings = listings
        self.workspace = workspace
        self.onPromoted = onPromoted
        _model = StateObject(wrappedValue: BusinessProViewModel(workspace: workspace))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JourneyPhotoBackground(imageName: JourneyBackdrop.market.rawValue, blurRadius: 12, darkness: 0.84)
                if model.isLoading && model.profile == nil {
                    ProgressView().tint(JourneyVisual.lime)
                } else if model.profile == nil {
                    BusinessProfileOnboarding(model: model)
                } else {
                    mainContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Image(systemName: "xmark") } }
                ToolbarItem(placement: .primaryAction) { Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") }.disabled(model.isLoading) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sweezy Pro", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
            .sheet(item: $editor) { sheet in
                switch sheet {
                case .profile: BusinessProfileEditor(model: model)
                case .service: BusinessServiceEditor(model: model, listings: listings)
                case .booking: BusinessBookingEditor(model: model)
                case .client: BusinessClientEditor(model: model)
                case .quickReply: BusinessQuickReplyEditor(model: model)
                case .team: BusinessTeamEditor(model: model)
                case .availability: BusinessAvailabilityEditor(model: model)
                case .document: BusinessDocumentEditor(model: model)
                }
            }
            .fullScreenCover(item: $selectedConversation) { ChatConversationView(conversation: $0).environmentObject(appContainer) }
        }
        .task { await model.load() }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            proHeader
            tabRail
            ScrollView(showsIndicators: false) {
                Group {
                    switch tab {
                    case .today: todayView
                    case .leads: leadsView
                    case .calendar: calendarView
                    case .clients: clientsView
                    case .receptionist: receptionistView
                    case .more: moreView
                    }
                }
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 40)
            }.refreshable { await model.load() }
        }
    }

    private var proHeader: some View {
        HStack(spacing: 12) {
            ZStack { RoundedRectangle(cornerRadius: 16).fill(JourneyVisual.lime); Image(systemName: "briefcase.fill").font(.title3.bold()).foregroundStyle(.black) }.frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) { Text(model.profile?.displayName ?? "Sweezy Pro").font(.headline).foregroundStyle(.white).lineLimit(1); if model.profile?.isVerified == true { Image(systemName: "checkmark.seal.fill").foregroundStyle(JourneyVisual.lime) } }
                Text(profileStatus).font(.caption).foregroundStyle(profileStatusColor)
            }
            Spacer()
            if workspace == nil { Button { editor = .profile } label: { Image(systemName: "slider.horizontal.3").foregroundStyle(.white).frame(width: 42, height: 42).background(.white.opacity(0.08)).clipShape(Circle()) } }
        }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 12).background(.black.opacity(0.42))
    }

    private var tabRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(availableTabs) { item in
                    Button { withAnimation(.snappy) { tab = item } } label: {
                        Label(item.title, systemImage: item.icon).font(.caption.weight(.bold)).padding(.horizontal, 14).frame(height: 44)
                            .foregroundStyle(tab == item ? .black : .white.opacity(0.62)).background(tab == item ? JourneyVisual.lime : .white.opacity(0.07), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 18).padding(.bottom, 10)
        }.background(.black.opacity(0.42))
    }

    private var todayView: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("СЬОГОДНІ У БІЗНЕСІ").font(.caption.bold()).tracking(2).foregroundStyle(JourneyVisual.lime)
                Text(todayHeadline).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(todayAdvice).foregroundStyle(.white.opacity(0.62))
            }
            metricsGrid
            if let next = model.dashboard?.bookings.first(where: { $0.startsAt >= Date() }) { nextBookingCard(next) }
            if let lead = model.dashboard?.leads.first(where: { $0.status == "new" }) { nextLeadCard(lead) }
            businessHealth
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
            metric("Нові заявки", model.dashboard?.openLeads ?? 0, "bubble.left.and.exclamationmark.bubble.right.fill", JourneyVisual.lime)
            metric("Записи сьогодні", model.dashboard?.bookingsToday ?? 0, "calendar.badge.clock", .cyan)
            metric("Перегляди", model.dashboard?.totalViews ?? listings.reduce(0) { $0 + $1.viewCount }, "eye.fill", .white)
            metric("Конверсія", model.dashboard?.conversionPercent ?? 0, "chart.line.uptrend.xyaxis", .orange, suffix: "%")
        }
    }

    private func metric(_ title: String, _ value: Int, _ icon: String, _ color: Color, suffix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).font(.headline)
            Text("\(value)\(suffix)").font(.system(size: 27, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.55))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).proCard()
    }

    private func nextBookingCard(_ booking: BusinessBooking) -> some View {
        Button { tab = .calendar } label: {
            HStack(spacing: 14) {
                ProDateBadge(date: booking.startsAt)
                VStack(alignment: .leading, spacing: 4) { Text("Наступний запис").font(.caption.bold()).foregroundStyle(JourneyVisual.lime); Text(booking.customerName).font(.headline).foregroundStyle(.white); Text(booking.startsAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.white.opacity(0.55)) }
                Spacer(); Image(systemName: "arrow.right").foregroundStyle(JourneyVisual.lime)
            }.padding(16).proCard(stroke: JourneyVisual.lime.opacity(0.28))
        }.buttonStyle(.plain)
    }

    private func nextLeadCard(_ lead: BusinessLead) -> some View {
        Button { Task { await openConversation(lead) } } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.exclamationmark").font(.title2).foregroundStyle(.black).frame(width: 50, height: 50).background(JourneyVisual.lime).clipShape(RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 4) { Text("Потрібна відповідь").font(.caption.bold()).foregroundStyle(JourneyVisual.lime); Text(lead.customerName).font(.headline).foregroundStyle(.white); Text(lead.nextAction ?? "Відкрити діалог").font(.caption).foregroundStyle(.white.opacity(0.55)).lineLimit(1) }
                Spacer(); Image(systemName: "message.fill").foregroundStyle(JourneyVisual.lime)
            }.padding(16).proCard(stroke: JourneyVisual.lime.opacity(0.28))
        }.buttonStyle(.plain)
    }

    private var businessHealth: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Стан бізнесу").font(.title3.bold()).foregroundStyle(.white)
            healthRow("Швидкість відповіді", model.dashboard?.responseRatePercent ?? 0)
            healthRow("Заповнення профілю", profileCompletion)
            healthRow("Активні послуги", min(100, model.services.filter(\.isActive).count * 25))
        }.padding(17).proCard()
    }

    private func healthRow(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 7) {
            HStack { Text(title).font(.subheadline).foregroundStyle(.white.opacity(0.72)); Spacer(); Text("\(value)%").font(.caption.bold()).foregroundStyle(JourneyVisual.lime) }
            GeometryReader { geo in Capsule().fill(.white.opacity(0.08)).overlay(alignment: .leading) { Capsule().fill(JourneyVisual.lime).frame(width: geo.size.width * CGFloat(value) / 100) } }.frame(height: 5)
        }
    }

    private var leadsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Заявки", "Веди клієнта від першого повідомлення до виконаної роботи")
            if model.leads.isEmpty { proEmpty("Нових заявок немає", "Звернення з Marketplace автоматично з’являться тут.", "bubble.left.and.bubble.right") }
            ForEach(model.leads) { lead in
                VStack(alignment: .leading, spacing: 12) {
                    HStack { VStack(alignment: .leading, spacing: 3) { Text(lead.customerName).font(.headline).foregroundStyle(.white); Text(lead.source.capitalized).font(.caption).foregroundStyle(.white.opacity(0.45)) }; Spacer(); ProStatusPill(status: lead.status) }
                    if let action = lead.nextAction { Label(action, systemImage: "arrow.turn.down.right").font(.caption).foregroundStyle(.white.opacity(0.62)) }
                    HStack {
                        if workspace == nil, lead.conversationID != nil { Button("Відкрити чат") { Task { await openConversation(lead) } }.buttonStyle(ProOutlineButton()) }
                        Menu("Змінити етап") { ForEach(ProLeadStage.allCases) { stage in Button(stage.title) { Task { await model.changeLead(lead, to: stage.rawValue) } } } }.buttonStyle(ProLimeButton()).disabled(model.isReadOnly)
                    }
                }.padding(16).proCard(stroke: lead.status == "new" ? JourneyVisual.lime.opacity(0.35) : .clear)
            }
        }
    }

    private var calendarView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { sectionTitle("Календар", "Записи, нагадування та статуси"); Spacer(); plusButton { editor = .booking } }
            if model.bookings.isEmpty { proEmpty("Календар порожній", "Створи перший запис або перетвори заявку на бронювання.", "calendar.badge.plus") }
            ForEach(model.bookings.sorted { $0.startsAt < $1.startsAt }) { booking in
                HStack(alignment: .top, spacing: 14) {
                    ProDateBadge(date: booking.startsAt)
                    VStack(alignment: .leading, spacing: 5) { Text(booking.customerName).font(.headline).foregroundStyle(.white); Text(booking.startsAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.white.opacity(0.65)); if let location = booking.location, !location.isEmpty { Label(location, systemImage: "mappin").font(.caption).foregroundStyle(.white.opacity(0.48)) } }
                    Spacer(); Menu { ForEach(["confirmed", "completed", "cancelled", "no_show"], id: \.self) { status in Button(status.capitalized) { Task { await model.changeBooking(booking, to: status) } } } } label: { ProStatusPill(status: booking.status) }.disabled(model.isReadOnly)
                }.padding(16).proCard()
            }
        }
    }

    private var clientsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { sectionTitle("Клієнти", "Історія, нотатки та повторні звернення"); Spacer(); plusButton { editor = .client } }
            if model.clients.isEmpty { proEmpty("Клієнтів ще немає", "Додай клієнта вручну або створи його із заявки.", "person.2") }
            ForEach(model.clients) { client in
                HStack(spacing: 13) {
                    Text(client.displayName.prefix(1).uppercased()).font(.title3.bold()).foregroundStyle(.black).frame(width: 48, height: 48).background(JourneyVisual.lime).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) { Text(client.displayName).font(.headline).foregroundStyle(.white); Text("\(client.completedCount) виконано · CHF \(Double(client.totalSpendCents) / 100, specifier: "%.0f")").font(.caption).foregroundStyle(.white.opacity(0.52)) }
                    Spacer(); Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
                }.padding(15).proCard()
            }
        }
    }

    private var receptionistView: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("AI-рецепціоніст", "Знає твої послуги, правила й стиль спілкування")
            HStack(spacing: 13) {
                ZStack { Circle().fill(JourneyVisual.lime); Image(systemName: "sparkles").font(.title2.bold()).foregroundStyle(.black) }.frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 4) { Text(model.aiSettings.aiEnabled ? "Рецепціоніст активний" : "Рецепціоніст вимкнений").font(.headline).foregroundStyle(.white); Text(model.aiSettings.aiAutoReply ? "Автовідповіді увімкнені" : "Відповіді спочатку підтверджуєш ти").font(.caption).foregroundStyle(.white.opacity(0.55)) }
                Spacer(); Toggle("", isOn: Binding(get: { model.aiSettings.aiEnabled }, set: { model.aiSettings.aiEnabled = $0; Task { await model.saveAI() } })).labelsHidden().tint(JourneyVisual.lime)
            }.padding(17).proCard(stroke: JourneyVisual.lime.opacity(0.35))
            NavigationLink { AIReceptionistSettingsView(model: model) } label: { proAction("Налаштувати характер і знання", "slider.horizontal.3", "Факти, правила, мови, тон та передача людині") }.buttonStyle(.plain)
            NavigationLink { AIReceptionistTestView(model: model) } label: { proAction("Протестувати відповідь", "message.badge.waveform", "Напиши запит клієнта й перевір результат") }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 10) { Label("Контроль власника", systemImage: "hand.raised.fill").foregroundStyle(JourneyVisual.lime).font(.headline); Text("AI не вигадує ціни, не підтверджує вільний час і передає тобі скарги, повернення коштів та складні випадки.").foregroundStyle(.white.opacity(0.6)).font(.subheadline) }.padding(17).proCard()
        }
    }

    private var moreView: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Керування", "Усе, що формує роботу твого бізнесу")
            proGroup("Послуги", count: model.services.count, icon: "square.grid.2x2.fill", action: { editor = .service }) { ForEach(model.services.prefix(4)) { item in ProCompactRow(title: item.title, subtitle: "\(item.durationMinutes) хв · \(item.priceText)", active: item.isActive) } }
            Button { editor = .availability } label: { proAction("Графік роботи", "clock.fill", "\(model.availability.count) активних часових вікон") }.buttonStyle(.plain)
            proGroup("Швидкі відповіді", count: model.quickReplies.count, icon: "text.bubble.fill", action: { editor = .quickReply }) { ForEach(model.quickReplies.prefix(3)) { item in ProCompactRow(title: item.title, subtitle: item.body, active: item.isActive) } }
            proGroup("Команда", count: model.team.count, icon: "person.3.fill", action: { editor = .team }) { ForEach(model.team.prefix(3)) { item in ProCompactRow(title: item.displayName, subtitle: "\(item.role) · \(item.status)", active: item.status == "active") } }
            VStack(alignment: .leading, spacing: 12) {
                HStack { Label("Документи", systemImage: "doc.text.fill").font(.headline).foregroundStyle(.white); Spacer(); Text("\(model.documents.count)").foregroundStyle(JourneyVisual.lime); plusButton { editor = .document } }
                Text("Пропозиції, підтвердження та рахунки зберігаються тут.").font(.caption).foregroundStyle(.white.opacity(0.52))
                ForEach(model.documents.prefix(3)) { item in
                    ProCompactRow(
                        title: item.title,
                        subtitle: "\(item.number) · CHF \(String(format: "%.2f", Double(item.totalCents) / 100))",
                        active: item.status == "paid"
                    )
                }
            }.padding(17).proCard()
            VStack(alignment: .leading, spacing: 12) {
                Text("Просування").font(.headline).foregroundStyle(.white)
                ForEach(listings.filter { $0.status == .approved }) { listing in HStack { Text(listing.title).foregroundStyle(.white).lineLimit(1); Spacer(); Button(listing.isFeatured ? "Активне" : "Підняти") { Task { await promote(listing) } }.font(.caption.bold()).foregroundStyle(.black).padding(.horizontal, 12).padding(.vertical, 8).background(JourneyVisual.lime, in: Capsule()).disabled(listing.isFeatured) } }
            }.padding(17).proCard()
        }
    }

    private func proGroup<Content: View>(_ title: String, count: Int, icon: String, action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { HStack { Label(title, systemImage: icon).font(.headline).foregroundStyle(.white); Spacer(); Text("\(count)").foregroundStyle(JourneyVisual.lime); plusButton(action) }; content() }.padding(17).proCard()
    }
    private func proAction(_ title: String, _ icon: String, _ subtitle: String) -> some View { HStack(spacing: 14) { Image(systemName: icon).font(.title3.bold()).foregroundStyle(.black).frame(width: 48, height: 48).background(JourneyVisual.lime).clipShape(RoundedRectangle(cornerRadius: 15)); VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(.white); Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.52)).lineLimit(2) }; Spacer(); Image(systemName: "arrow.right").foregroundStyle(JourneyVisual.lime) }.padding(16).proCard() }
    private func sectionTitle(_ title: String, _ subtitle: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 27, weight: .black, design: .rounded)).foregroundStyle(.white); Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.55)) } }
    private func proEmpty(_ title: String, _ subtitle: String, _ icon: String) -> some View { VStack(spacing: 12) { Image(systemName: icon).font(.largeTitle).foregroundStyle(JourneyVisual.lime); Text(title).font(.headline).foregroundStyle(.white); Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(30).proCard() }
    private func plusButton(_ action: @escaping () -> Void) -> some View { Button(action: action) { Image(systemName: "plus").font(.headline).foregroundStyle(.black).frame(width: 38, height: 38).background(JourneyVisual.lime).clipShape(Circle()) } }
    private var todayHeadline: String { (model.dashboard?.openLeads ?? 0) > 0 ? "Є клієнти, які чекають" : "Бізнес під контролем" }
    private var todayAdvice: String { (model.dashboard?.openLeads ?? 0) > 0 ? "Відповідай швидше — це напряму впливає на конверсію." : "Нові заявки, записи й важливі дії з’являться тут." }
    private var profileCompletion: Int { guard let p = model.profile else { return 0 }; return [!p.displayName.isEmpty, !p.description.isEmpty, !p.languages.isEmpty, !p.deliveryModes.isEmpty, p.phone != nil || p.email != nil, p.logoURL != nil].filter { $0 }.count * 100 / 6 }
    private var profileStatus: String { switch model.profile?.status { case "approved": "Перевірений бізнес · Plus"; case "pending": "Профіль на перевірці"; case "rejected": "Потрібні зміни"; case "suspended": "Профіль призупинено"; default: "Чернетка профілю" } }
    private var profileStatusColor: Color { model.profile?.status == "approved" ? JourneyVisual.lime : .orange }
    private var availableTabs: [ProTab] { workspace == nil ? ProTab.allCases : [.today, .leads, .calendar, .clients] }
    private func openConversation(_ lead: BusinessLead) async { guard let id = lead.conversationID else { return }; do { selectedConversation = try await ChatAPI.conversation(id: id) } catch { model.error = error.localizedDescription } }
    private func promote(_ listing: ServiceListing) async { do { onPromoted(try await APIClient.promoteListing(id: listing.id)) } catch { model.error = error.localizedDescription } }
}

@MainActor final class BusinessProViewModel: ObservableObject {
    let workspace: BusinessWorkspace?
    @Published var profile: BusinessProfile?
    @Published var dashboard: BusinessProDashboard?
    @Published var services: [BusinessServiceItem] = []
    @Published var availability: [BusinessAvailabilityRule] = []
    @Published var leads: [BusinessLead] = []
    @Published var bookings: [BusinessBooking] = []
    @Published var clients: [BusinessClientItem] = []
    @Published var quickReplies: [BusinessQuickReply] = []
    @Published var team: [BusinessTeamMember] = []
    @Published var documents: [BusinessDocumentItem] = []
    @Published var aiSettings: BusinessAISettings = .empty
    @Published var isLoading = false
    @Published var error: String?

    init(workspace: BusinessWorkspace? = nil) { self.workspace = workspace }
    var isReadOnly: Bool { workspace?.role == "viewer" }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            let result = if let workspace { try await BusinessProAPI.workspaceDashboard(ownerID: workspace.ownerUserID) } else { try await BusinessProAPI.dashboard() }
            dashboard = result; profile = result.profile; leads = result.leads; bookings = result.bookings; clients = result.clients; quickReplies = result.quickReplies
            if workspace == nil {
                async let servicesTask = BusinessProAPI.services(); async let availabilityTask = BusinessProAPI.availability(); async let settingsTask = BusinessProAPI.aiSettings(); async let teamTask = BusinessProAPI.team(); async let docsTask = BusinessProAPI.documents()
                services = try await servicesTask; availability = try await availabilityTask; aiSettings = try await settingsTask; team = try await teamTask; documents = try await docsTask
            }
        } catch { if (error as NSError).code == 404 { profile = nil; dashboard = nil } else { self.error = error.localizedDescription } }
    }
    func saveProfile(_ payload: BusinessProfilePayload, submit: Bool) async -> Bool { do { profile = try await BusinessProAPI.saveProfile(payload); if submit { profile = try await BusinessProAPI.submitProfile() }; await load(); return true } catch { self.error = error.localizedDescription; return false } }
    func saveAI() async { do { aiSettings = try await BusinessProAPI.saveAISettings(aiSettings) } catch { self.error = error.localizedDescription } }
    func addService(_ payload: BusinessServicePayload) async -> Bool { do { services.insert(try await BusinessProAPI.createService(payload), at: 0); return true } catch { self.error = error.localizedDescription; return false } }
    func addBooking(_ payload: BusinessBookingPayload) async -> Bool { do { bookings.append(try await BusinessProAPI.createBooking(payload)); await load(); return true } catch { self.error = error.localizedDescription; return false } }
    func addClient(_ payload: BusinessClientPayload) async -> Bool { do { clients.insert(try await BusinessProAPI.createClient(payload), at: 0); return true } catch { self.error = error.localizedDescription; return false } }
    func addQuickReply(_ payload: BusinessQuickReplyPayload) async -> Bool { do { quickReplies.append(try await BusinessProAPI.createQuickReply(payload)); return true } catch { self.error = error.localizedDescription; return false } }
    func addTeam(_ payload: BusinessTeamPayload) async -> Bool { do { team.append(try await BusinessProAPI.addTeamMember(payload)); return true } catch { self.error = error.localizedDescription; return false } }
    func addDocument(_ payload: BusinessDocumentPayload) async -> Bool { do { documents.insert(try await BusinessProAPI.createDocument(payload), at: 0); return true } catch { self.error = error.localizedDescription; return false } }
    func saveAvailability(_ payload: [BusinessAvailabilityPayload]) async -> Bool { do { availability = try await BusinessProAPI.saveAvailability(payload); return true } catch { self.error = error.localizedDescription; return false } }
    func changeLead(_ lead: BusinessLead, to status: String) async { do { let payload = BusinessLeadUpdatePayload(status: status); let updated = if let workspace { try await BusinessProAPI.updateWorkspaceLead(ownerID: workspace.ownerUserID, id: lead.id, payload: payload) } else { try await BusinessProAPI.updateLead(id: lead.id, payload: payload) }; if let i = leads.firstIndex(where: { $0.id == lead.id }) { leads[i] = updated } } catch { self.error = error.localizedDescription } }
    func changeBooking(_ booking: BusinessBooking, to status: String) async { do { let updated = if let workspace { try await BusinessProAPI.updateWorkspaceBooking(ownerID: workspace.ownerUserID, id: booking.id, status: status) } else { try await BusinessProAPI.updateBooking(id: booking.id, status: status) }; if let i = bookings.firstIndex(where: { $0.id == booking.id }) { bookings[i] = updated } } catch { self.error = error.localizedDescription } }
}

private enum ProTab: String, CaseIterable, Identifiable { case today, leads, calendar, clients, receptionist, more; var id: String { rawValue }; var title: String { switch self { case .today: "Сьогодні"; case .leads: "Заявки"; case .calendar: "Календар"; case .clients: "Клієнти"; case .receptionist: "AI"; case .more: "Ще" } }; var icon: String { switch self { case .today: "sparkles"; case .leads: "rectangle.3.group.bubble.left.fill"; case .calendar: "calendar"; case .clients: "person.2.fill"; case .receptionist: "waveform.and.mic"; case .more: "square.grid.2x2" } } }
private enum ProSheet: String, Identifiable { case profile, service, booking, client, quickReply, team, availability, document; var id: String { rawValue } }
private enum ProLeadStage: String, CaseIterable, Identifiable { case new, replied, qualifying, quoted, booked, completed, lost; var id: String { rawValue }; var title: String { switch self { case .new: "Нова"; case .replied: "Відповіли"; case .qualifying: "Уточнення"; case .quoted: "Пропозиція"; case .booked: "Заброньовано"; case .completed: "Виконано"; case .lost: "Втрачено" } } }
private struct ProStatusPill: View { let status: String; var body: some View { Text(label).font(.caption2.bold()).padding(.horizontal, 9).padding(.vertical, 6).foregroundStyle(color).background(color.opacity(0.13), in: Capsule()) }; private var label: String { switch status { case "new": "НОВА"; case "replied": "ВІДПОВІЛИ"; case "qualifying": "УТОЧНЕННЯ"; case "quoted": "ПРОПОЗИЦІЯ"; case "booked", "confirmed": "ЗАПИС"; case "completed": "ГОТОВО"; case "cancelled": "СКАСОВАНО"; case "no_show": "НЕ ПРИЙШОВ"; default: status.uppercased() } }; private var color: Color { ["new", "requested"].contains(status) ? JourneyVisual.lime : (status == "completed" ? .green : (["cancelled", "lost", "no_show"].contains(status) ? .red : .cyan)) } }
private struct ProDateBadge: View { let date: Date; var body: some View { VStack(spacing: 1) { Text(date.formatted(.dateTime.day())).font(.title2.weight(.black)); Text(date.formatted(.dateTime.month(.abbreviated))).font(.caption2.bold()).textCase(.uppercase) }.foregroundStyle(.black).frame(width: 54, height: 58).background(JourneyVisual.lime).clipShape(RoundedRectangle(cornerRadius: 15)) } }
private struct ProCompactRow: View { let title: String; let subtitle: String; let active: Bool; var body: some View { HStack { Circle().fill(active ? JourneyVisual.lime : .white.opacity(0.2)).frame(width: 7, height: 7); VStack(alignment: .leading, spacing: 2) { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.45)).lineLimit(1) }; Spacer() }.padding(.vertical, 3) } }
private struct ProLimeButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.caption.bold()).foregroundStyle(.black).padding(.horizontal, 14).frame(height: 38).background(JourneyVisual.lime.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule()) } }
private struct ProOutlineButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 14).frame(height: 38).background(.white.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule()) } }
private extension View { func proCard(stroke: Color = .white.opacity(0.08)) -> some View { background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(stroke)) } }
