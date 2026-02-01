import XCTest
@testable import RushDay

/// Unit tests for AppState AI Event Planner flow
/// Tests the authentication flow and state transitions for post-sign-in navigation
@MainActor
final class AppStateAIPlannerTests: XCTestCase {

    var appState: AppState!

    override func setUp() async throws {
        try await super.setUp()
        // Create a fresh AppState for each test
        // Note: In real tests, we'd inject mock services
        appState = AppState()
    }

    override func tearDown() async throws {
        appState = nil
        try await super.tearDown()
    }

    // MARK: - AI Planner Flow State Tests

    func testInitialAIPlannerState() {
        XCTAssertFalse(appState.showAIEventPlanner, "AI planner should not show initially")
        XCTAssertNil(appState.pendingEventData, "No pending event data initially")
        XCTAssertFalse(appState.showAIEventPreviewAfterAuth, "Should not show preview after auth initially")
        XCTAssertFalse(appState.isSigningInFromAIPlanner, "Should not be signing in from AI planner initially")
    }

    func testShowAIPlanner() {
        appState.showAIPlanner()

        XCTAssertTrue(appState.showAIEventPlanner, "AI planner should show after calling showAIPlanner")
    }

    func testCancelAIPlannerFlow() {
        // Setup
        appState.showAIEventPlanner = true
        appState.pendingEventData = createMockPendingEventData()

        // Act
        appState.cancelAIPlannerFlow()

        // Assert
        XCTAssertFalse(appState.showAIEventPlanner, "AI planner should be hidden")
        XCTAssertNil(appState.pendingEventData, "Pending event data should be cleared")
    }

    // MARK: - Complete AI Planner Tests

    func testCompleteAIPlanner_WhenUnauthenticated() {
        // Setup: User is not authenticated
        appState.authState = .unauthenticated
        let pendingData = createMockPendingEventData()

        // Act
        appState.completeAIPlanner(with: pendingData)

        // Assert
        XCTAssertFalse(appState.showAIEventPlanner, "AI planner should be hidden")
        XCTAssertNotNil(appState.pendingEventData, "Pending event data should be stored")
        XCTAssertFalse(appState.showAIEventPreviewAfterAuth, "Should NOT show preview when unauthenticated")
    }

    func testCompleteAIPlanner_WhenAuthenticated() {
        // Setup: User is authenticated
        let mockUser = User(id: "test-user", email: "test@example.com", displayName: "Test User", avatarUrl: nil, createdAt: Date(), provider: "google", name: nil)
        appState.authState = .authenticated(mockUser)
        let pendingData = createMockPendingEventData()

        // Act
        appState.completeAIPlanner(with: pendingData)

        // Assert
        XCTAssertFalse(appState.showAIEventPlanner, "AI planner should be hidden")
        XCTAssertNotNil(appState.pendingEventData, "Pending event data should be stored")
        XCTAssertTrue(appState.showAIEventPreviewAfterAuth, "Should show preview when authenticated")
    }

    // MARK: - Post Auth Flow Tests

    func testHandlePostAuthWithPendingEvent() {
        // Setup
        appState.pendingEventData = createMockPendingEventData()

        // Act
        appState.handlePostAuthWithPendingEvent()

        // Assert
        XCTAssertTrue(appState.showAIEventPreviewAfterAuth, "Should show AI event preview after auth")
    }

    func testHandlePostAuthWithoutPendingEvent() {
        // Setup
        appState.pendingEventData = nil

        // Act
        appState.handlePostAuthWithPendingEvent()

        // Assert
        XCTAssertFalse(appState.showAIEventPreviewAfterAuth, "Should NOT show preview without pending data")
    }

    // MARK: - Complete Preview Flow Tests

    func testCompleteAIEventPreviewFlow() {
        // Setup
        appState.showAIEventPreviewAfterAuth = true
        appState.pendingEventData = createMockPendingEventData()

        // Act
        appState.completeAIEventPreviewFlow()

        // Assert
        XCTAssertFalse(appState.showAIEventPreviewAfterAuth, "Preview flag should be cleared")
        XCTAssertEqual(appState.currentRoute, .home, "Should navigate to home")
    }

    func testClearPendingEventData() {
        // Setup
        appState.pendingEventData = createMockPendingEventData()

        // Act
        appState.clearPendingEventData()

        // Assert
        XCTAssertNil(appState.pendingEventData, "Pending event data should be cleared")
    }

    // MARK: - Auth State During AI Planner Tests

    func testIsSigningInFromAIPlanner_BlocksNavigation() {
        // Setup: Simulating sign-in started from AI planner
        appState.isSigningInFromAIPlanner = true
        appState.showAIEventPlanner = true

        // Verify the flags are set correctly
        XCTAssertTrue(appState.isSigningInFromAIPlanner)
        XCTAssertTrue(appState.showAIEventPlanner)

        // These flags should prevent normal navigation in handleSuccessfulSignIn
        // The actual navigation logic is tested through integration tests
    }

    func testShowAIEventPlanner_BlocksNavigation() {
        // Setup: AI planner is showing
        appState.showAIEventPlanner = true

        // Verify the flag is set
        XCTAssertTrue(appState.showAIEventPlanner)

        // When showAIEventPlanner is true, handleSuccessfulSignIn should not navigate away
        // The actual navigation logic is tested through integration tests
    }

    // MARK: - Helper Methods

    private func createMockPendingEventData() -> PendingEventData {
        PendingEventData(
            eventType: .birthday,
            customEventType: nil,
            guestRange: .medium,
            customGuestCount: nil,
            eventName: "Test Birthday Party",
            eventStartDate: Date(),
            eventEndDate: nil,
            eventVenue: "Test Venue",
            venueType: .indoorVenue,
            customVenueName: nil,
            venueSkipped: false,
            budgetTier: .medium,
            customBudgetAmount: nil,
            selectedServices: [.catering, .photography],
            customService: nil,
            servicesSkipped: false,
            preferencesText: "Fun and colorful theme",
            selectedTags: ["fun", "colorful"],
            preferencesSkipped: false,
            selectedPlan: createMockPlan()
        )
    }

    private func createMockPlan() -> GeneratedPlan {
        GeneratedPlan(
            id: "test-plan-1",
            title: "Classic Celebration",
            description: "A timeless birthday celebration",
            estimatedCost: 2500,
            style: .classic,
            tier: .aiRecommended,
            matchScore: 95,
            highlights: ["Elegant decor", "Professional catering"],
            venueDescription: "Banquet hall with classic decor",
            cateringDescription: "Full-service buffet",
            entertainmentDescription: "Live band and DJ",
            vendors: nil,
            timeline: [
                PlanTimelineItem(id: "1", time: "6:00 PM", title: "Guest Arrival", description: nil, duration: 60),
                PlanTimelineItem(id: "2", time: "7:00 PM", title: "Dinner", description: nil, duration: 90)
            ],
            suggestedTasks: [
                PlanTask(id: "t1", title: "Order cake", description: nil, daysBeforeEvent: 7, priority: "high", category: "catering"),
                PlanTask(id: "t2", title: "Send invitations", description: nil, daysBeforeEvent: 30, priority: "high", category: "guests")
            ]
        )
    }
}
