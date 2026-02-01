//
//  CreateNotificationRequest.swift
//  RushDay
//
//  Request model for creating scheduled notifications via the notification service.
//

import Foundation

// MARK: - CreateNotificationRequest

/// Request model for scheduling a push notification.
struct CreateNotificationRequest: Encodable {
    let userId: String
    let type: NotificationType
    let tokens: [String]
    let title: String
    let body: String
    let sendAt: Date
    let sound: String?
    let data: [String: AnyCodable]?

    // Grouping fields
    let eventId: String?
    let taskId: String?
    let agendaId: String?
    let groupId: String?

    // User context
    let timezone: String?
    let recipientId: String?

    init(
        userId: String,
        type: NotificationType,
        tokens: [String],
        title: String,
        body: String,
        sendAt: Date,
        sound: String? = "default",
        data: [String: AnyCodable]? = nil,
        eventId: String? = nil,
        taskId: String? = nil,
        agendaId: String? = nil,
        groupId: String? = nil,
        timezone: String? = nil,
        recipientId: String? = nil
    ) {
        self.userId = userId
        self.type = type
        self.tokens = tokens
        self.title = title
        self.body = body
        self.sendAt = sendAt
        self.sound = sound
        self.data = data
        self.eventId = eventId
        self.taskId = taskId
        self.agendaId = agendaId
        self.groupId = groupId
        self.timezone = timezone
        self.recipientId = recipientId
    }

    // MARK: - Custom Encoding

    enum CodingKeys: String, CodingKey {
        case userId, type, tokens, title, body, sendAt, sound, data
        case eventId, taskId, agendaId, groupId, timezone, recipientId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(userId, forKey: .userId)
        try container.encode(type.apiValue, forKey: .type)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)

        // Format date as UTC string (matching Flutter format)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: sendAt)
        try container.encode(dateString, forKey: .sendAt)

        try container.encodeIfPresent(sound, forKey: .sound)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(eventId, forKey: .eventId)
        try container.encodeIfPresent(taskId, forKey: .taskId)
        try container.encodeIfPresent(agendaId, forKey: .agendaId)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encodeIfPresent(timezone, forKey: .timezone)
        try container.encodeIfPresent(recipientId, forKey: .recipientId)
    }
}

// MARK: - AnyCodable

/// A type-erased Codable value for encoding dynamic JSON data.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - UpdateNotificationRequest

/// Request model for updating notifications by group.
struct UpdateNotificationRequest: Encodable {
    let title: String?
    let body: String?
    let sendAt: Date?
    let data: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case title, body, sendAt, data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)

        if let sendAt = sendAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: sendAt), forKey: .sendAt)
        }

        try container.encodeIfPresent(data, forKey: .data)
    }
}

// MARK: - BatchDeleteFilter

/// Filter for batch delete operations.
struct BatchDeleteFilter: Encodable {
    let filters: [[String: String]]
}

// MARK: - AdjustTimeRequest

/// Request for adjusting notification timing by type.
struct AdjustTimeRequest: Encodable {
    let userId: String
    let type: String
    let deltaMs: Int
}

// MARK: - ToggleTypeRequest

/// Request for toggling notification type on/off.
struct ToggleTypeRequest: Encodable {
    let userId: String
    let type: String
    let enabled: Bool
}
