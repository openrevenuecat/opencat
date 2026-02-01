import Foundation
import SwiftUI

enum TaskPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return .rdSuccess
        case .medium: return .rdWarning
        case .high: return .rdError
        }
    }

    var icon: String {
        switch self {
        case .low: return "flag"
        case .medium: return "flag.fill"
        case .high: return "exclamationmark.triangle.fill"
        }
    }
}

enum TaskStatus: String, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .pending: return "To Do"
        case .inProgress: return "In Progress"
        case .completed: return "Done"
        case .cancelled: return "Cancelled"
        }
    }
}

struct EventTask: Identifiable, Codable, Hashable {
    let id: String
    var eventId: String?  // Optional - may not be stored in subcollection documents
    var title: String
    var description: String?
    var status: TaskStatus
    var priority: TaskPriority
    var dueDate: Date?
    var assignedTo: [String]
    var category: String?
    var estimatedCost: Double?
    var actualCost: Double?
    var attachments: [String]
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var order: Int  // Position in the list for custom ordering

    init(
        id: String = UUID().uuidString,
        eventId: String? = nil,
        title: String,
        description: String? = nil,
        status: TaskStatus = .pending,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        assignedTo: [String] = [],
        category: String? = nil,
        estimatedCost: Double? = nil,
        actualCost: Double? = nil,
        attachments: [String] = [],
        createdBy: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.eventId = eventId
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.assignedTo = assignedTo
        self.category = category
        self.estimatedCost = estimatedCost
        self.actualCost = actualCost
        self.attachments = attachments
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.order = order
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && status != .completed && status != .cancelled
    }
}

extension EventTask {
    static let mock = EventTask(
        id: "task_123",
        eventId: "event_123",
        title: "Book venue",
        description: "Find and book a suitable venue for the party",
        status: .pending,
        priority: .high,
        dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
        createdBy: "user_123"
    )

    static let mockList: [EventTask] = [
        .mock,
        EventTask(
            id: "task_456",
            eventId: "event_123",
            title: "Order cake",
            status: .inProgress,
            priority: .medium,
            dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
            createdBy: "user_123"
        ),
        EventTask(
            id: "task_789",
            eventId: "event_123",
            title: "Send invitations",
            status: .completed,
            priority: .high,
            createdBy: "user_123",
            completedAt: Date()
        ),
        EventTask(
            id: "task_012",
            eventId: "event_123",
            title: "Arrange decorations",
            status: .pending,
            priority: .low,
            createdBy: "user_123"
        )
    ]
}
