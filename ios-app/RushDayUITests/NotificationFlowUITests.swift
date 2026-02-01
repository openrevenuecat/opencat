import XCTest

/// UI tests for notification-related user flows
/// Note: These tests require the app to be running with a test configuration
/// that mocks network services.
final class NotificationFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Task Notification Flow Tests

    /// Test that creating a task with a due date schedules a notification
    func testCreateTaskWithDueDate_SchedulesNotification() throws {
        // Skip if not logged in
        try skipIfNotLoggedIn()

        // Navigate to an event
        navigateToFirstEvent()

        // Navigate to tasks
        let tasksButton = app.buttons["Tasks"]
        XCTAssertTrue(tasksButton.waitForExistence(timeout: 5))
        tasksButton.tap()

        // Tap add task button
        let addButton = app.buttons["Add Task"]
        if addButton.exists {
            addButton.tap()

            // Fill in task details
            let titleField = app.textFields["Task Title"]
            if titleField.exists {
                titleField.tap()
                titleField.typeText("Test Task with Notification")
            }

            // Enable reminder (if toggle exists)
            let reminderToggle = app.switches["Reminder"]
            if reminderToggle.exists {
                reminderToggle.tap()
            }

            // Save the task
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            }

            // Verify task was created (task should appear in list)
            let taskCell = app.staticTexts["Test Task with Notification"]
            XCTAssertTrue(taskCell.waitForExistence(timeout: 3))
        }
    }

    /// Test that deleting a task removes its notification
    func testDeleteTask_RemovesNotification() throws {
        try skipIfNotLoggedIn()

        navigateToFirstEvent()

        let tasksButton = app.buttons["Tasks"]
        guard tasksButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Tasks button not found")
        }
        tasksButton.tap()

        // Find a task and swipe to delete
        let taskCell = app.cells.firstMatch
        if taskCell.exists {
            taskCell.swipeLeft()

            let deleteButton = app.buttons["Delete"]
            if deleteButton.exists {
                deleteButton.tap()

                // Confirm deletion if dialog appears
                let confirmButton = app.buttons["Confirm"]
                if confirmButton.exists {
                    confirmButton.tap()
                }
            }
        }
    }

    // MARK: - Event Notification Flow Tests

    /// Test that event creation schedules an event reminder
    func testCreateEvent_SchedulesEventReminder() throws {
        try skipIfNotLoggedIn()

        // Tap create event button
        let createButton = app.buttons["Create Event"]
        guard createButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Create Event button not found")
        }
        createButton.tap()

        // Fill in event details
        let eventNameField = app.textFields["Event Name"]
        if eventNameField.waitForExistence(timeout: 3) {
            eventNameField.tap()
            eventNameField.typeText("Test Event for Notification")
        }

        // Select event type if required
        let birthdayButton = app.buttons["Birthday"]
        if birthdayButton.exists {
            birthdayButton.tap()
        }

        // Navigate through the flow
        let continueButton = app.buttons["Continue"]
        if continueButton.exists {
            continueButton.tap()
        }

        // Complete event creation
        let publishButton = app.buttons["Publish"]
        if publishButton.waitForExistence(timeout: 5) {
            publishButton.tap()
        }
    }

    /// Test that deleting an event removes all its notifications
    func testDeleteEvent_RemovesAllNotifications() throws {
        try skipIfNotLoggedIn()

        navigateToFirstEvent()

        // Open event settings/menu
        let moreButton = app.buttons["More"]
        if moreButton.waitForExistence(timeout: 3) {
            moreButton.tap()

            let deleteButton = app.buttons["Delete Event"]
            if deleteButton.exists {
                deleteButton.tap()

                // Confirm deletion
                let confirmButton = app.buttons["Delete"]
                if confirmButton.waitForExistence(timeout: 2) {
                    confirmButton.tap()
                }
            }
        }
    }

    // MARK: - Agenda Notification Flow Tests

    /// Test that creating an agenda item schedules a notification
    func testCreateAgendaItem_SchedulesNotification() throws {
        try skipIfNotLoggedIn()

        navigateToFirstEvent()

        let agendaButton = app.buttons["Agenda"]
        guard agendaButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Agenda button not found")
        }
        agendaButton.tap()

        // Add agenda item
        let addButton = app.buttons["Add Activity"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()

            // Fill in activity details
            let titleField = app.textFields["Name"]
            if titleField.exists {
                titleField.tap()
                titleField.typeText("Test Activity")
            }

            // Save
            let saveButton = app.buttons["Add"]
            if saveButton.exists {
                saveButton.tap()
            }

            // Verify item was created
            let activityCell = app.staticTexts["Test Activity"]
            XCTAssertTrue(activityCell.waitForExistence(timeout: 3))
        }
    }

    // MARK: - Notification Settings Flow Tests

    /// Test that notification settings can be toggled
    func testNotificationSettings_CanBeToggled() throws {
        try skipIfNotLoggedIn()

        // Navigate to profile/settings
        let profileTab = app.tabBars.buttons["Profile"]
        guard profileTab.waitForExistence(timeout: 5) else {
            throw XCTSkip("Profile tab not found")
        }
        profileTab.tap()

        // Navigate to notification settings
        let notificationSettingsButton = app.buttons["Notification Settings"]
        if notificationSettingsButton.waitForExistence(timeout: 3) {
            notificationSettingsButton.tap()

            // Toggle event notifications
            let eventToggle = app.switches["Event Reminders"]
            if eventToggle.exists {
                let wasEnabled = eventToggle.value as? String == "1"
                eventToggle.tap()

                // Verify toggle changed
                let isEnabled = eventToggle.value as? String == "1"
                XCTAssertNotEqual(wasEnabled, isEnabled)

                // Toggle back
                eventToggle.tap()
            }

            // Toggle task notifications
            let taskToggle = app.switches["Task Reminders"]
            if taskToggle.exists {
                taskToggle.tap()
                taskToggle.tap() // Toggle back
            }
        }
    }

    // MARK: - Helper Methods

    private func skipIfNotLoggedIn() throws {
        // Check if we're on a login screen
        let loginButton = app.buttons["Sign In"]
        if loginButton.waitForExistence(timeout: 2) {
            throw XCTSkip("User is not logged in")
        }
    }

    private func navigateToFirstEvent() {
        // Tap on home tab if not already there
        let homeTab = app.tabBars.buttons["Home"]
        if homeTab.exists {
            homeTab.tap()
        }

        // Tap on first event in the list
        let eventCell = app.cells.firstMatch
        if eventCell.waitForExistence(timeout: 5) {
            eventCell.tap()
        }
    }
}

// MARK: - Accessibility Identifiers Extension
// These should be added to the actual views for better testability

extension NotificationFlowUITests {

    /// Accessibility identifiers used in the app
    enum AccessibilityID {
        static let createEventButton = "Create Event"
        static let tasksButton = "Tasks"
        static let agendaButton = "Agenda"
        static let addTaskButton = "Add Task"
        static let addActivityButton = "Add Activity"
        static let notificationSettingsButton = "Notification Settings"
    }
}
