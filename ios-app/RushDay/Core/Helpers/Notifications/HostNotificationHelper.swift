//
//  HostNotificationHelper.swift
//  RushDay
//
//  Helper for building co-host invitation notification requests.
//

import Foundation

/// Helper for building host invitation notification requests.
enum HostNotificationHelper {

    // MARK: - Build Create Request

    /// Builds a notification request for a co-host invitation.
    /// - Parameters:
    ///   - userId: The user being invited as co-host
    ///   - tokens: FCM tokens for the invited user's devices
    ///   - inviterName: Name of the user sending the invitation
    ///   - eventName: Name of the event
    ///   - eventId: The event ID
    /// - Returns: A CreateNotificationRequest for the invitation
    @MainActor
    static func buildCreateRequest(
        userId: String,
        tokens: [String],
        inviterName: String,
        eventName: String,
        eventId: String
    ) -> CreateNotificationRequest {
        return CreateNotificationRequest(
            userId: userId,
            type: .hostInvitation,
            tokens: tokens,
            title: L10n.hostInvitationTitle,
            body: L10n.hostInvitationSubtitle(inviterName, eventName),
            sendAt: Date(), // Send immediately
            data: buildDataPayload(userId: userId, eventId: eventId),
            eventId: eventId
        )
    }

    // MARK: - Build Data Payload

    /// Builds the notification data payload for a host invitation.
    static func buildDataPayload(userId: String, eventId: String) -> [String: AnyCodable] {
        return [
            "type": AnyCodable(NotificationType.hostInvitation.apiValue),
            "userId": AnyCodable(userId),
            "eventId": AnyCodable(eventId)
        ]
    }
}

// MARK: - Localization Helpers

private extension L10n {
    @MainActor
    static var hostInvitationTitle: String {
        // TODO: Replace with proper localization
        return "Co-Host Invitation"
    }

    @MainActor
    static func hostInvitationSubtitle(_ inviterName: String, _ eventName: String) -> String {
        // TODO: Replace with proper localization
        return "\(inviterName) invited you to co-host \(eventName)"
    }
}
