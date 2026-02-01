//
//  TaskNotificationHelper.swift
//  RushDay
//
//  Helper for building task reminder notification requests.
//

import Foundation

/// Helper for building task notification requests.
enum TaskNotificationHelper {

    // MARK: - Build Create Request

    /// Builds a notification request for a task reminder.
    /// - Parameters:
    ///   - task: The task to create a notification for
    ///   - tokens: FCM tokens for the user's devices
    ///   - userId: The user's ID
    ///   - eventId: The event ID the task belongs to
    ///   - timezone: Optional timezone identifier
    /// - Returns: A CreateNotificationRequest for the task
    @MainActor
    static func buildCreateRequest(
        task: EventTask,
        tokens: [String],
        userId: String,
        eventId: String,
        timezone: String? = nil
    ) -> CreateNotificationRequest? {
        // Use dueDate as the reminder time
        guard let reminderTime = task.dueDate else {
            return nil
        }

        // Don't create notifications for past dates
        guard reminderTime > Date() else {
            return nil
        }

        return CreateNotificationRequest(
            userId: userId,
            type: .taskReminder,
            tokens: tokens,
            title: L10n.taskReminderTitle(task.title),
            body: L10n.taskReminderSubtitle,
            sendAt: reminderTime,
            data: buildDataPayload(task: task, eventId: eventId),
            eventId: eventId,
            taskId: task.id,
            timezone: timezone
        )
    }

    // MARK: - Build Data Payload

    /// Builds the notification data payload for a task.
    static func buildDataPayload(task: EventTask, eventId: String) -> [String: AnyCodable] {
        return [
            "type": AnyCodable(NotificationType.taskReminder.apiValue),
            "taskId": AnyCodable(task.id),
            "eventId": AnyCodable(eventId),
            "taskTitle": AnyCodable(task.title)
        ]
    }

    // MARK: - Should Create Notification

    /// Checks if a notification should be created for the task.
    static func shouldCreateNotification(_ task: EventTask) -> Bool {
        guard let dueDate = task.dueDate else { return false }
        return dueDate > Date() && task.status != .completed && task.status != .cancelled
    }

    // MARK: - Check for Changes

    /// Determines what notification updates are needed when a task is updated.
    static func determineNotificationAction(
        newTask: EventTask,
        oldTask: EventTask
    ) -> TaskNotificationAction {
        let isNameChanged = newTask.title != oldTask.title
        let isDateChanged = newTask.dueDate != oldTask.dueDate
        let wasCompleted = newTask.status == .completed && oldTask.status != .completed
        let wasUncompleted = oldTask.status == .completed && newTask.status != .completed
        let wasReminderAdded = oldTask.dueDate == nil && newTask.dueDate != nil
        let wasReminderRemoved = oldTask.dueDate != nil && newTask.dueDate == nil

        // Task was completed - delete notification
        if wasCompleted {
            return .delete
        }

        // Task was uncompleted and has a reminder - create notification
        if wasUncompleted && newTask.dueDate != nil {
            return .create
        }

        // Reminder was added - create notification
        if wasReminderAdded && shouldCreateNotification(newTask) {
            return .create
        }

        // Reminder was removed - delete notification
        if wasReminderRemoved {
            return .delete
        }

        // Name or date changed - update notification
        if (isNameChanged || isDateChanged) && shouldCreateNotification(newTask) {
            return .update(nameChanged: isNameChanged, dateChanged: isDateChanged)
        }

        return .none
    }
}

// MARK: - Task Notification Action

/// Actions that can be taken for task notifications.
enum TaskNotificationAction {
    case create
    case update(nameChanged: Bool, dateChanged: Bool)
    case delete
    case none
}

// MARK: - Localization Helpers

private extension L10n {
    @MainActor
    static func taskReminderTitle(_ taskName: String) -> String {
        // TODO: Replace with proper localization
        return "Task Reminder: \(taskName)"
    }

    @MainActor
    static var taskReminderSubtitle: String {
        // TODO: Replace with proper localization
        return "Don't forget to complete this task!"
    }
}
