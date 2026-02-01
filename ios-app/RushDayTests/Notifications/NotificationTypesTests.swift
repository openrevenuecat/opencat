import XCTest
@testable import RushDay

/// Unit tests for notification types and models
final class NotificationTypesTests: XCTestCase {

    // MARK: - NotificationType Tests

    func testNotificationTypeApiValues() {
        XCTAssertEqual(NotificationType.taskReminder.apiValue, "task_reminder")
        XCTAssertEqual(NotificationType.eventReminder.apiValue, "event_reminder")
        XCTAssertEqual(NotificationType.agendaNotification.apiValue, "agenda_notification")
        XCTAssertEqual(NotificationType.rsvpStatus.apiValue, "rsvp_status")
        XCTAssertEqual(NotificationType.hostInvitation.apiValue, "host_invitation")
        XCTAssertEqual(NotificationType.inactivityAlert.apiValue, "inactivity_alert")
    }

    func testNotificationTypeAllCases() {
        XCTAssertEqual(NotificationType.allCases.count, 6)
    }

    // MARK: - GroupField Tests

    func testGroupFieldApiValues() {
        XCTAssertEqual(GroupField.eventId.apiValue, "eventId")
        XCTAssertEqual(GroupField.taskId.apiValue, "taskId")
        XCTAssertEqual(GroupField.agendaId.apiValue, "agendaId")
        XCTAssertEqual(GroupField.groupId.apiValue, "groupId")
    }

    // MARK: - AgendaReminderPeriod Tests

    func testAgendaReminderPeriodAllCases() {
        let allCases = AgendaReminderPeriod.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.atActivityTime))
        XCTAssertTrue(allCases.contains(.fiveMinutesBefore))
        XCTAssertTrue(allCases.contains(.fifteenMinutesBefore))
        XCTAssertTrue(allCases.contains(.thirtyMinutesBefore))
    }

    // MARK: - EventReminderTime Tests

    func testEventReminderTimeAllCases() {
        let allCases = EventReminderTime.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.atActivityTime))
        XCTAssertTrue(allCases.contains(.fifteenMinutesBefore))
        XCTAssertTrue(allCases.contains(.thirtyMinutesBefore))
        XCTAssertTrue(allCases.contains(.oneHourBefore))
        XCTAssertTrue(allCases.contains(.oneDayBefore))
    }

    // MARK: - CreateNotificationRequest Tests

    func testCreateNotificationRequestInitialization() {
        let sendAt = Date()
        let request = CreateNotificationRequest(
            userId: "user123",
            type: .taskReminder,
            tokens: ["token1", "token2"],
            title: "Test Title",
            body: "Test Body",
            sendAt: sendAt,
            data: ["key": AnyCodable("value")],
            eventId: "event123",
            taskId: "task456"
        )

        XCTAssertEqual(request.userId, "user123")
        XCTAssertEqual(request.type, .taskReminder)
        XCTAssertEqual(request.tokens.count, 2)
        XCTAssertEqual(request.title, "Test Title")
        XCTAssertEqual(request.body, "Test Body")
        XCTAssertEqual(request.sendAt, sendAt)
        XCTAssertEqual(request.eventId, "event123")
        XCTAssertEqual(request.taskId, "task456")
        XCTAssertNil(request.agendaId)
        XCTAssertNil(request.groupId)
    }

    func testCreateNotificationRequestWithMinimalData() {
        let request = CreateNotificationRequest(
            userId: "user123",
            type: .inactivityAlert,
            tokens: ["token1"],
            title: "Title",
            body: "Body",
            sendAt: Date()
        )

        XCTAssertNil(request.data)
        XCTAssertNil(request.eventId)
        XCTAssertNil(request.taskId)
        XCTAssertNil(request.agendaId)
        XCTAssertNil(request.groupId)
        XCTAssertNil(request.recipientId)
    }

    func testCreateNotificationRequestEncoding() throws {
        let sendAt = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
        let request = CreateNotificationRequest(
            userId: "user123",
            type: .eventReminder,
            tokens: ["token1"],
            title: "Event Reminder",
            body: "Your event is starting soon",
            sendAt: sendAt,
            eventId: "event789"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["userId"] as? String, "user123")
        XCTAssertEqual(json?["type"] as? String, "event_reminder")
        XCTAssertEqual(json?["title"] as? String, "Event Reminder")
        XCTAssertEqual(json?["eventId"] as? String, "event789")
    }

    // MARK: - AnyCodable Tests

    func testAnyCodableWithString() throws {
        let codable = AnyCodable("test string")
        let encoder = JSONEncoder()
        let data = try encoder.encode(codable)
        let json = try JSONSerialization.jsonObject(with: data)

        XCTAssertEqual(json as? String, "test string")
    }

    func testAnyCodableWithInt() throws {
        let codable = AnyCodable(42)
        let encoder = JSONEncoder()
        let data = try encoder.encode(codable)
        let json = try JSONSerialization.jsonObject(with: data)

        XCTAssertEqual(json as? Int, 42)
    }

    func testAnyCodableWithBool() throws {
        let codable = AnyCodable(true)
        let encoder = JSONEncoder()
        let data = try encoder.encode(codable)
        let json = try JSONSerialization.jsonObject(with: data)

        XCTAssertEqual(json as? Bool, true)
    }

    func testAnyCodableWithDictionary() throws {
        let dict: [String: Any] = ["key1": "value1", "key2": 123]
        let codable = AnyCodable(dict)
        let encoder = JSONEncoder()
        let data = try encoder.encode(codable)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["key1"] as? String, "value1")
        XCTAssertEqual(json?["key2"] as? Int, 123)
    }

    func testAnyCodableWithArray() throws {
        let array = ["item1", "item2", "item3"]
        let codable = AnyCodable(array)
        let encoder = JSONEncoder()
        let data = try encoder.encode(codable)
        let json = try JSONSerialization.jsonObject(with: data) as? [String]

        XCTAssertEqual(json, array)
    }
}
