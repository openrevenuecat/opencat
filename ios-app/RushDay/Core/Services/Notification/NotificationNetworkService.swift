//
//  NotificationNetworkService.swift
//  RushDay
//
//  Network service for scheduling and managing push notifications.
//

import Foundation

// MARK: - Protocol

/// Protocol for notification scheduling network operations.
protocol NotificationNetworkServiceProtocol {
    /// Create a single notification
    func createNotification(_ request: CreateNotificationRequest) async throws -> Bool

    /// Create multiple notifications in batch
    func createNotificationsBatch(_ requests: [CreateNotificationRequest]) async throws -> Bool

    /// Update all notifications in a group
    func updateNotificationsByGroup(
        groupField: GroupField,
        groupValue: String,
        title: String?,
        body: String?,
        sendAt: Date?,
        data: [String: AnyCodable]?
    ) async throws -> Bool

    /// Delete all notifications in a group
    func deleteNotificationsByGroup(
        groupField: GroupField,
        groupValue: String
    ) async throws -> Bool

    /// Delete a specific user's notification from a group
    func deleteUserNotificationFromGroup(
        groupField: GroupField,
        groupValue: String,
        userId: String
    ) async throws -> Bool

    /// Delete multiple notifications by filters
    func deleteNotificationsBatch(_ filters: [[String: String]]) async throws -> Bool

    /// Adjust notification timing by type
    func editNotificationPeriodByType(
        userId: String,
        type: NotificationType,
        deltaMs: Int
    ) async throws -> Bool

    /// Toggle notification type on/off
    func toggleNotificationType(
        userId: String,
        type: NotificationType,
        enabled: Bool
    ) async throws -> Bool
}

// MARK: - Implementation

/// Implementation of notification network service using URLSession.
final class NotificationNetworkService: NotificationNetworkServiceProtocol {

    // MARK: - Properties

    private let baseUrl: String
    private let session: URLSession

    private var apiUrl: String {
        return "\(baseUrl)/api"
    }

    private var defaultHeaders: [String: String] {
        return ["Content-Type": "application/json"]
    }

    // MARK: - Init

    init(baseUrl: String = AppConfig.shared.notificationServiceUrl, session: URLSession = .shared) {
        self.baseUrl = baseUrl
        self.session = session
    }

    // MARK: - Create Notifications

    func createNotification(_ request: CreateNotificationRequest) async throws -> Bool {
        let url = URL(string: "\(apiUrl)/notifications/schedule")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = defaultHeaders

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationApiError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            return true
        } else {
            throw NotificationApiError.httpError(statusCode: httpResponse.statusCode, message: "Failed to create notification")
        }
    }

    func createNotificationsBatch(_ requests: [CreateNotificationRequest]) async throws -> Bool {
        let url = URL(string: "\(apiUrl)/notifications/batch")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = defaultHeaders

        let body = BatchCreateRequest(notifications: requests)
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(body)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationApiError.invalidResponse
        }

        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            return true
        } else {
            throw NotificationApiError.httpError(statusCode: httpResponse.statusCode, message: "Failed to create batch notifications")
        }
    }

    // MARK: - Update Notifications

    func updateNotificationsByGroup(
        groupField: GroupField,
        groupValue: String,
        title: String?,
        body: String?,
        sendAt: Date?,
        data: [String: AnyCodable]?
    ) async throws -> Bool {
        let url = URL(string: "\(apiUrl)/notifications/groups/\(groupField.apiValue)/\(groupValue)")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.allHTTPHeaderFields = defaultHeaders

        let updateRequest = UpdateNotificationRequest(
            title: title,
            body: body,
            sendAt: sendAt,
            data: data
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(updateRequest)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationApiError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return true
        } else {
            throw NotificationApiError.httpError(statusCode: httpResponse.statusCode, message: "Failed to update notifications")
        }
    }

    // MARK: - Delete Notifications

    func deleteNotificationsByGroup(
        groupField: GroupField,
        groupValue: String
    ) async throws -> Bool {
        let url = URL(string: "\(apiUrl)/notifications/groups/\(groupField.apiValue)/\(groupValue)")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.allHTTPHeaderFields = defaultHeaders

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationApiError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return true
        } else {
            throw NotificationApiError.httpError(statusCode: httpResponse.statusCode, message: "Failed to delete notifications")
        }
    }

    func deleteUserNotificationFromGroup(
        groupField: GroupField,
        groupValue: String,
        userId: String
    ) async throws -> Bool {
        let url = URL(string: "\(apiUrl)/notifications/groups/\(groupField.apiValue)/\(groupValue)/users/\(userId)")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.allHTTPHeaderFields = defaultHeaders

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationApiError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return true
        } else {
            throw NotificationApiError.httpError(statusCode: httpResponse.statusCode, message: "Failed to delete user notification")
        }
    }

    func deleteNotificationsBatch(_ filters: [[String: String]]) async throws -> Bool {
        let url = URL(string: "\(apiUrl)/notifications/batch")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.allHTTPHeaderFields = defaultHeaders

        let body = BatchDeleteFilter(filters: filters)
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(body)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationApiError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return true
        } else {
            throw NotificationApiError.httpError(statusCode: httpResponse.statusCode, message: "Failed to delete batch notifications")
        }
    }

    // MARK: - Notification Settings

    func editNotificationPeriodByType(
        userId: String,
        type: NotificationType,
        deltaMs: Int
    ) async throws -> Bool {
        let url = URL(string: "\(apiUrl)/notifications/adjust-time")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.allHTTPHeaderFields = defaultHeaders

        let request = AdjustTimeRequest(userId: userId, type: type.apiValue, deltaMs: deltaMs)
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationApiError.invalidResponse
        }

        return httpResponse.statusCode == 200
    }

    func toggleNotificationType(
        userId: String,
        type: NotificationType,
        enabled: Bool
    ) async throws -> Bool {
        let url = URL(string: "\(apiUrl)/notifications/toggle")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.allHTTPHeaderFields = defaultHeaders

        let request = ToggleTypeRequest(userId: userId, type: type.apiValue, enabled: enabled)
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationApiError.invalidResponse
        }

        return httpResponse.statusCode == 200
    }
}

// MARK: - Helper Models

private struct BatchCreateRequest: Encodable {
    let notifications: [CreateNotificationRequest]
}

// MARK: - Error Types

/// Errors that can occur when interacting with the notification API.
enum NotificationApiError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case encodingError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from notification service"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
