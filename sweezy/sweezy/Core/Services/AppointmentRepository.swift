import Foundation
import Combine

@MainActor
final class AppointmentRepository: ObservableObject {
    @Published private(set) var appointments: [Appointment] = []

    private let notificationService: any NotificationServiceProtocol
    private let iCloudStore: NSUbiquitousKeyValueStore
    private let fileManager: FileManager
    private let appGroupIdentifier: String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cancellables = Set<AnyCancellable>()
    
    private var localURL: URL {
        Self.makeLocalURL(
            fileManager: fileManager,
            appGroupIdentifier: appGroupIdentifier,
            fileName: AccountScopedStorage.appointmentsFileName()
        )
    }
    
    private var iCloudKey: String {
        AccountScopedStorage.appointmentsICloudKey
    }

    init(
        notificationService: any NotificationServiceProtocol,
        fileManager: FileManager = .default,
        iCloudStore: NSUbiquitousKeyValueStore = .default,
        appGroupIdentifier: String? = nil,
        iCloudKey: String = "sweezy.appointments"
    ) {
        self.notificationService = notificationService
        self.fileManager = fileManager
        self.iCloudStore = iCloudStore
        self.appGroupIdentifier = appGroupIdentifier

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        loadFromLocal()
        syncFromiCloud()
        observeiCloudChanges()
        observeAccountScopeChanges()
    }

    func add(_ appointment: Appointment) {
        var normalized = appointment
        let now = Date()
        normalized.updatedAt = now

        if appointments.contains(where: { $0.id == normalized.id }) {
            update(normalized)
            return
        }

        appointments.append(normalized)
        persistAppointments()
        scheduleNotifications(for: normalized)
    }

    func update(_ appointment: Appointment) {
        var normalized = appointment
        normalized.updatedAt = Date()

        guard let index = appointments.firstIndex(where: { $0.id == normalized.id }) else {
            add(normalized)
            return
        }

        appointments[index] = normalized
        persistAppointments()
        rescheduleNotifications(for: normalized)
    }

    func delete(_ appointment: Appointment) {
        delete(withID: appointment.id)
    }

    func delete(withID id: UUID) {
        guard let index = appointments.firstIndex(where: { $0.id == id }) else { return }

        appointments.remove(at: index)
        persistAppointments()
        notificationService.cancelAppointmentNotifications(for: id)
    }

    private func saveToLocal() {
        do {
            let directoryURL = localURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            let data = try encoder.encode(sortedAppointments(appointments))
            try data.write(to: localURL, options: .atomic)
        } catch {
            AppLogger.error("Failed to save appointments locally: \(error)")
        }
    }

    private func saveToiCloud() {
        do {
            let data = try encoder.encode(sortedAppointments(appointments))
            iCloudStore.set(data, forKey: iCloudKey)
            let didSynchronize = iCloudStore.synchronize()
            if !didSynchronize {
                AppLogger.warning("iCloud sync unavailable, keeping local appointments only")
            }
        } catch {
            AppLogger.error("Failed to mirror appointments to iCloud: \(error)")
        }
    }

    private func loadFromLocal() {
        guard fileManager.fileExists(atPath: localURL.path) else {
            appointments = []
            return
        }

        do {
            let data = try Data(contentsOf: localURL)
            appointments = try decodeAppointments(from: data)
        } catch {
            appointments = []
            AppLogger.error("Failed to load appointments locally: \(error)")
        }
    }

    private func syncFromiCloud() {
        let didSynchronize = iCloudStore.synchronize()
        guard didSynchronize else { return }
        guard let data = iCloudStore.data(forKey: iCloudKey) else { return }

        do {
            let remoteAppointments = try decodeAppointments(from: data)
            let mergedAppointments = merge(local: appointments, remote: remoteAppointments)

            guard mergedAppointments != appointments else { return }

            appointments = mergedAppointments
            saveToLocal()
            saveToiCloud()
        } catch {
            AppLogger.error("Failed to sync appointments from iCloud: \(error)")
        }
    }

    private func observeiCloudChanges() {
        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
        .sink { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.syncFromiCloud()
            }
        }
        .store(in: &cancellables)
    }
    
    private func observeAccountScopeChanges() {
        NotificationCenter.default.publisher(for: .accountScopeDidChange)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.handleAccountScopeChange()
                }
            }
            .store(in: &cancellables)
    }

    private func persistAppointments() {
        appointments = sortedAppointments(appointments)
        saveToLocal()
        saveToiCloud()
    }
    
    private func handleAccountScopeChange() {
        let previousAppointments = appointments
        appointments = []
        previousAppointments.forEach { notificationService.cancelAppointmentNotifications(for: $0.id) }
        loadFromLocal()
        syncFromiCloud()
        appointments.forEach { rescheduleNotifications(for: $0) }
    }

    private func scheduleNotifications(for appointment: Appointment) {
        Task { [notificationService] in
            if notificationService.authorizationStatus == .notDetermined {
                _ = await notificationService.requestPermission()
            }

            _ = await notificationService.scheduleAppointmentReminder(for: appointment)
        }
    }

    private func rescheduleNotifications(for appointment: Appointment) {
        Task { [notificationService] in
            if notificationService.authorizationStatus == .notDetermined {
                _ = await notificationService.requestPermission()
            }

            _ = await notificationService.rescheduleAppointmentNotifications(for: appointment)
        }
    }

    private func merge(local: [Appointment], remote: [Appointment]) -> [Appointment] {
        var mergedByID: [UUID: Appointment] = [:]

        for appointment in local + remote {
            if let existing = mergedByID[appointment.id] {
                mergedByID[appointment.id] = appointment.updatedAt >= existing.updatedAt ? appointment : existing
            } else {
                mergedByID[appointment.id] = appointment
            }
        }

        return sortedAppointments(Array(mergedByID.values))
    }

    private func sortedAppointments(_ appointments: [Appointment]) -> [Appointment] {
        appointments.sorted { lhs, rhs in
            if lhs.dateTime != rhs.dateTime {
                return lhs.dateTime < rhs.dateTime
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func decodeAppointments(from data: Data) throws -> [Appointment] {
        let decoded = try decoder.decode([Appointment].self, from: data)
        return sortedAppointments(decoded)
    }

    private static func makeLocalURL(fileManager: FileManager, appGroupIdentifier: String?, fileName: String) -> URL {
        if let appGroupIdentifier,
           let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL.appendingPathComponent(fileName)
        }

        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return documentsURL.appendingPathComponent(fileName)
    }
}
