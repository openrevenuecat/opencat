//
//  NotificationTypes.swift
//  RushDay
//
//  Notification type enums for the notification scheduling service.
//

import Foundation

// MARK: - NotificationType

/// Types of notifications that can be scheduled via the notification service.
enum NotificationType: String, Codable, CaseIterable {
    case taskReminder = "task_reminder"
    case agendaNotification = "agenda_notification"
    case rsvpStatus = "rsvp_status"
    case eventReminder = "event_reminder"
    case hostInvitation = "host_invitation"
    case inactivityAlert = "inactivity_alert"
    case coHostRemoved = "co_host_removed"

    /// Returns the API string value for this notification type.
    var apiValue: String {
        return rawValue
    }

    /// Creates a NotificationType from an API string value.
    static func from(_ value: String) -> NotificationType? {
        return NotificationType(rawValue: value)
    }
}

// MARK: - GroupField

/// Fields used to group notifications for batch operations.
enum GroupField: String, Codable {
    case eventId = "eventId"
    case taskId = "taskId"
    case agendaId = "agendaId"
    case groupId = "groupId"

    /// Returns the API string value for this group field.
    var apiValue: String {
        return rawValue
    }
}
