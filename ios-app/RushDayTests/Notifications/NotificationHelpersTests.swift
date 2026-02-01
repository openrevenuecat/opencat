import XCTest
@testable import RushDay

/// Unit tests for notification helper classes
@MainActor
final class NotificationHelpersTests: XCTestCase {

    // MARK: - Test Data

    private let testUserId = "user123"
    private let testEventId = "event456"
    private let testTokens = ["token1", "token2"]

    // MARK: - TaskNotificationHelper Tests

    func testTaskNotificationHelper_BuildCreateRequest_WithDueDate() {
        let dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = EventTask(
            id: "task123",
            eventId: testEventId,
            title: "Book venue",
            description: "Find and book the event venue",
            status: .pending,
            priority: .high,
            dueDate: dueDate
        )

        let request = TaskNotificationHelper.buildCreateRequest(
            task: task,
            tokens: testTokens,
            userId: testUserId,
            eventId: testEventId
        )

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.userId, testUserId)
        XCTAssertEqual(request?.type, .taskReminder)
        XCTAssertEqual(request?.tokens, testTokens)
        XCTAssertEqual(request?.eventId, testEventId)
        XCTAssertEqual(request?.taskId, "task123")
        XCTAssertNotNil(request?.data)
    }

    func testTaskNotificationHelper_BuildCreateRequest_WithoutDueDate() {
        let task = EventTask(
            id: "task123",
            eventId: testEventId,
            title: "Book venue",
            status: .pending,
            priority: .medium
        )

        let request = TaskNotificationHelper.buildCreateRequest(
            task: task,
            tokens: testTokens,
            userId: testUserId,
            eventId: testEventId
        )

        // Should return nil when task has no due date
        XCTAssertNil(request)
    }

    func testTaskNotificationHelper_BuildCreateRequest_WithPastDueDate() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = EventTask(
            id: "task123",
            eventId: testEventId,
            title: "Book venue",
            status: .pending,
            priority: .high,
            dueDate: pastDate
        )

        let request = TaskNotificationHelper.buildCreateRequest(
            task: task,
            tokens: testTokens,
            userId: testUserId,
            eventId: testEventId
        )

        // Should return nil for past dates
        XCTAssertNil(request)
    }

    func testTaskNotificationHelper_ShouldCreateNotification() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let taskWithDueDate = EventTask(
            id: "task1",
            eventId: testEventId,
            title: "Task with due date",
            status: .pending,
            priority: .medium,
            dueDate: futureDate
        )

        let taskWithoutDueDate = EventTask(
            id: "task2",
            eventId: testEventId,
            title: "Task without due date",
            status: .pending,
            priority: .medium
        )

        XCTAssertTrue(TaskNotificationHelper.shouldCreateNotification(taskWithDueDate))
        XCTAssertFalse(TaskNotificationHelper.shouldCreateNotification(taskWithoutDueDate))
    }

    func testTaskNotificationHelper_BuildDataPayload() {
        let task = EventTask(
            id: "task123",
            eventId: testEventId,
            title: "Test Task",
            status: .pending,
            priority: .medium
        )

        let payload = TaskNotificationHelper.buildDataPayload(task: task, eventId: testEventId)

        XCTAssertNotNil(payload["type"])
        XCTAssertNotNil(payload["taskId"])
        XCTAssertNotNil(payload["eventId"])
    }

    // MARK: - EventNotificationHelper Tests

    func testEventNotificationHelper_BuildCreateRequest() {
        let eventDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let event = Event(
            id: testEventId,
            name: "Birthday Party",
            startDate: eventDate,
            eventTypeId: "birthday",
            ownerId: testUserId
        )

        let config = NotificationConfiguration(
            eventEnabled: true,
            eventReminderPeriod: 3600, // 1 hour before
            eventReminderTime: .oneHourBefore
        )

        let request = EventNotificationHelper.buildCreateRequest(
            event: event,
            tokens: testTokens,
            userId: testUserId,
            config: config
        )

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.userId, testUserId)
        XCTAssertEqual(request?.type, .eventReminder)
        XCTAssertEqual(request?.tokens, testTokens)
        XCTAssertEqual(request?.eventId, testEventId)
    }

    func testEventNotificationHelper_BuildCreateRequest_WhenDisabled() {
        let eventDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let event = Event(
            id: testEventId,
            name: "Birthday Party",
            startDate: eventDate,
            eventTypeId: "birthday",
            ownerId: testUserId
        )

        let config = NotificationConfiguration(
            eventEnabled: false,
            eventReminderPeriod: 3600,
            eventReminderTime: .oneHourBefore
        )

        let request = EventNotificationHelper.buildCreateRequest(
            event: event,
            tokens: testTokens,
            userId: testUserId,
            config: config
        )

        // Should return nil when notifications are disabled
        XCTAssertNil(request)
    }

    func testEventNotificationHelper_CalculateSendAt() {
        let eventDate = Date(timeIntervalSince1970: 1704110400) // 2024-01-01 12:00:00 UTC
        let period: TimeInterval = 3600 // 1 hour

        let sendAt = EventNotificationHelper.calculateSendAt(
            eventDate: eventDate,
            period: period,
            reminderTime: .oneHourBefore
        )

        // Should be 1 hour before the event
        let expectedSendAt = Date(timeIntervalSince1970: 1704106800) // 2024-01-01 11:00:00 UTC
        XCTAssertEqual(sendAt.timeIntervalSince1970, expectedSendAt.timeIntervalSince1970, accuracy: 1)
    }

    func testEventNotificationHelper_BuildDataPayload() {
        let event = Event(
            id: testEventId,
            name: "Test Event",
            startDate: Date(),
            eventTypeId: "birthday",
            ownerId: testUserId
        )

        let payload = EventNotificationHelper.buildDataPayload(event: event)

        XCTAssertNotNil(payload["type"])
        XCTAssertNotNil(payload["eventId"])
    }

    // MARK: - AgendaNotificationHelper Tests

    func testAgendaNotificationHelper_BuildCreateRequest() {
        let agendaStartTime = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
        let agenda = AgendaItem(
            id: "agenda123",
            eventId: testEventId,
            title: "Opening Ceremony",
            startTime: agendaStartTime
        )

        let request = AgendaNotificationHelper.buildCreateRequest(
            agenda: agenda,
            tokens: testTokens,
            userId: testUserId,
            eventId: testEventId,
            period: .fifteenMinutesBefore
        )

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.userId, testUserId)
        XCTAssertEqual(request?.type, .agendaNotification)
        XCTAssertEqual(request?.tokens, testTokens)
        XCTAssertEqual(request?.eventId, testEventId)
        XCTAssertEqual(request?.agendaId, "agenda123")
    }

    func testAgendaNotificationHelper_BuildCreateRequest_WithPastTime() {
        let pastTime = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        let agenda = AgendaItem(
            id: "agenda123",
            eventId: testEventId,
            title: "Opening Ceremony",
            startTime: pastTime
        )

        let request = AgendaNotificationHelper.buildCreateRequest(
            agenda: agenda,
            tokens: testTokens,
            userId: testUserId,
            eventId: testEventId,
            period: .fifteenMinutesBefore
        )

        // Should return nil for past agenda items
        XCTAssertNil(request)
    }

    func testAgendaNotificationHelper_CalculateSendAt() {
        let agendaStartTime = Date(timeIntervalSince1970: 1704110400) // 2024-01-01 12:00:00 UTC

        let sendAtFifteenMinutes = AgendaNotificationHelper.calculateSendAt(
            agendaStartTime: agendaStartTime,
            period: .fifteenMinutesBefore
        )

        let sendAtThirtyMinutes = AgendaNotificationHelper.calculateSendAt(
            agendaStartTime: agendaStartTime,
            period: .thirtyMinutesBefore
        )

        let sendAtTime = AgendaNotificationHelper.calculateSendAt(
            agendaStartTime: agendaStartTime,
            period: .atActivityTime
        )

        // 15 minutes before
        let expected15 = Date(timeIntervalSince1970: 1704109500) // 12:00 - 15 min = 11:45
        XCTAssertEqual(sendAtFifteenMinutes.timeIntervalSince1970, expected15.timeIntervalSince1970, accuracy: 1)

        // 30 minutes before
        let expected30 = Date(timeIntervalSince1970: 1704108600) // 12:00 - 30 min = 11:30
        XCTAssertEqual(sendAtThirtyMinutes.timeIntervalSince1970, expected30.timeIntervalSince1970, accuracy: 1)

        // At time
        XCTAssertEqual(sendAtTime.timeIntervalSince1970, agendaStartTime.timeIntervalSince1970, accuracy: 1)
    }

    func testAgendaNotificationHelper_PeriodMinutesOffset() {
        XCTAssertEqual(AgendaNotificationHelper.periodMinutesOffset(.atActivityTime), 0)
        XCTAssertEqual(AgendaNotificationHelper.periodMinutesOffset(.fiveMinutesBefore), -5)
        XCTAssertEqual(AgendaNotificationHelper.periodMinutesOffset(.fifteenMinutesBefore), -15)
        XCTAssertEqual(AgendaNotificationHelper.periodMinutesOffset(.thirtyMinutesBefore), -30)
    }

    func testAgendaNotificationHelper_BuildBatchRequests() {
        let now = Date()
        let agendas = [
            AgendaItem(
                id: "agenda1",
                eventId: testEventId,
                title: "Session 1",
                startTime: Calendar.current.date(byAdding: .hour, value: 1, to: now)!
            ),
            AgendaItem(
                id: "agenda2",
                eventId: testEventId,
                title: "Session 2",
                startTime: Calendar.current.date(byAdding: .hour, value: 2, to: now)!
            ),
            AgendaItem(
                id: "agenda3",
                eventId: testEventId,
                title: "Past Session",
                startTime: Calendar.current.date(byAdding: .hour, value: -1, to: now)! // Past
            )
        ]

        let requests = AgendaNotificationHelper.buildBatchRequests(
            agendas: agendas,
            tokens: testTokens,
            userId: testUserId,
            eventId: testEventId,
            period: .fifteenMinutesBefore
        )

        // Should only create requests for future agenda items
        XCTAssertEqual(requests.count, 2)
    }

    // MARK: - HostNotificationHelper Tests

    func testHostNotificationHelper_BuildCreateRequest() {
        let request = HostNotificationHelper.buildCreateRequest(
            eventId: testEventId,
            eventName: "Birthday Party",
            inviterName: "John Doe",
            recipientUserId: "recipient123",
            recipientTokens: testTokens,
            senderId: testUserId
        )

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.userId, "recipient123")
        XCTAssertEqual(request?.type, .hostInvitation)
        XCTAssertEqual(request?.tokens, testTokens)
        XCTAssertEqual(request?.eventId, testEventId)
        XCTAssertEqual(request?.recipientId, "recipient123")
    }

    func testHostNotificationHelper_BuildDataPayload() {
        let payload = HostNotificationHelper.buildDataPayload(
            eventId: testEventId,
            senderId: testUserId
        )

        XCTAssertNotNil(payload["type"])
        XCTAssertNotNil(payload["eventId"])
        XCTAssertNotNil(payload["senderId"])
    }
}
