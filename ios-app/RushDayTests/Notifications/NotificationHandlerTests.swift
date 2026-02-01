import XCTest
@testable import RushDay

/// Unit tests for NotificationHandler
final class NotificationHandlerTests: XCTestCase {

    // MARK: - Parse Notification Tests

    func testParseNotification_TaskReminder() {
        let userInfo: [AnyHashable: Any] = [
            "type": "task_reminder",
            "taskId": "task123",
            "eventId": "event456"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        if case .taskDetails(let taskId, let eventId) = destination {
            XCTAssertEqual(taskId, "task123")
            XCTAssertEqual(eventId, "event456")
        } else {
            XCTFail("Expected taskDetails destination")
        }
    }

    func testParseNotification_TaskReminder_MissingTaskId() {
        let userInfo: [AnyHashable: Any] = [
            "type": "task_reminder",
            "eventId": "event456"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        XCTAssertEqual(destination, .unknown)
    }

    func testParseNotification_EventReminder() {
        let userInfo: [AnyHashable: Any] = [
            "type": "event_reminder",
            "eventId": "event789"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        if case .eventDetails(let eventId) = destination {
            XCTAssertEqual(eventId, "event789")
        } else {
            XCTFail("Expected eventDetails destination")
        }
    }

    func testParseNotification_EventReminder_MissingEventId() {
        let userInfo: [AnyHashable: Any] = [
            "type": "event_reminder"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        XCTAssertEqual(destination, .unknown)
    }

    func testParseNotification_AgendaNotification() {
        let userInfo: [AnyHashable: Any] = [
            "type": "agenda_notification",
            "agendaId": "agenda123",
            "eventId": "event456"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        if case .agendaDetails(let agendaId, let eventId) = destination {
            XCTAssertEqual(agendaId, "agenda123")
            XCTAssertEqual(eventId, "event456")
        } else {
            XCTFail("Expected agendaDetails destination")
        }
    }

    func testParseNotification_AgendaNotification_MissingAgendaId() {
        let userInfo: [AnyHashable: Any] = [
            "type": "agenda_notification",
            "eventId": "event456"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        XCTAssertEqual(destination, .unknown)
    }

    func testParseNotification_HostInvitation() {
        let userInfo: [AnyHashable: Any] = [
            "type": "host_invitation",
            "eventId": "event789"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        if case .hostInvitation(let eventId) = destination {
            XCTAssertEqual(eventId, "event789")
        } else {
            XCTFail("Expected hostInvitation destination")
        }
    }

    func testParseNotification_RsvpStatus() {
        let userInfo: [AnyHashable: Any] = [
            "type": "rsvp_status",
            "eventId": "event123"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        if case .eventDetails(let eventId) = destination {
            XCTAssertEqual(eventId, "event123")
        } else {
            XCTFail("Expected eventDetails destination for RSVP status")
        }
    }

    func testParseNotification_InactivityAlert() {
        let userInfo: [AnyHashable: Any] = [
            "type": "inactivity_alert"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        XCTAssertEqual(destination, .unknown)
    }

    func testParseNotification_UnknownType() {
        let userInfo: [AnyHashable: Any] = [
            "type": "some_unknown_type",
            "eventId": "event123"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        XCTAssertEqual(destination, .unknown)
    }

    func testParseNotification_MissingType() {
        let userInfo: [AnyHashable: Any] = [
            "eventId": "event123"
        ]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        XCTAssertEqual(destination, .unknown)
    }

    func testParseNotification_EmptyUserInfo() {
        let userInfo: [AnyHashable: Any] = [:]

        let destination = NotificationHandler.parseNotification(userInfo: userInfo)

        XCTAssertEqual(destination, .unknown)
    }

    // MARK: - Destination Equality Tests

    func testNotificationDestination_Equality() {
        let dest1 = NotificationDestination.taskDetails(taskId: "task1", eventId: "event1")
        let dest2 = NotificationDestination.taskDetails(taskId: "task1", eventId: "event1")
        let dest3 = NotificationDestination.taskDetails(taskId: "task2", eventId: "event1")

        XCTAssertEqual(dest1, dest2)
        XCTAssertNotEqual(dest1, dest3)
    }

    func testNotificationDestination_DifferentTypes() {
        let taskDest = NotificationDestination.taskDetails(taskId: "task1", eventId: "event1")
        let eventDest = NotificationDestination.eventDetails(eventId: "event1")
        let unknownDest = NotificationDestination.unknown

        XCTAssertNotEqual(taskDest, eventDest)
        XCTAssertNotEqual(taskDest, unknownDest)
        XCTAssertNotEqual(eventDest, unknownDest)
    }

    // MARK: - Analytics Tracking Tests

    func testTrackNotificationOpened_TaskReminder() {
        // This test just ensures the method doesn't crash
        // In a real implementation, we'd mock the AnalyticsService
        let destination = NotificationDestination.taskDetails(taskId: "task1", eventId: "event1")
        NotificationHandler.trackNotificationOpened(destination: destination)
        // If we get here without crashing, the test passes
    }

    func testTrackNotificationOpened_EventReminder() {
        let destination = NotificationDestination.eventDetails(eventId: "event1")
        NotificationHandler.trackNotificationOpened(destination: destination)
    }

    func testTrackNotificationOpened_AgendaNotification() {
        let destination = NotificationDestination.agendaDetails(agendaId: "agenda1", eventId: "event1")
        NotificationHandler.trackNotificationOpened(destination: destination)
    }

    func testTrackNotificationOpened_HostInvitation() {
        let destination = NotificationDestination.hostInvitation(eventId: "event1")
        NotificationHandler.trackNotificationOpened(destination: destination)
    }

    func testTrackNotificationOpened_Unknown() {
        let destination = NotificationDestination.unknown
        NotificationHandler.trackNotificationOpened(destination: destination)
    }
}

// MARK: - AppState EventSection Tests

extension NotificationHandlerTests {

    func testAppState_EventSection_AllCases() {
        // Verify all event sections exist
        let sections: [AppState.EventSection] = [.tasks, .guests, .agenda, .expenses]
        XCTAssertEqual(sections.count, 4)
    }
}
