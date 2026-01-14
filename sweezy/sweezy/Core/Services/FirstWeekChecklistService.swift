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
    
    private let storageURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        storageURL = dir.appendingPathComponent("first_week_tasks.json")
        load()
        
        $tasks
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.persist() }
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
    
    func generateDefaultTasks(for profile: UserProfile) {
        let start = profile.arrivalDate ?? Date()
        var new: [TaskItem] = []
        
        func add(_ title: String, _ days: Int, _ details: String? = nil) {
            let due = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
            new.append(TaskItem(title: title, details: details, dueDate: due))
        }
        
        add("Реєстрація у громаді", 1, "Зверніться до Gemeinde/Commune за місцем проживання")
        add("Оформити SIM-карту", 1)
        add("Відкрити рахунок у банку", 3)
        add("Медичне страхування", 7)
        if profile.hasChildren { add("Реєстрація дітей до школи", 5) }
        add("Ознайомитись з транспортом", 3)
        if profile.goals.contains(.work) { add("Оновити CV / профіль LinkedIn", 5) }
        if profile.goals.contains(.language) { add("Записатись на мовні курси", 4) }
        
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
    
    func scheduleReminders(using notificationService: any NotificationServiceProtocol) async {
        for idx in tasks.indices {
            // Cancel old
            tasks[idx].notificationIds.forEach { notificationService.cancelNotification(with: $0) }
            tasks[idx].notificationIds.removeAll()
            
            // Schedule: 1 day before and 2 hours before
            let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: tasks[idx].dueDate) ?? tasks[idx].dueDate
            let twoHoursBefore = Calendar.current.date(byAdding: .hour, value: -2, to: tasks[idx].dueDate) ?? tasks[idx].dueDate
            
            let id1 = "fw_\\(tasks[idx].id.uuidString)_d1"
            let id2 = "fw_\\(tasks[idx].id.uuidString)_h2"
            let title = "Наближається дедлайн"
            let body = tasks[idx].title
            _ = await notificationService.scheduleReminder(id: id1, title: title, body: body, at: dayBefore)
            _ = await notificationService.scheduleReminder(id: id2, title: title, body: body, at: twoHoursBefore)
            tasks[idx].notificationIds = [id1, id2]
        }
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        if let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        }
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(tasks) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}


