//
//  AgendaNotificationHelper.swift
//  RushDay
//
//  Helper for building agenda item notification requests.
//

import Foundation

/// Helper for building agenda notification requests.
enum AgendaNotificationHelper {

    // MARK: - Build Create Request

    /// Builds a notification request for an agenda item reminder.
    /// - Parameters:
    ///   - agenda: The agenda item to create a notification for
    ///   - tokens: FCM tokens for the user's devices
    ///   - userId: The user's ID
    ///   - eventId: The event ID the agenda belongs to
    ///   - period: The user's agenda reminder period preference
    /// - Returns: A CreateNotificationRequest for the agenda item
    @MainActor
    static func buildCreateRequest(
        agenda: AgendaItem,
        tokens: [String],
        userId: String,
        eventId: String,
        period: AgendaReminderPeriod
    ) -> CreateNotificationRequest? {
        let sendAt = calculateSendAt(agendaStartTime: agenda.startTime, period: period)

        // Don't create notifications for past dates
        guard sendAt > Date() else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: agenda.startTime)

        return CreateNotificationRequest(
            userId: userId,
            type: .agendaNotification,
            tokens: tokens,
            title: L10n.agendaReminderTitle(agenda.title, timeString),
            body: L10n.agendaReminderSubtitle,
            sendAt: sendAt,
            data: buildDataPayload(agenda: agenda, eventId: eventId),
            eventId: eventId,
            agendaId: agenda.id
        )
    }

    // MARK: - Calculate Send At

    /// Calculates when the notification should be sent based on agenda start time and period.
    static func calculateSendAt(agendaStartTime: Date, period: AgendaReminderPeriod) -> Date {
        let minutesOffset = periodMinutesOffset(period)
        return Calendar.current.date(byAdding: .minute, value: minutesOffset, to: agendaStartTime) ?? agendaStartTime
    }

    // MARK: - Build Data Payload

    /// Builds the notification data payload for an agenda item.
    static func buildDataPayload(agenda: AgendaItem, eventId: String) -> [String: AnyCodable] {
        return [
            "type": AnyCodable(NotificationType.agendaNotification.apiValue),
            "agendaId": AnyCodable(agenda.id),
            "eventId": AnyCodable(eventId)
        ]
    }

    // MARK: - Period Offset

    /// Returns the minutes offset for a given reminder period.
    static func periodMinutesOffset(_ period: AgendaReminderPeriod) -> Int {
        switch period {
        case .atActivityTime: return 0
        case .fiveMinutesBefore: return -5
        case .fifteenMinutesBefore: return -15
        case .thirtyMinutesBefore: return -30
        }
    }

    // MARK: - Build Batch Requests

    /// Builds notification requests for multiple agenda items.
    @MainActor
    static func buildBatchRequests(
        agendas: [AgendaItem],
        tokens: [String],
        userId: String,
        eventId: String,
        period: AgendaReminderPeriod
    ) -> [CreateNotificationRequest] {
        return agendas.compactMap { agenda in
            buildCreateRequest(
                agenda: agenda,
                tokens: tokens,
                userId: userId,
                eventId: eventId,
                period: period
            )
        }
    }
}

// MARK: - Localization Helpers

private extension L10n {
    @MainActor
    static func agendaReminderTitle(_ agendaName: String, _ time: String) -> String {
        // TODO: Replace with proper localization
        return "\(agendaName) at \(time)"
    }

    @MainActor
    static var agendaReminderSubtitle: String {
        // TODO: Replace with proper localization
        return "Your agenda item is starting soon!"
    }
}
