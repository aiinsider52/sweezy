import SwiftUI

struct BusinessProfileOnboarding: View {
    @ObservedObject var model: BusinessProViewModel
    @State private var showEditor = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 48)
                Text("SWEEZY PRO · PLUS").font(.caption.bold()).tracking(3).foregroundStyle(JourneyVisual.lime)
                Text("Перетвори профіль\nна робочий бізнес").font(.system(size: 39, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("Заявки, клієнти, записи, документи та AI-рецепціоніст — в одному місці.").font(.title3).foregroundStyle(.white.opacity(0.62))
                VStack(spacing: 0) {
                    benefit("person.crop.circle.badge.plus", "Нові клієнти", "Заявки з Marketplace автоматично потрапляють у CRM")
                    benefit("calendar.badge.clock", "Онлайн-запис", "Реальний графік, статуси й нагадування")
                    benefit("sparkles", "AI-рецепціоніст", "Налаштовується під твої послуги та стиль")
                    benefit("chart.line.uptrend.xyaxis", "Зростання", "Конверсія, перегляди й просування")
                }.background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 25)).overlay(RoundedRectangle(cornerRadius: 25).stroke(JourneyVisual.lime.opacity(0.22)))
                Button { showEditor = true } label: { HStack { Text("Створити бізнес-профіль"); Spacer(); Image(systemName: "arrow.right") }.font(.headline).foregroundStyle(.black).padding(.horizontal, 22).frame(height: 60).background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 19)) }.buttonStyle(.plain)
            }.padding(24).padding(.bottom, 40)
        }.sheet(isPresented: $showEditor) { BusinessProfileEditor(model: model, isOnboarding: true) }
    }
    private func benefit(_ icon: String, _ title: String, _ subtitle: String) -> some View { HStack(spacing: 14) { Image(systemName: icon).font(.title3).foregroundStyle(JourneyVisual.lime).frame(width: 42); VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline).foregroundStyle(.white); Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.52)) }; Spacer() }.padding(17) }
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
        ProFormShell(title: isOnboarding ? "Бізнес-профіль" : "Налаштування бізнесу") {
            ProField("Назва", text: $payload.displayName)
            ProField("Юридична назва", text: optional($payload.legalName))
            ProTextArea("Про бізнес", text: $payload.description, hint: "Що ти робиш, для кого і чому тобі можна довіряти")
            HStack { ProField("Місто", text: $payload.city); ProField("Кантон", text: $payload.canton) }
            ProField("Категорія", text: $payload.category)
            ProField("Мови через кому", text: $languages)
            ProField("Кантони роботи через кому", text: $serviceArea)
            ProField("Телефон", text: optional($payload.phone), keyboard: .phonePad)
            ProField("Email", text: optional($payload.email), keyboard: .emailAddress)
            ProField("Website", text: optional($payload.website), keyboard: .URL)
            ProField("UID", text: optional($payload.uidNumber))
            ProTextArea("Правила скасування", text: optional($payload.cancellationPolicy), hint: "Наприклад: безкоштовне скасування за 24 години")
            VStack(alignment: .leading, spacing: 10) {
                Text("Формат роботи").font(.caption.bold()).foregroundStyle(.white.opacity(0.55))
                HStack { mode("У себе", "onsite"); mode("Онлайн", "remote"); mode("З виїздом", "mobile") }
            }
            if model.profile?.status == "rejected", let reason = model.profile?.rejectionReason { Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).padding(14).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14)) }
            Button { save(submit: true) } label: { ProSubmitLabel(title: model.profile?.status == "approved" ? "Зберегти зміни" : "Зберегти й надіслати на перевірку", working: working) }.disabled(!valid || working)
        }
        .onAppear {
            if let profile = model.profile { payload = BusinessProfilePayload(profile: profile); languages = profile.languages.joined(separator: ", "); serviceArea = profile.serviceArea.joined(separator: ", ") }
        }
    }
    private var valid: Bool { payload.displayName.trimmingCharacters(in: .whitespaces).count >= 2 && payload.description.count >= 10 && !payload.city.isEmpty }
    private func mode(_ title: String, _ value: String) -> some View { Button { if payload.deliveryModes.contains(value) { payload.deliveryModes.removeAll { $0 == value } } else { payload.deliveryModes.append(value) } } label: { Text(title).font(.caption.bold()).foregroundStyle(payload.deliveryModes.contains(value) ? .black : .white).padding(.horizontal, 12).frame(height: 40).background(payload.deliveryModes.contains(value) ? JourneyVisual.lime : .white.opacity(0.08), in: Capsule()) }.buttonStyle(.plain) }
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
    var body: some View { ProFormShell(title: "Нова послуга") {
        ProField("Назва", text: $payload.title)
        if !listings.isEmpty {
            Picker("Оголошення Marketplace", selection: $payload.listingID) {
                Text("Без прив’язки").tag(String?.none)
                ForEach(listings.filter { $0.listingType == .service && $0.status == .approved }) { listing in
                    Text(listing.title).tag(Optional(listing.id))
                }
            }
            .tint(JourneyVisual.lime)
            Text("Прив’язка додає клієнтам реальну кнопку запису у картці послуги.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))
        }
        ProTextArea("Опис", text: $payload.description, hint: "Результат, умови й важливі деталі")
        ProField("Категорія", text: $payload.category)
        Stepper("Тривалість: \(payload.durationMinutes) хв", value: $payload.durationMinutes, in: 15...480, step: 15).foregroundStyle(.white)
        ProField("Ціна CHF", text: $price, keyboard: .decimalPad)
        Picker("Формат", selection: $payload.deliveryMode) { Text("У себе").tag("onsite"); Text("Онлайн").tag("remote"); Text("З виїздом").tag("mobile") }.pickerStyle(.segmented)
        Button { working = true; payload.priceCents = Double(price).map { Int($0 * 100) }; Task { if await model.addService(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Додати послугу", working: working) }.disabled(payload.title.count < 2 || working)
    } }
}

struct BusinessBookingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var payload = BusinessBookingPayload()
    @State private var price = ""
    @State private var working = false
    var body: some View { ProFormShell(title: "Новий запис") {
        ProField("Ім’я клієнта", text: $payload.customerName)
        DatePicker("Початок", selection: $payload.startsAt).datePickerStyle(.compact).foregroundStyle(.white)
        DatePicker("Кінець", selection: $payload.endsAt).datePickerStyle(.compact).foregroundStyle(.white)
        ProField("Місце", text: optional($payload.location))
        ProField("Ціна CHF", text: $price, keyboard: .decimalPad)
        ProTextArea("Нотатки", text: $payload.notes, hint: "Що потрібно підготувати")
        Button { working = true; payload.priceCents = Double(price).map { Int($0 * 100) }; Task { if await model.addBooking(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Створити запис", working: working) }.disabled(payload.customerName.isEmpty || payload.endsAt <= payload.startsAt || working)
    } }
    private func optional(_ binding: Binding<String?>) -> Binding<String> { Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }) }
}

struct BusinessClientEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var payload = BusinessClientPayload()
    @State private var working = false
    var body: some View { ProFormShell(title: "Новий клієнт") {
        ProField("Ім’я", text: $payload.displayName)
        ProField("Email", text: optional($payload.email), keyboard: .emailAddress)
        ProField("Телефон", text: optional($payload.phone), keyboard: .phonePad)
        ProField("Мова", text: optional($payload.language))
        ProTextArea("Нотатки", text: $payload.notes, hint: "Побажання, контекст, домовленості")
        Button { working = true; Task { if await model.addClient(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Додати клієнта", working: working) }.disabled(payload.displayName.isEmpty || working)
    } }
    private func optional(_ binding: Binding<String?>) -> Binding<String> { Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }) }
}

struct BusinessQuickReplyEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var payload = BusinessQuickReplyPayload()
    @State private var working = false
    var body: some View { ProFormShell(title: "Швидка відповідь") {
        ProField("Назва", text: $payload.title)
        ProTextArea("Текст", text: $payload.body, hint: "Можна використовувати {client_name}, {service}, {date}, {price}")
        ProField("Мова", text: $payload.language)
        Button { working = true; Task { if await model.addQuickReply(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Зберегти шаблон", working: working) }.disabled(payload.title.isEmpty || payload.body.isEmpty || working)
    } }
}

struct BusinessTeamEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var payload = BusinessTeamPayload()
    @State private var working = false
    var body: some View { ProFormShell(title: "Додати до команди") {
        ProField("Ім’я", text: $payload.displayName)
        ProField("Email", text: $payload.email, keyboard: .emailAddress)
        Picker("Роль", selection: $payload.role) { Text("Менеджер").tag("manager"); Text("Працівник").tag("staff"); Text("Перегляд").tag("viewer") }.pickerStyle(.segmented)
        Text("Учасник отримає статус pending. Повноцінні запрошення активуються після підтвердження email.").font(.caption).foregroundStyle(.white.opacity(0.5))
        Button { working = true; Task { if await model.addTeam(payload) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Додати учасника", working: working) }.disabled(payload.displayName.isEmpty || !payload.email.contains("@") || working)
    } }
}

struct BusinessAvailabilityEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: BusinessProViewModel
    @State private var selected = Set(0...4)
    @State private var start = DateComponents(calendar: .current, hour: 9).date ?? Date()
    @State private var end = DateComponents(calendar: .current, hour: 18).date ?? Date()
    @State private var working = false
    private let names = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Нд"]
    var body: some View { ProFormShell(title: "Графік роботи") {
        Text("Робочі дні").font(.caption.bold()).foregroundStyle(.white.opacity(0.55))
        HStack { ForEach(0..<7) { day in Button { if selected.contains(day) { selected.remove(day) } else { selected.insert(day) } } label: { Text(names[day]).font(.caption.bold()).foregroundStyle(selected.contains(day) ? .black : .white).frame(maxWidth: .infinity).frame(height: 40).background(selected.contains(day) ? JourneyVisual.lime : .white.opacity(0.08), in: Circle()) }.buttonStyle(.plain) } }
        DatePicker("Початок", selection: $start, displayedComponents: .hourAndMinute).foregroundStyle(.white)
        DatePicker("Кінець", selection: $end, displayedComponents: .hourAndMinute).foregroundStyle(.white)
        Button { working = true; let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"; let rows = selected.sorted().map { BusinessAvailabilityPayload(weekday: $0, startTime: formatter.string(from: start), endTime: formatter.string(from: end), isActive: true) }; Task { if await model.saveAvailability(rows) { dismiss() }; working = false } } label: { ProSubmitLabel(title: "Зберегти графік", working: working) }.disabled(selected.isEmpty || end <= start || working)
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
        ProFormShell(title: "Новий документ") {
            Picker("Тип", selection: $payload.documentType) {
                Text("Пропозиція").tag("quote")
                Text("Підтвердження").tag("confirmation")
                Text("Рахунок").tag("invoice")
            }
            .pickerStyle(.segmented)
            ProField("Назва документа", text: $payload.title)
            if !model.clients.isEmpty {
                Picker("Клієнт", selection: $payload.clientID) {
                    Text("Без клієнта").tag(String?.none)
                    ForEach(model.clients) { client in Text(client.displayName).tag(Optional(client.id)) }
                }
                .tint(JourneyVisual.lime)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Позиції").font(.caption.bold()).foregroundStyle(.white.opacity(0.55))
                ForEach(payload.lineItems) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title).foregroundStyle(.white)
                            Text("\(item.quantity) × CHF \(String(format: "%.2f", Double(item.unitPriceCents) / 100))").font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        Button(role: .destructive) { payload.lineItems.removeAll { $0.id == item.id } } label: { Image(systemName: "trash") }
                    }
                    .padding(12)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
                }
                ProField("Послуга або товар", text: $itemTitle)
                HStack {
                    ProField("Ціна CHF", text: $itemPrice, keyboard: .decimalPad)
                    Stepper("×\(itemQuantity)", value: $itemQuantity, in: 1...100)
                        .foregroundStyle(.white)
                }
                Button("Додати позицію") { addLine() }
                    .buttonStyle(.bordered)
                    .tint(JourneyVisual.lime)
                    .disabled(itemTitle.trimmingCharacters(in: .whitespaces).isEmpty || Double(itemPrice) == nil)
            }
            ProTextArea("Нотатки", text: $payload.notes, hint: "Умови, термін дії або платіжні реквізити")
            Button {
                working = true
                Task { if await model.addDocument(payload) { dismiss() }; working = false }
            } label: {
                ProSubmitLabel(title: "Створити документ", working: working)
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
        ZStack { Color.black.ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("Налаштуй AI під себе").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white)
            Toggle("AI-рецепціоніст", isOn: $model.aiSettings.aiEnabled).tint(JourneyVisual.lime).foregroundStyle(.white)
            Toggle("Автоматично відповідати", isOn: $model.aiSettings.aiAutoReply).tint(JourneyVisual.lime).foregroundStyle(.white)
            if model.aiSettings.aiAutoReply { Label("Автовідповіді надсилаються лише для звичайних запитів. Складні теми передаються тобі.", systemImage: "shield.checkered").font(.caption).foregroundStyle(.orange) }
            Picker("Тон", selection: $model.aiSettings.aiTone) { Text("Дружньо-професійний").tag("friendly_professional"); Text("Короткий").tag("concise"); Text("Теплий").tag("warm"); Text("Формальний").tag("formal") }.pickerStyle(.menu).tint(JourneyVisual.lime)
            ProTextArea("Факти про бізнес", text: $model.aiSettings.aiBusinessFacts, hint: "Досвід, район роботи, обладнання, сильні сторони")
            ProTextArea("Особливі інструкції", text: $model.aiSettings.aiInstructions, hint: "Які питання ставити, що пропонувати, чого не обіцяти")
            ProTextArea("Привітання", text: optional($model.aiSettings.aiGreeting), hint: "Перше повідомлення клієнту")
            ProField("Мови через кому", text: $languages)
            ProField("Передавати людині теми", text: $handoff)
            faqEditor
            Button { model.aiSettings.aiAllowedLanguages = split(languages); model.aiSettings.aiHandoffTopics = split(handoff); Task { await model.saveAI(); saved = true } } label: { ProSubmitLabel(title: saved ? "Збережено" : "Зберегти налаштування", working: false) }
        }.padding(20).padding(.bottom, 40) } }.navigationTitle("AI-рецепціоніст").navigationBarTitleDisplayMode(.inline).onAppear { languages = model.aiSettings.aiAllowedLanguages.joined(separator: ", "); handoff = model.aiSettings.aiHandoffTopics.joined(separator: ", ") }
    }

    private var faqEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("База знань FAQ").font(.headline).foregroundStyle(.white)
                    Text("AI використовує лише перевірені тобою відповіді.").font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text("\(model.aiSettings.aiFAQ.count)").font(.caption.bold()).foregroundStyle(.black).padding(.horizontal, 9).padding(.vertical, 5).background(JourneyVisual.lime, in: Capsule())
            }

            ForEach(Array(model.aiSettings.aiFAQ.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top) {
                        Text(item["question"] ?? "Питання").font(.subheadline.bold()).foregroundStyle(.white)
                        Spacer()
                        Button(role: .destructive) { model.aiSettings.aiFAQ.remove(at: index); saved = false } label: {
                            Image(systemName: "trash").foregroundStyle(.red.opacity(0.85))
                        }
                    }
                    Text(item["answer"] ?? "").font(.caption).foregroundStyle(.white.opacity(0.58)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
            }

            ProField("Питання клієнта", text: $faqQuestion)
            ProTextArea("Точна відповідь", text: $faqAnswer, hint: "Відповідь, яку AI може безпечно використати")
            Button {
                let question = faqQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                let answer = faqAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !question.isEmpty, !answer.isEmpty else { return }
                model.aiSettings.aiFAQ.append(["question": question, "answer": answer])
                faqQuestion = ""
                faqAnswer = ""
                saved = false
            } label: {
                Label("Додати до бази знань", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold()).foregroundStyle(JourneyVisual.lime)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(JourneyVisual.lime.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .disabled(faqQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || faqAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 22))
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
    var body: some View { ZStack { Color.black.ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 18) {
        Text("Тестова розмова").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white)
        ProTextArea("Повідомлення клієнта", text: $question, hint: "Наприклад: Guten Tag, haben Sie am Freitag Zeit?")
        Button { working = true; Task { do { draft = try await BusinessProAPI.draftReply(.init(conversationID: nil, customerName: "Тестовий клієнт", customerLanguage: nil, messages: [.init(role: "customer", content: question)])) } catch { model.error = error.localizedDescription }; working = false } } label: { ProSubmitLabel(title: "Створити відповідь", working: working) }.disabled(question.count < 2 || working)
        if let draft { VStack(alignment: .leading, spacing: 12) { HStack { Label(draft.generatedByAI ? "AI-відповідь" : "Безпечний шаблон", systemImage: "sparkles").foregroundStyle(JourneyVisual.lime); Spacer(); if draft.shouldHandoff { Text("ПЕРЕДАТИ ЛЮДИНІ").font(.caption2.bold()).foregroundStyle(.orange) } }; Text(draft.reply).foregroundStyle(.white).textSelection(.enabled); Divider().overlay(.white.opacity(0.1)); Text(draft.leadSummary).font(.caption).foregroundStyle(.white.opacity(0.55)); if !draft.missingInformation.isEmpty { Text("Уточнити: \(draft.missingInformation.joined(separator: ", "))").font(.caption).foregroundStyle(.cyan) } }.padding(18).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(JourneyVisual.lime.opacity(0.3))) }
    }.padding(20) } }.navigationTitle("Тест AI").navigationBarTitleDisplayMode(.inline) }
}

struct ProFormShell<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View { NavigationStack { ZStack { Color.black.ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 17) { content }.padding(20).padding(.bottom, 35) } }.navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } } } } }
}

struct ProField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    init(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) { self.title = title; _text = text; self.keyboard = keyboard }
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(title).font(.caption.bold()).foregroundStyle(.white.opacity(0.55)); TextField(title, text: $text).keyboardType(keyboard).textInputAutocapitalization(keyboard == .emailAddress || keyboard == .URL ? .never : .sentences).foregroundStyle(.white).padding(14).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08))) } }
}

struct ProTextArea: View {
    let title: String
    @Binding var text: String
    let hint: String
    init(_ title: String, text: Binding<String>, hint: String) { self.title = title; _text = text; self.hint = hint }
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(title).font(.caption.bold()).foregroundStyle(.white.opacity(0.55)); TextField(hint, text: $text, axis: .vertical).lineLimit(3...7).foregroundStyle(.white).padding(14).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08))) } }
}

struct ProSubmitLabel: View { let title: String; let working: Bool; var body: some View { HStack { if working { ProgressView().tint(.black) }; Text(title); Spacer(); Image(systemName: "arrow.right") }.font(.headline).foregroundStyle(.black).padding(.horizontal, 20).frame(maxWidth: .infinity).frame(height: 58).background(JourneyVisual.lime, in: RoundedRectangle(cornerRadius: 18)) } }
