import EventKit
import Foundation

enum ReminderAuthorizationState: Equatable {
    case unknown
    case requesting
    case granted
    case denied
    case restricted

    var isGranted: Bool {
        self == .granted
    }
}

@MainActor
final class RemindersStore: ObservableObject {
    @Published private(set) var authorizationState: ReminderAuthorizationState = .unknown
    @Published private(set) var reminders: [ReminderSnapshot] = []
    @Published private(set) var writableCalendars: [ReminderListOption] = []
    @Published var selectedCalendarIdentifier: String = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let eventStore = EKEventStore()
    private var reminderCache: [String: EKReminder] = [:]
    private var changeObserver: NSObjectProtocol?

    var currentReminder: ReminderSnapshot? {
        reminders.first
    }

    var queuedReminders: [ReminderSnapshot] {
        Array(reminders.dropFirst().prefix(6))
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func start() async {
        observeEventStoreChangesIfNeeded()
        await refreshAuthorizationAndLoad(forceRequest: true)
    }

    func requestAccess() async {
        await refreshAuthorizationAndLoad(forceRequest: true)
    }

    func refresh() async {
        let state = currentAuthorizationState()
        authorizationState = state

        guard state.isGranted else {
            reminders = []
            reminderCache = [:]
            return
        }

        await reloadData(resetStore: true)
    }

    func addReminder(title: String, notes: String, dueDate: Date?, calendarIdentifier: String?) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "提醒事项标题不能为空。"
            return false
        }

        guard currentAuthorizationState().isGranted else {
            errorMessage = "请先允许应用访问提醒事项。"
            return false
        }

        guard let calendar = reminderCalendar(for: calendarIdentifier) else {
            errorMessage = "没有找到可写入的提醒事项列表。"
            return false
        }

        errorMessage = nil

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        reminder.title = trimmedTitle

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute],
                from: dueDate
            )
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }

        do {
            try eventStore.save(reminder, commit: true)
            await reloadData(resetStore: false)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func completeReminder(id: String) async -> Bool {
        guard currentAuthorizationState().isGranted else {
            errorMessage = "提醒事项权限不可用。"
            return false
        }

        guard let reminder = reminderCache[id] ?? (eventStore.calendarItem(withIdentifier: id) as? EKReminder) else {
            errorMessage = "找不到这个提醒事项，可能已经被修改了。"
            await reloadData(resetStore: true)
            return false
        }

        reminder.isCompleted = true
        reminder.completionDate = Date()

        do {
            try eventStore.save(reminder, commit: true)
            await reloadData(resetStore: false)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func refreshAuthorizationAndLoad(forceRequest: Bool) async {
        let currentState = currentAuthorizationState()
        authorizationState = currentState

        if forceRequest || currentState == .unknown {
            authorizationState = .requesting
            let granted = await requestReminderAccess()
            authorizationState = granted ? .granted : currentAuthorizationState()
        }

        guard authorizationState.isGranted else {
            reminders = []
            reminderCache = [:]
            updateCalendars()
            return
        }

        await reloadData(resetStore: true)
    }

    private func requestReminderAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToReminders { granted, _ in
                    continuation.resume(returning: granted)
                }
            } else {
                eventStore.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func reloadData(resetStore: Bool) async {
        let state = currentAuthorizationState()
        authorizationState = state

        guard state.isGranted else {
            reminders = []
            reminderCache = [:]
            updateCalendars()
            return
        }

        if resetStore {
            eventStore.reset()
        }

        isLoading = true
        errorMessage = nil
        updateCalendars()

        let fetchedReminders = await fetchIncompleteReminders()
        reminderCache = Dictionary(uniqueKeysWithValues: fetchedReminders.map { ($0.calendarItemIdentifier, $0) })
        reminders = fetchedReminders
            .map(Self.snapshot(from:))
            .sorted(by: Self.compareReminders)

        if selectedCalendarIdentifier.isEmpty || !writableCalendars.contains(where: { $0.id == selectedCalendarIdentifier }) {
            selectedCalendarIdentifier = preferredCalendarIdentifier()
        }

        isLoading = false
    }

    private func fetchIncompleteReminders() async -> [EKReminder] {
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private func updateCalendars() {
        let calendars = eventStore.calendars(for: .reminder)
            .filter(\.allowsContentModifications)
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }

        writableCalendars = calendars.map {
            ReminderListOption(id: $0.calendarIdentifier, title: $0.title)
        }
    }

    private func preferredCalendarIdentifier() -> String {
        if let calendar = eventStore.defaultCalendarForNewReminders(), calendar.allowsContentModifications {
            return calendar.calendarIdentifier
        }

        return writableCalendars.first?.id ?? ""
    }

    private func reminderCalendar(for identifier: String?) -> EKCalendar? {
        if let identifier, let calendar = eventStore.calendar(withIdentifier: identifier), calendar.allowsContentModifications {
            return calendar
        }

        if let defaultCalendar = eventStore.defaultCalendarForNewReminders(), defaultCalendar.allowsContentModifications {
            return defaultCalendar
        }

        guard let firstWritableCalendar = writableCalendars.first else {
            return nil
        }

        return eventStore.calendar(withIdentifier: firstWritableCalendar.id)
    }

    private func observeEventStoreChangesIfNeeded() {
        guard changeObserver == nil else {
            return
        }

        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.reloadData(resetStore: true)
            }
        }
    }

    private func currentAuthorizationState() -> ReminderAuthorizationState {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:
                return .granted
            case .writeOnly:
                return .denied
            case .notDetermined:
                return .unknown
            case .restricted:
                return .restricted
            case .denied:
                return .denied
            @unknown default:
                return .denied
            }
        } else {
            switch status {
            case .authorized:
                return .granted
            case .fullAccess:
                return .granted
            case .writeOnly:
                return .denied
            case .notDetermined:
                return .unknown
            case .restricted:
                return .restricted
            case .denied:
                return .denied
            @unknown default:
                return .denied
            }
        }
    }

    private static func snapshot(from reminder: EKReminder) -> ReminderSnapshot {
        ReminderSnapshot(
            id: reminder.calendarItemIdentifier,
            title: reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名提醒" : reminder.title,
            notes: reminder.notes,
            calendarTitle: reminder.calendar.title,
            calendarIdentifier: reminder.calendar.calendarIdentifier,
            dueDate: reminder.dueDateComponents?.date,
            priority: reminder.priority,
            isCompleted: reminder.isCompleted
        )
    }

    private static func compareReminders(lhs: ReminderSnapshot, rhs: ReminderSnapshot) -> Bool {
        let lhsDueDate = lhs.dueDate ?? .distantFuture
        let rhsDueDate = rhs.dueDate ?? .distantFuture

        if lhsDueDate != rhsDueDate {
            return lhsDueDate < rhsDueDate
        }

        let lhsPriority = lhs.priority == 0 ? 10 : lhs.priority
        let rhsPriority = rhs.priority == 0 ? 10 : rhs.priority

        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        if lhs.calendarTitle != rhs.calendarTitle {
            return lhs.calendarTitle.localizedCaseInsensitiveCompare(rhs.calendarTitle) == .orderedAscending
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}
