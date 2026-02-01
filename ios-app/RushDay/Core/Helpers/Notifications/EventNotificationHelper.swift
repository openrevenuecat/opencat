//
//  EventNotificationHelper.swift
//  RushDay
//
//  Helper for building event reminder notification requests.
//

import Foundation

/// Helper for building event notification requests.
enum EventNotificationHelper {

    // MARK: - Build Create Request

    /// Builds a notification request for an event reminder.
    /// - Parameters:
    ///   - event: The event to create a notification for
    ///   - tokens: FCM tokens for the user's devices
    ///   - userId: The user's ID
    ///   - config: The user's notification configuration
    /// - Returns: A CreateNotificationRequest for the event
    @MainActor
    static func buildCreateRequest(
        event: Event,
        tokens: [String],
        userId: String,
        config: NotificationConfiguration?
    ) -> CreateNotificationRequest? {
        guard let config = config, config.isEnableUpComingReminder else {
            return nil
        }

        let sendAt = calculateSendAt(
            eventDate: event.startDate,
            period: config.upComingPeriod,
            reminderTime: config.upComingReminderTime
        )

        // Don't create notifications for past dates
        guard sendAt > Date() else {
            return nil
        }

        let (title, body) = buildNotificationContent(event: event)

        return CreateNotificationRequest(
            userId: userId,
            type: .eventReminder,
            tokens: tokens,
            title: title,
            body: body,
            sendAt: sendAt,
            data: buildDataPayload(event: event),
            eventId: event.id,
            groupId: userId // Group by user for bulk period adjustments
        )
    }

    // MARK: - Calculate Send At

    /// Calculates when the notification should be sent based on event date and user preferences.
    static func calculateSendAt(
        eventDate: Date,
        period: UpComingEventReminderPeriod,
        reminderTime: String
    ) -> Date {
        // Calculate the base date based on period
        let baseDate: Date
        switch period {
        case .onEventDay:
            baseDate = eventDate
        case .dayBefore:
            baseDate = Calendar.current.date(byAdding: .day, value: -1, to: eventDate) ?? eventDate
        case .weekBefore:
            baseDate = Calendar.current.date(byAdding: .day, value: -7, to: eventDate) ?? eventDate
        case .twoWeeksBefore:
            baseDate = Calendar.current.date(byAdding: .day, value: -14, to: eventDate) ?? eventDate
        case .monthBefore:
            baseDate = Calendar.current.date(byAdding: .month, value: -1, to: eventDate) ?? eventDate
        }

        // Parse the reminder time (format: "HH:mm")
        let timeParts = reminderTime.split(separator: ":").map { Int($0) ?? 0 }
        let hour = timeParts.count > 0 ? timeParts[0] : 9
        let minute = timeParts.count > 1 ? timeParts[1] : 0

        // Set the time on the base date
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? baseDate
    }

    // MARK: - Build Notification Content

    /// Builds the title and body for an event notification.
    @MainActor
    static func buildNotificationContent(event: Event) -> (title: String, body: String) {
        let title = L10n.eventReminderTitle(event.name)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: event.startDate)

        let body = L10n.eventReminderSubtitle(dateString)

        return (title, body)
    }

    // MARK: - Build Data Payload

    /// Builds the notification data payload for an event.
    static func buildDataPayload(event: Event) -> [String: AnyCodable] {
        return [
            "type": AnyCodable(NotificationType.eventReminder.apiValue),
            "eventId": AnyCodable(event.id)
        ]
    }

    // MARK: - Period Offset

    /// Returns the number of days offset for a given reminder period.
    static func periodOffset(_ period: UpComingEventReminderPeriod) -> Int {
        switch period {
        case .onEventDay: return 0
        case .dayBefore: return -1
        case .weekBefore: return -7
        case .twoWeeksBefore: return -14
        case .monthBefore: return -30
        }
    }

    /// Calculates the delta in milliseconds between two reminder periods.
    static func calculatePeriodDeltaMs(
        from oldPeriod: UpComingEventReminderPeriod,
        to newPeriod: UpComingEventReminderPeriod
    ) -> Int {
        let oldDays = periodOffset(oldPeriod)
        let newDays = periodOffset(newPeriod)
        let daysDiff = newDays - oldDays
        return daysDiff * 24 * 60 * 60 * 1000 // Convert days to milliseconds
    }
}

// MARK: - Localization Helpers

private extension L10n {
    @MainActor
    static func eventReminderTitle(_ eventName: String) -> String {
        // TODO: Replace with proper localization
        return "Upcoming Event: \(eventName)"
    }

    @MainActor
    static func eventReminderSubtitle(_ dateTime: String) -> String {
        // TODO: Replace with proper localization
        return "Your event is scheduled for \(dateTime)"
    }
}
