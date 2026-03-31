import Foundation

struct ReminderSnapshot: Identifiable, Hashable {
    let id: String
    let title: String
    let notes: String?
    let calendarTitle: String
    let calendarIdentifier: String
    let dueDate: Date?
    let priority: Int
    let isCompleted: Bool
}

struct ReminderListOption: Identifiable, Hashable {
    let id: String
    let title: String
}
