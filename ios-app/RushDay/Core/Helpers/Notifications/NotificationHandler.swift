//
//  NotificationHandler.swift
//  RushDay
//
//  Handles push notification taps and navigates to the appropriate screen.
//

import Foundation
import UserNotifications

// MARK: - Notification Destination

/// Represents the destination to navigate to from a notification
enum NotificationDestination: Equatable {
    case taskDetails(taskId: String, eventId: String)
    case eventDetails(eventId: String)
    case agendaDetails(agendaId: String, eventId: String)
    case hostInvitation(eventId: String)
    case unknown
}

// MARK: - Notification Handler

/// Handles incoming push notifications and determines navigation destination
enum NotificationHandler {

    // MARK: - Parse Notification

    /// Parses the notification user info and returns the destination
    /// - Parameter userInfo: The notification's userInfo dictionary
    /// - Returns: The destination to navigate to
    static func parseNotification(userInfo: [AnyHashable: Any]) -> NotificationDestination {
        guard let typeString = userInfo["type"] as? String else {
            return .unknown
        }

        let eventId = userInfo["eventId"] as? String

        switch typeString {
        case NotificationType.taskReminder.apiValue:
            guard let taskId = userInfo["taskId"] as? String,
                  let eventId = eventId else {
                return .unknown
            }
            return .taskDetails(taskId: taskId, eventId: eventId)

        case NotificationType.eventReminder.apiValue:
            guard let eventId = eventId else {
                return .unknown
            }
            return .eventDetails(eventId: eventId)

        case NotificationType.agendaNotification.apiValue:
            guard let agendaId = userInfo["agendaId"] as? String,
                  let eventId = eventId else {
                return .unknown
            }
            return .agendaDetails(agendaId: agendaId, eventId: eventId)

        case NotificationType.hostInvitation.apiValue:
            guard let eventId = eventId else {
                return .unknown
            }
            return .hostInvitation(eventId: eventId)

        case NotificationType.rsvpStatus.apiValue:
            // RSVP status notification - navigate to event
            guard let eventId = eventId else {
                return .unknown
            }
            return .eventDetails(eventId: eventId)

        case NotificationType.inactivityAlert.apiValue:
            // Inactivity alert - no specific destination
            return .unknown

        default:
            return .unknown
        }
    }

    // MARK: - Parse UNNotificationResponse

    /// Parses a UNNotificationResponse and returns the destination
    /// - Parameter response: The notification response from user interaction
    /// - Returns: The destination to navigate to
    static func parseNotificationResponse(_ response: UNNotificationResponse) -> NotificationDestination {
        let userInfo = response.notification.request.content.userInfo
        return parseNotification(userInfo: userInfo)
    }

    // MARK: - Handle Notification

    /// Handles the notification destination and updates app state for navigation
    /// - Parameters:
    ///   - destination: The destination to navigate to
    ///   - appState: The app state to update
    @MainActor
    static func handleNotification(destination: NotificationDestination, appState: AppState) {
        switch destination {
        case .taskDetails(_, let eventId):
            // Navigate to event first, then to tasks
            // The task details could be shown as a sheet from tasks list
            appState.navigateToEvent(eventId: eventId, section: .tasks)

        case .eventDetails(let eventId):
            appState.navigateToEvent(eventId: eventId, section: nil)

        case .agendaDetails(_, let eventId):
            // Navigate to event's agenda section
            appState.navigateToEvent(eventId: eventId, section: .agenda)

        case .hostInvitation(let eventId):
            // Navigate to event details for host invitation
            appState.navigateToEvent(eventId: eventId, section: nil)

        case .unknown:
            break
        }
    }

    // MARK: - Track Analytics

    /// Tracks notification interaction in analytics
    static func trackNotificationOpened(destination: NotificationDestination) {
        let type: String
        switch destination {
        case .taskDetails: type = "task_reminder"
        case .eventDetails: type = "event_reminder"
        case .agendaDetails: type = "agenda_notification"
        case .hostInvitation: type = "host_invitation"
        case .unknown: type = "unknown"
        }

        AnalyticsService.shared.logEvent("notification_opened", parameters: [
            "type": type
        ])
    }
}

// MARK: - AppState Extension for Navigation

extension AppState {
    /// Navigation sections within an event
    enum EventSection {
        case tasks
        case guests
        case agenda
        case expenses
    }

    /// Navigates to a specific event and optionally a section within it
    func navigateToEvent(eventId: String, section: EventSection?) {
        // Set the navigation route to event details
        // The specific section handling would be done in EventDetailsView
        currentRoute = .eventDetails(eventId: eventId)

        // Store the section to navigate to (if any) for the event details view to pick up
        if let section = section {
            pendingEventSection = section
        }
    }

    /// Pending section to navigate to after event details loads
    var pendingEventSection: EventSection? {
        get { _pendingEventSection }
        set { _pendingEventSection = newValue }
    }

    private var _pendingEventSection: EventSection? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.pendingSection) as? EventSection
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.pendingSection, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private enum AssociatedKeys {
        static var pendingSection: UInt8 = 0
    }
}
