//
//  FirstWeekChecklistService.swift
//  sweezy
//
//  Manages “first 7 days” onboarding checklist with deadlines and reminders.
//

import Foundation
import Combine

@MainActor
final class FirstWeekChecklistService: ObservableObject {
    struct TaskItem: Identifiable, Codable, Equatable {
        let id: UUID
        var title: String
        var details: String?
        var dueDate: Date
        var isDone: Bool
        var notificationIds: [String]
        
        init(id: UUID = UUID(), title: String, details: String? = nil, dueDate: Date, isDone: Bool = false, notificationIds: [String] = []) {
            self.id = id
            self.title = title
            self.details = details
            self.dueDate = dueDate
            self.isDone = isDone
            self.notificationIds = notificationIds
        }
    }
    
    @Published private(set) var tasks: [TaskItem] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    private var storageURL: URL {
        AccountScopedStorage.firstWeekTasksURL()
    }
    
    init() {
        load()
        
        $tasks
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.persist() }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .accountScopeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)
    }
    
    var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        let done = tasks.filter { $0.isDone }.count
        return Double(done) / Double(tasks.count)
    }
    
    var nextDueTask: TaskItem? {
        tasks.filter { !$0.isDone }
            .sorted { $0.dueDate < $1.dueDate }
            .first
    }
    
    func generateTasks(for profile: UserProfile) {
        generateDefaultTasks(for: profile)
    }
    
    func generateDefaultTasks(for profile: UserProfile) {
        let start = profile.arrivalDate ?? Date()
        var new: [TaskItem] = []
        
        func add(_ title: String, _ days: Int, _ details: String? = nil) {
            let due = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
            new.append(TaskItem(title: title, details: details, dueDate: due))
        }
        
        switch profile.country {
        case .switzerland:
            add("Реєстрація у громаді".localized, 1, "Зверніться до Gemeinde/Commune за місцем проживання".localized)
            add("Перевірити обов’язок медичного страхування".localized, 7, "Зазвичай базове страхування потрібно оформити протягом 3 місяців після поселення; перевірте винятки у кантоні.".localized)
        case .germany:
            add("Записатися на Anmeldung".localized, 1, "Знайдіть Bürgeramt/Meldebehörde за адресою житла".localized)
            add("Звернутися до Ausländerbehörde".localized, 3, "Перевірте статус за §24 AufenthG і право на роботу".localized)
            add("Уточнити медичне страхування".localized, 5, "Зверніться до Krankenkasse, Jobcenter або Sozialamt за вашою ситуацією".localized)
        case .austria:
            add("Подати Meldezettel".localized, 3, "Загальний строк — три дні після заселення; потрібен підпис Unterkunftgeber".localized)
            add("Зареєструвати тимчасовий захист".localized, 3, "Meldezettel і реєстрація переміщеної особи — окремі процедури".localized)
            add("Уточнити Grundversorgung і страхування".localized, 5, "Зверніться до компетентного органу федеральної землі".localized)
        }
        add("Оформити SIM-карту".localized, 1)
        add("Відкрити рахунок у банку".localized, 3)
        if profile.hasChildren { add("Реєстрація дітей до школи".localized, 5) }
        add("Ознайомитись з місцевим транспортом".localized, 3)
        if profile.goals.contains(.work) { add("Оновити CV / профіль LinkedIn".localized, 5) }
        if profile.goals.contains(.language) { add("Записатись на мовні курси".localized, 4) }
        
        tasks = new
    }
    
    func toggle(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let willBeDone = !tasks[idx].isDone
        tasks[idx].isDone = willBeDone
        if willBeDone {
            EventBus.shared.emit(GamEvent(type: .checklistStepCompleted, metadata: ["entityId": id.uuidString]))
        }
        // If finished all tasks → checklist.completed
        let doneCount = tasks.filter { $0.isDone }.count
        if !tasks.isEmpty && doneCount == tasks.count {
            EventBus.shared.emit(GamEvent(type: .checklistCompleted, metadata: ["entityId": "first_week"]))
        }
    }
    
    func scheduleReminders(using notificationService: any NotificationServiceProtocol) async -> Bool {
        var scheduledAny = false
        for idx in tasks.indices {
            // Cancel old
            tasks[idx].notificationIds.forEach { notificationService.cancelNotification(with: $0) }
            tasks[idx].notificationIds.removeAll()
            
            // Schedule: 1 day before and 2 hours before
            let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: tasks[idx].dueDate) ?? tasks[idx].dueDate
            let twoHoursBefore = Calendar.current.date(byAdding: .hour, value: -2, to: tasks[idx].dueDate) ?? tasks[idx].dueDate
            
            let id1 = "fw_\\(tasks[idx].id.uuidString)_d1"
            let id2 = "fw_\\(tasks[idx].id.uuidString)_h2"
            let title = "Наближається дедлайн".localized
            let body = tasks[idx].title
            let scheduledDayBefore = await notificationService.scheduleReminder(id: id1, title: title, body: body, at: dayBefore)
            let scheduledTwoHoursBefore = await notificationService.scheduleReminder(id: id2, title: title, body: body, at: twoHoursBefore)
            scheduledAny = scheduledAny || scheduledDayBefore || scheduledTwoHoursBefore
            tasks[idx].notificationIds = [id1, id2]
        }
        return scheduledAny
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else {
            tasks = []
            return
        }
        if let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        } else {
            tasks = []
        }
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(tasks) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}

