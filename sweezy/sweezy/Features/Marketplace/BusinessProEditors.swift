import SwiftUI

struct BusinessProfileOnboarding: View {
    @ObservedObject var model: BusinessProViewModel
    @State private var showEditor = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 48)
                Text("SWEEZY PRO · PLUS").font(.caption.bold()).tracking(3).foregroundStyle(Theme.Colors.textPrimary)
                Text("Перетвори профіль\nна робочий бізнес".localized).font(.system(size: 30, weight: .black, design: .default)).foregroundStyle(JourneyVisual.primaryText)
                Text("Заявки, клієнти, записи, документи та AI-рецепціоніст — в одному місці.".localized).font(.title3).foregroundStyle(JourneyVisual.secondaryText)
                VStack(spacing: 0) {
                    benefit("person.crop.circle.badge.plus", "Нові клієнти".localized, "Заявки з Marketplace автоматично потрапляють у CRM".localized)
                    benefit("calendar.badge.clock", "Онлайн-запис".localized, "Реальний графік, статуси й нагадування".localized)
                    benefit("sparkles", "AI-рецепціоніст".localized, "Налаштовується під твої послуги та стиль".localized)
                    benefit("chart.line.uptrend.xyaxis", "Зростання".localized, "Конверсія, перегляди й просування".localized)
                }.background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 25)).overlay(RoundedRectangle(cornerRadius: 25).stroke(JourneyVisual.lime.opacity(0.22)))
                Button { showEditor = true } label: { HStack { Text("Створити бізнес-профіль".localized); Spacer(); Image(systemName: "arrow.right") }.font(.headline).foregroundStyle(.black).padding(.horizontal, 22).frame(height: 60).background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 19)) }.buttonStyle(.plain)
            }.padding(24).padding(.bottom, 40)
        }.sheet(isPresented: $showEditor) { BusinessProfileEditor(model: model, isOnboarding: true) }
    }
    private func benefit(_ icon: String, _ title: String, _ subtitle: String) -> some View { HStack(spacing: 14) { Image(systemName: icon).font(.title3).foregroundStyle(Theme.Colors.textPrimary).frame(width: 42); VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(JourneyVisual.primaryText); Text(subtitle).font(.caption).foregroundStyle(JourneyVisual.secondaryText) }; Spacer() }.padding(17) }
}

struct BusinessProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    var isOnboarding = false
    @State private var payload = BusinessProfilePayload()
    @State private var languages = "de, uk"
    @State private var serviceArea = "ZH"
    @State private var working = false

    var body: some View {
        ProFormShell(title: isOnboarding ? "Бізнес-профіль".localized : "Налаштування бізнесу".localized) {
            ProField("Назва".localized, text: $payload.displayName)
            ProField("Юридична назва".localized, text: optional($payload.legalName))
            ProTextArea("Про бізнес".localized, text: $payload.description, hint: "Що ти робиш, для кого і чому тобі можна довіряти".localized)
            HStack { ProField("Місто".localized, text: $payload.city); ProField("Кантон".localized, text: $payload.canton) }
            ProField("Категорія".localized, text: $payload.category)
            ProField("Мови через кому".localized, text: $languages)
            ProField("Кантони роботи через кому".localized, text: $serviceArea)
            ProField("Телефон".localized, text: optional($payload.phone), keyboard: .phonePad)
            ProField("Email", text: optional($payload.email), keyboard: .emailAddress)
            ProField("Website", text: optional($payload.website), keyboard: .URL)
            ProField("UID", text: optional($payload.uidNumber))
            ProTextArea("Правила скасування".localized, text: optional($payload.cancellationPolicy), hint: "Наприклад: безкоштовне скасування за 24 години".localized)
            VStack(alignment: .leading, spacing: 10) {
                Text("Формат роботи".localized).font(.caption.bold()).foregroundStyle(JourneyVisual.secondaryText)
                HStack { mode("У себе".localized, "onsite"); mode("Онлайн".localized, "remote"); mode("З виїздом".localized, "mobile") }
            }
            if model.profile?.status == "rejected", let reason = model.profile?.rejectionReason { Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).padding(14).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14)) }
            Button { save(submit: true) } label: { ProSubmitLabel(title: model.profile?.status == "approved" ? "Зберегти зміни".localized : "Зберегти й надіслати на перевірку".localized, working: working) }.disabled(!valid || working)
        }
        .onAppear {
            if let profile = model.profile { payload = BusinessProfilePayload(profile: profile); languages = profile.languages.joined(separator: ", "); serviceArea = profile.serviceArea.joined(separator: ", ") }
        }
    }
    private var valid: Bool { payload.displayName.trimmingCharacters(in: .whitespaces).count >= 2 && payload.description.count >= 10 && !payload.city.isEmpty }
    private func mode(_ title: String, _ value: String) -> some View { Button { if payload.deliveryModes.contains(value) { payload.deliveryModes.removeAll { $0 == value } } else { payload.deliveryModes.append(value) } } label: { Text(title).font(.caption.bold()).foregroundStyle(payload.deliveryModes.contains(value) ? .black : JourneyVisual.primaryText).padding(.horizontal, 12).frame(height: 40).background(payload.deliveryModes.contains(value) ? JourneyVisual.lime : JourneyVisual.softSurface, in: Capsule()) }.buttonStyle(.plain) }
    private func save(submit: Bool) { working = true; payload.languages = split(languages); payload.serviceArea = split(serviceArea); Task { if await model.saveProfile(payload, submit: submit) { dismiss() }; working = false } }
    private func split(_ value: String) -> [String] { value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
    private func optional(_ binding: Binding<String?>) -> Binding<String> { Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }) }
}

struct BusinessServiceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    let listings: [ServiceListing]
    @State private var payload = BusinessServicePayload()
    @State private var price = ""
    @State private var working = false
    var body: some View { ProFormShell(title: "Нова послуга".localized) {
        ProField("Назва".localized, text: $payload.title)
        if !listings.isEmpty {
            Picker("Оголошення Marketplace".localized, selection: $payload.listingID) {
                Text("Без прив’язки".localized).tag(String?.none)
                ForEach(listings.filter { $0.listingType == .service && $0.status == .approved }) { listing in
                    Text(listing.title).tag(Optional(listing.id))
                }
            }
            .tint(JourneyVisual.accentText)
            Text("Прив’язка додає клієнтам реальну кнопку запису у картці послуги.".localized)
                .font(.caption)
                .foregroundStyle(JourneyVisual.secondaryText)
        }
        ProTextArea("Опис".localized, text: $payload.description, hint: "Результат, умови й важливі деталі".localized)
        ProField("Категорія".localized, text: $payload.category)
        Stepper("Тривалість: %@ хв".localized(with: "\(payload.durationMinutes)"), value: $payload.durationMinutes, in: 15...480, step: 15).foregroundStyle(JourneyVisual.primaryText)
        ProField("Ціна CHF".localized, text: $price, keyboard: .decimalPad)
        Picker("Формат".localized, selection: $payload.deliveryMode) { Text("У себе".localized).tag("onsite"); Text("Онлайн".localized).tag("remote"); Text("З виїздом".localized).tag("mobile") }.pickerStyle(.segmented)
        Button { working = true; payload.priceCents = Double(price).map { Int($0 * 100) }; Task { if await model.addService(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Додати послугу".localized, working: working) }.disabled(payload.title.count < 2 || working)
    } }
}

struct BusinessBookingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var payload = BusinessBookingPayload()
    @State private var price = ""
    @State private var working = false
    var body: some View { ProFormShell(title: "Новий запис".localized) {
        ProField("Ім’я клієнта".localized, text: $payload.customerName)
        DatePicker("Початок".localized, selection: $payload.startsAt).datePickerStyle(.compact).foregroundStyle(JourneyVisual.primaryText)
        DatePicker("Кінець".localized, selection: $payload.endsAt).datePickerStyle(.compact).foregroundStyle(JourneyVisual.primaryText)
        ProField("Місце".localized, text: optional($payload.location))
        ProField("Ціна CHF".localized, text: $price, keyboard: .decimalPad)
        ProTextArea("Нотатки".localized, text: $payload.notes, hint: "Що потрібно підготувати".localized)
        Button { working = true; payload.priceCents = Double(price).map { Int($0 * 100) }; Task { if await model.addBooking(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Створити запис".localized, working: working) }.disabled(payload.customerName.isEmpty || payload.endsAt <= payload.startsAt || working)
    } }
    private func optional(_ binding: Binding<String?>) -> Binding<String> { Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }) }
}

struct BusinessClientEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var payload = BusinessClientPayload()
    @State private var working = false
    var body: some View { ProFormShell(title: "Новий клієнт".localized) {
        ProField("Ім’я".localized, text: $payload.displayName)
        ProField("Email", text: optional($payload.email), keyboard: .emailAddress)
        ProField("Телефон".localized, text: optional($payload.phone), keyboard: .phonePad)
        ProField("Мова".localized, text: optional($payload.language))
        ProTextArea("Нотатки".localized, text: $payload.notes, hint: "Побажання, контекст, домовленості".localized)
        Button { working = true; Task { if await model.addClient(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Додати клієнта".localized, working: working) }.disabled(payload.displayName.isEmpty || working)
    } }
    private func optional(_ binding: Binding<String?>) -> Binding<String> { Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }) }
}

struct BusinessQuickReplyEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var payload = BusinessQuickReplyPayload()
    @State private var working = false
    var body: some View { ProFormShell(title: "Швидка відповідь".localized) {
        ProField("Назва".localized, text: $payload.title)
        ProTextArea("Текст".localized, text: $payload.body, hint: "Можна використовувати {client_name}, {service}, {date}, {price}".localized)
        ProField("Мова".localized, text: $payload.language)
        Button { working = true; Task { if await model.addQuickReply(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Зберегти шаблон".localized, working: working) }.disabled(payload.title.isEmpty || payload.body.isEmpty || working)
    } }
}

struct BusinessTeamEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var payload = BusinessTeamPayload()
    @State private var working = false
    var body: some View { ProFormShell(title: "Додати до команди".localized) {
        ProField("Ім’я".localized, text: $payload.displayName)
        ProField("Email", text: $payload.email, keyboard: .emailAddress)
        Picker("Роль".localized, selection: $payload.role) { Text("Менеджер".localized).tag("manager"); Text("Працівник".localized).tag("staff"); Text("Перегляд".localized).tag("viewer") }.pickerStyle(.segmented)
        Text("Учасник отримає статус pending. Повноцінні запрошення активуються після підтвердження email.".localized).font(.caption).foregroundStyle(JourneyVisual.secondaryText)
        Button { working = true; Task { if await model.addTeam(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Додати учасника".localized, working: working) }.disabled(payload.displayName.isEmpty || !payload.email.contains("@") || working)
    } }
}

struct BusinessAvailabilityEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var selected = Set(0...4)
    @State private var start = DateComponents(calendar: .current, hour: 9).date ?? Date()
    @State private var end = DateComponents(calendar: .current, hour: 18).date ?? Date()
    @State private var working = false
    private let names = ["Пн".localized, "Вт".localized, "Ср".localized, "Чт".localized, "Пт".localized, "Сб".localized, "Нд".localized]
    var body: some View { ProFormShell(title: "Графік роботи".localized) {
        Text("Робочі дні".localized).font(.caption.bold()).foregroundStyle(JourneyVisual.secondaryText)
        HStack { ForEach(0..<7) { day in Button { if selected.contains(day) { selected.remove(day) } else { selected.insert(day) } } label: { Text(names[day]).font(.caption.bold()).foregroundStyle(selected.contains(day) ? .black : JourneyVisual.primaryText).frame(maxWidth: .infinity).frame(height: 40).background(selected.contains(day) ? JourneyVisual.lime : JourneyVisual.softSurface, in: Circle()) }.buttonStyle(.plain) } }
        DatePicker("Початок".localized, selection: $start, displayedComponents: .hourAndMinute).foregroundStyle(JourneyVisual.primaryText)
        DatePicker("Кінець".localized, selection: $end, displayedComponents: .hourAndMinute).foregroundStyle(JourneyVisual.primaryText)
        Button { working = true; let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"; let rows = selected.sorted().map { BusinessAvailabilityPayload(weekday: $0, startTime: formatter.string(from: start), endTime: formatter.string(from: end), isActive: true) }; Task { if await model.saveAvailability(rows) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Зберегти графік".localized, working: working) }.disabled(selected.isEmpty || end <= start || working)
    }.onAppear { if !model.availability.isEmpty { selected = Set(model.availability.map(\.weekday)) } } }
}

struct BusinessDocumentEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var payload = BusinessDocumentPayload()
    @State private var itemTitle = ""
    @State private var itemPrice = ""
    @State private var itemQuantity = 1
    @State private var working = false

    var body: some View {
        ProFormShell(title: "Новий документ".localized) {
            Picker("Тип".localized, selection: $payload.documentType) {
                Text("Пропозиція".localized).tag("quote")
                Text("Підтвердження".localized).tag("confirmation")
                Text("Рахунок".localized).tag("invoice")
            }
            .pickerStyle(.segmented)
            ProField("Назва документа".localized, text: $payload.title)
            if !model.clients.isEmpty {
                Picker("Клієнт".localized, selection: $payload.clientID) {
                    Text("Без клієнта".localized).tag(String?.none)
                    ForEach(model.clients) { client in Text(client.displayName).tag(Optional(client.id)) }
                }
                .tint(JourneyVisual.accentText)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Позиції".localized).font(.caption.bold()).foregroundStyle(JourneyVisual.secondaryText)
                ForEach(payload.lineItems) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title).foregroundStyle(JourneyVisual.primaryText)
                            Text("\(item.quantity) × CHF \(String(format: "%.2f", Double(item.unitPriceCents) / 100))").font(.caption).foregroundStyle(JourneyVisual.secondaryText)
                        }
                        Spacer()
                        Button(role: .destructive) { payload.lineItems.removeAll { $0.id == item.id } } label: { Image(systemName: "trash") }
                    }
                    .padding(12)
                    .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 13))
                }
                ProField("Послуга або товар".localized, text: $itemTitle)
                HStack {
                    ProField("Ціна CHF".localized, text: $itemPrice, keyboard: .decimalPad)
                    Stepper("×\(itemQuantity)", value: $itemQuantity, in: 1...100)
                        .foregroundStyle(JourneyVisual.primaryText)
                }
                Button("Додати позицію".localized) { addLine() }
                    .buttonStyle(.bordered)
                    .tint(JourneyVisual.accentText)
                    .disabled(itemTitle.trimmingCharacters(in: .whitespaces).isEmpty || Double(itemPrice) == nil)
            }
            ProTextArea("Нотатки".localized, text: $payload.notes, hint: "Умови, термін дії або платіжні реквізити".localized)
            Button {
                working = true
                Task { if await model.addDocument(payload) { dismiss() }; working = false }
            } label: {
                ProSubmitLabel(title: "Створити документ".localized, working: working)
            }
            .disabled(payload.title.count < 2 || payload.lineItems.isEmpty || working)
        }
    }

    private func addLine() {
        guard let value = Double(itemPrice), value >= 0 else { return }
        payload.lineItems.append(.init(
            title: itemTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: itemQuantity,
            unitPriceCents: Int((value * 100).rounded())
        ))
        itemTitle = ""
        itemPrice = ""
        itemQuantity = 1
    }
}

struct AIReceptionistSettingsView: View {
    @ObservedObject var model: BusinessProViewModel
    @State private var languages = ""
    @State private var handoff = ""
    @State private var faqQuestion = ""
    @State private var faqAnswer = ""
    @State private var saved = false
    var body: some View {
        ZStack { JourneyVisual.pageBackground.ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("Налаштуй AI під себе".localized).font(.system(size: 32, weight: .black, design: .default)).foregroundStyle(JourneyVisual.primaryText)
            Toggle("AI-рецепціоніст".localized, isOn: $model.aiSettings.aiEnabled).tint(JourneyVisual.lime).foregroundStyle(JourneyVisual.primaryText)
            Toggle("Автоматично відповідати".localized, isOn: $model.aiSettings.aiAutoReply).tint(JourneyVisual.lime).foregroundStyle(JourneyVisual.primaryText)
            if model.aiSettings.aiAutoReply { Label("Автовідповіді надсилаються лише для звичайних запитів. Складні теми передаються тобі.".localized, systemImage: "shield.checkered").font(.caption).foregroundStyle(.orange) }
            Picker("Тон".localized, selection: $model.aiSettings.aiTone) { Text("Дружньо-професійний".localized).tag("friendly_professional"); Text("Короткий".localized).tag("concise"); Text("Теплий".localized).tag("warm"); Text("Формальний".localized).tag("formal") }.pickerStyle(.menu).tint(JourneyVisual.lime)
            ProTextArea("Факти про бізнес".localized, text: $model.aiSettings.aiBusinessFacts, hint: "Досвід, район роботи, обладнання, сильні сторони".localized)
            ProTextArea("Особливі інструкції".localized, text: $model.aiSettings.aiInstructions, hint: "Які питання ставити, що пропонувати, чого не обіцяти".localized)
            ProTextArea("Привітання".localized, text: optional($model.aiSettings.aiGreeting), hint: "Перше повідомлення клієнту".localized)
            ProField("Мови через кому".localized, text: $languages)
            ProField("Передавати людині теми".localized, text: $handoff)
            faqEditor
            Button { model.aiSettings.aiAllowedLanguages = split(languages); model.aiSettings.aiHandoffTopics = split(handoff); Task { await model.saveAI(); saved = true } } label: { ProSubmitLabel(title: saved ? "Збережено".localized : "Зберегти налаштування".localized, working: false) }
        }.padding(20).padding(.bottom, 40) } }.navigationTitle("AI-рецепціоніст".localized).navigationBarTitleDisplayMode(.inline).onAppear { languages = model.aiSettings.aiAllowedLanguages.joined(separator: ", "); handoff = model.aiSettings.aiHandoffTopics.joined(separator: ", ") }
    }

    private var faqEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("База знань FAQ".localized).font(.headline).foregroundStyle(JourneyVisual.primaryText)
                    Text("AI використовує лише перевірені тобою відповіді.".localized).font(.caption).foregroundStyle(JourneyVisual.secondaryText)
                }
                Spacer()
                Text("\(model.aiSettings.aiFAQ.count)").font(.caption.bold()).foregroundStyle(.black).padding(.horizontal, 9).padding(.vertical, 5).background(JourneyVisual.lime, in: Capsule())
            }

            ForEach(Array(model.aiSettings.aiFAQ.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top) {
                        Text(item["question"] ?? "Питання".localized).font(.subheadline.bold()).foregroundStyle(JourneyVisual.primaryText)
                        Spacer()
                        Button(role: .destructive) { model.aiSettings.aiFAQ.remove(at: index); saved = false } label: {
                            Image(systemName: "trash").foregroundStyle(.red.opacity(0.85))
                        }
                    }
                    Text(item["answer"] ?? "").font(.caption).foregroundStyle(JourneyVisual.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 16))
            }

            ProField("Питання клієнта".localized, text: $faqQuestion)
            ProTextArea("Точна відповідь".localized, text: $faqAnswer, hint: "Відповідь, яку AI може безпечно використати".localized)
            Button {
                let question = faqQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                let answer = faqAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !question.isEmpty, !answer.isEmpty else { return }
                model.aiSettings.aiFAQ.append(["question": question, "answer": answer])
                faqQuestion = ""
                faqAnswer = ""
                saved = false
            } label: {
                Label("Додати до бази знань".localized, systemImage: "plus.circle.fill")
                    .font(.subheadline.bold()).foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(JourneyVisual.lime.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .disabled(faqQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || faqAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(JourneyVisual.lime.opacity(0.2)))
    }
    private func split(_ value: String) -> [String] { value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
    private func optional(_ binding: Binding<String?>) -> Binding<String> { Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }) }
}

struct AIReceptionistTestView: View {
    @ObservedObject var model: BusinessProViewModel
    @State private var question = ""
    @State private var draft: AIReceptionistDraft?
    @State private var working = false
    var body: some View { ZStack { JourneyVisual.pageBackground.ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 18) {
        Text("Тестова розмова".localized).font(.system(size: 32, weight: .black, design: .default)).foregroundStyle(JourneyVisual.primaryText)
        ProTextArea("Повідомлення клієнта".localized, text: $question, hint: "Наприклад: Guten Tag, haben Sie am Freitag Zeit?".localized)
        Button { working = true; Task { do { draft = try await BusinessProAPI.draftReply(.init(conversationID: nil, customerName: "Тестовий клієнт".localized, customerLanguage: nil, messages: [.init(role: "customer", content: question)])) } catch { model.error = error.localizedDescription }; working = false } } label: { ProSubmitLabel(title: "Створити відповідь".localized, working: working) }.disabled(question.count < 2 || working)
        if let draft { VStack(alignment: .leading, spacing: 12) { HStack { Label(draft.generatedByAI ? "AI-відповідь".localized : "Безпечний шаблон".localized, systemImage: "sparkles").foregroundStyle(Theme.Colors.textPrimary); Spacer(); if draft.shouldHandoff { Text("ПЕРЕДАТИ ЛЮДИНІ".localized).font(.caption2.bold()).foregroundStyle(.orange) } }; Text(draft.reply).foregroundStyle(JourneyVisual.primaryText).textSelection(.enabled); Divider().overlay(JourneyVisual.softBorder); Text(draft.leadSummary).font(.caption).foregroundStyle(JourneyVisual.secondaryText); if !draft.missingInformation.isEmpty { Text("Уточнити: \(draft.missingInformation.joined(separator: ", "))").font(.caption).foregroundStyle(.cyan) } }.padding(18).background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(JourneyVisual.lime.opacity(0.3))) }
    }.padding(20) } }.navigationTitle("Тест AI".localized).navigationBarTitleDisplayMode(.inline) }
}

struct ProFormShell<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View { NavigationStack { ZStack { JourneyVisual.pageBackground.ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 17) { content }.padding(20).padding(.bottom, 35) } }.navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити".localized) { dismiss() } } } } }
}

struct ProField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    init(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) { self.title = title; _text = text; self.keyboard = keyboard }
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(title).font(.caption.bold()).foregroundStyle(JourneyVisual.secondaryText); TextField(title, text: $text).keyboardType(keyboard).textInputAutocapitalization(keyboard == .emailAddress || keyboard == .URL ? .never : .sentences).foregroundStyle(JourneyVisual.primaryText).padding(14).background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(JourneyVisual.softBorder)) } }
}

struct ProTextArea: View {
    let title: String
    @Binding var text: String
    let hint: String
    init(_ title: String, text: Binding<String>, hint: String) { self.title = title; _text = text; self.hint = hint }
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(title).font(.caption.bold()).foregroundStyle(JourneyVisual.secondaryText); TextField(hint, text: $text, axis: .vertical).lineLimit(3...7).foregroundStyle(JourneyVisual.primaryText).padding(14).background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(JourneyVisual.softBorder)) } }
}

struct ProSubmitLabel: View { let title: String; let working: Bool; var body: some View { HStack { if working { ProgressView().tint(.black) }; Text(title); Spacer(); Image(systemName: "arrow.right") }.font(.headline).foregroundStyle(.black).padding(.horizontal, 20).frame(maxWidth: .infinity).frame(height: 58).background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 18)) } }
