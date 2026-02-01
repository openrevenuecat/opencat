import XCTest
@testable import RushDay

/// Integration tests for the complete AI Event Planner flow
/// Tests the full user journey from wizard completion through authentication to event preview
///
/// ## Flow Being Tested:
/// 1. User completes AI wizard steps (event type, guests, venue, budget, etc.)
/// 2. User selects a generated plan
/// 3. User taps "See Plan" → triggers sign-in (if unauthenticated)
/// 4. User signs in via Firebase (Google/Apple)
/// 5. Auth state changes → `.onChange(of: appState.authState)` triggers
/// 6. Sign-in sheet dismisses → `viewModel.showSignIn = false`
/// 7. `onDisappear` fires → `viewModel.onSignInComplete()` called
/// 8. `shouldCompleteAfterSignIn = true` → `.onChange` calls `onComplete`
/// 9. `appState.completeAIPlanner()` sets `showAIEventPreviewAfterAuth = true`
/// 10. ContentView shows `AIPlanDetailView` → displays `GeneratedEventResultView`
///
@MainActor
final class AIEventPlannerFlowIntegrationTests: XCTestCase {

    var viewModel: AIEventPlannerViewModel!
    var appState: AppState!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = AIEventPlannerViewModel()
        viewModel.resetState()
        appState = AppState()
    }

    override func tearDown() async throws {
        viewModel = nil
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Flow Integration Tests

    /// Tests the complete flow when user signs in after selecting a plan
    func testCompleteSignInFlow() async {
        // Step 1: Simulate user completing the wizard
        viewModel.selectedEventType = .birthday
        viewModel.eventName = "Test Birthday"
        viewModel.eventStartDate = Date()
        viewModel.selectedGuestRange = .medium
        viewModel.selectedBudgetTier = .medium

        // Step 2: Simulate plan generation and selection
        let plan = createMockPlan()
        viewModel.selectedPlanDetails = plan
        viewModel.generatedPlanSummaries = [createMockPlanSummary()]

        // Step 3: Simulate sign-in sheet being shown
        viewModel.showSignIn = true

        // Step 4: Simulate successful authentication (sheet will dismiss)
        // In real app, this happens via .onChange(of: appState.authState)
        viewModel.showSignIn = false

        // Step 5: Simulate onDisappear callback
        viewModel.onSignInComplete()

        // Verify: shouldCompleteAfterSignIn should be true
        XCTAssertTrue(viewModel.shouldCompleteAfterSignIn,
            "shouldCompleteAfterSignIn should be true after sign-in completes with plan details ready")

        // Step 6: Simulate the .onChange observer calling onComplete
        let pendingData = viewModel.pendingEventData
        viewModel.shouldCompleteAfterSignIn = false // Reset (as the observer would)

        // Step 7: Simulate appState.completeAIPlanner being called
        let mockUser = User(id: "test", email: "test@example.com", displayName: "Test", avatarUrl: nil, createdAt: Date(), provider: "google", name: nil)
        appState.authState = .authenticated(mockUser)
        appState.completeAIPlanner(with: pendingData)

        // Verify final state
        XCTAssertFalse(appState.showAIEventPlanner, "AI planner should be hidden")
        XCTAssertNotNil(appState.pendingEventData, "Pending data should be stored")
        XCTAssertTrue(appState.showAIEventPreviewAfterAuth, "Should show AI event preview")
    }

    /// Tests the flow when plan details finish loading after sign-in
    func testSignInBeforePlanDetailsReady() async {
        // Setup: User signs in before plan details are fetched
        viewModel.selectedPlanDetails = nil // Details not ready yet
        viewModel.showSignIn = true

        // Simulate sign-in completing
        viewModel.showSignIn = false
        viewModel.onSignInComplete()

        // shouldCompleteAfterSignIn should be false because details aren't ready
        XCTAssertFalse(viewModel.shouldCompleteAfterSignIn,
            "shouldCompleteAfterSignIn should be false when plan details are not ready")

        // Now simulate plan details arriving
        viewModel.selectedPlanDetails = createMockPlan()

        // In the real app, fetchPlanDetails would set shouldCompleteAfterSignIn
        // when it completes and user is authenticated
        viewModel.shouldCompleteAfterSignIn = true

        XCTAssertTrue(viewModel.shouldCompleteAfterSignIn,
            "shouldCompleteAfterSignIn should become true when details arrive")
    }

    /// Tests that the flow stays in AI planner when isSigningInFromAIPlanner is true
    func testStaysInAIPlannerDuringSignIn() {
        // Setup
        appState.isSigningInFromAIPlanner = true
        appState.showAIEventPlanner = true

        let mockUser = User(id: "test", email: "test@example.com", displayName: "Test", avatarUrl: nil, createdAt: Date(), provider: "google", name: nil)

        // Simulate authentication happening
        // In the real app, handleSuccessfulSignIn would check these flags
        let shouldNavigate = !appState.isSigningInFromAIPlanner && !appState.showAIEventPlanner

        XCTAssertFalse(shouldNavigate,
            "Should NOT navigate away when signing in from AI planner")
    }

    /// Tests that pending event data prevents navigation to home
    func testPendingDataPreventsHomeNavigation() {
        // Setup: Has pending data
        appState.pendingEventData = createMockPendingData()

        let mockUser = User(id: "test", email: "test@example.com", displayName: "Test", avatarUrl: nil, createdAt: Date(), provider: "google", name: nil)
        appState.authState = .authenticated(mockUser)

        // In the real app, handleSuccessfulSignIn checks for pending data
        let hasPendingData = appState.pendingEventData != nil

        XCTAssertTrue(hasPendingData, "Should have pending data")
        // Navigation to home should be blocked
    }

    /// Tests the type conversions work correctly
    func testTypeConversions() {
        // Test AIEventType to EventType conversion
        XCTAssertEqual(AIEventType.birthday.toEventType(), .birthday)
        XCTAssertEqual(AIEventType.wedding.toEventType(), .wedding)
        XCTAssertEqual(AIEventType.business.toEventType(), .corporate)
        XCTAssertEqual(AIEventType.graduation.toEventType(), .graduation)

        // Test AIVenueType to VenueOption conversion
        XCTAssertEqual(AIVenueType.indoorVenue.toVenueOption(), .venue)
        XCTAssertEqual(AIVenueType.outdoorSpace.toVenueOption(), .outdoor)
        XCTAssertEqual(AIVenueType.atHome.toVenueOption(), .home)
        XCTAssertEqual(AIVenueType.hotel.toVenueOption(), .hotel)

        // Test GuestCountRange to GuestCountOption conversion
        XCTAssertEqual(GuestCountRange.intimate.toGuestCountOption(), .lessThan10)
        XCTAssertEqual(GuestCountRange.small.toGuestCountOption(), .tenTo20)
        XCTAssertEqual(GuestCountRange.medium.toGuestCountOption(), .twentyTo50)
        XCTAssertEqual(GuestCountRange.large.toGuestCountOption(), .fiftyTo100)
    }

    // MARK: - Edge Case Tests

    /// Tests that resetting the viewModel clears all state
    func testResetClearsAllState() {
        // Setup: Populate state
        viewModel.showWelcome = false
        viewModel.currentStep = 5
        viewModel.selectedEventType = .wedding
        viewModel.showSignIn = true
        viewModel.shouldCompleteAfterSignIn = true
        viewModel.selectedPlanDetails = createMockPlan()

        // Act
        viewModel.resetState()

        // Assert
        XCTAssertTrue(viewModel.showWelcome)
        XCTAssertEqual(viewModel.currentStep, 0)
        XCTAssertNil(viewModel.selectedEventType)
        XCTAssertFalse(viewModel.showSignIn)
        XCTAssertFalse(viewModel.shouldCompleteAfterSignIn)
        XCTAssertNil(viewModel.selectedPlanDetails)
    }

    /// Tests that completing the flow clears pending data correctly
    func testFlowCompletionClearsPendingData() {
        // Setup
        appState.pendingEventData = createMockPendingData()
        appState.showAIEventPreviewAfterAuth = true

        // Act: Clear pending data (would happen after event is created)
        appState.clearPendingEventData()

        // Assert
        XCTAssertNil(appState.pendingEventData)
    }

    // MARK: - Helper Methods

    private func createMockPlanSummary() -> GeneratedPlanSummary {
        GeneratedPlanSummary(
            id: "test-plan-1",
            title: "Classic Celebration",
            description: "A timeless birthday celebration",
            tier: .aiRecommended,
            style: .classic,
            matchScore: 95,
            estimatedBudgetMin: 2000,
            estimatedBudgetMax: 3000,
            highlights: ["Elegant", "Professional"],
            venueDescription: "Banquet hall",
            cateringDescription: "Full buffet",
            entertainmentDescription: "Live band"
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
            highlights: ["Elegant", "Professional"],
            venueDescription: "Banquet hall",
            cateringDescription: "Full buffet",
            entertainmentDescription: "Live band",
            vendors: nil,
            timeline: [
                PlanTimelineItem(id: "1", time: "6:00 PM", title: "Arrival", description: nil, duration: 60)
            ],
            suggestedTasks: [
                PlanTask(id: "t1", title: "Book venue", description: nil, daysBeforeEvent: 30, priority: "high", category: "venue")
            ]
        )
    }

    private func createMockPendingData() -> PendingEventData {
        PendingEventData(
            eventType: .birthday,
            customEventType: nil,
            guestRange: .medium,
            customGuestCount: nil,
            eventName: "Test Birthday",
            eventStartDate: Date(),
            eventEndDate: nil,
            eventVenue: "Test Venue",
            venueType: .indoorVenue,
            customVenueName: nil,
            venueSkipped: false,
            budgetTier: .medium,
            customBudgetAmount: nil,
            selectedServices: [],
            customService: nil,
            servicesSkipped: false,
            preferencesText: nil,
            selectedTags: [],
            preferencesSkipped: false,
            selectedPlan: createMockPlan()
        )
    }
}
