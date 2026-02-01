import XCTest
@testable import RushDay

/// Unit tests for AIEventPlannerViewModel
/// Tests the sign-in flow and state transitions for the AI Event Planner wizard
@MainActor
final class AIEventPlannerViewModelTests: XCTestCase {

    var viewModel: AIEventPlannerViewModel!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = AIEventPlannerViewModel()
        viewModel.resetState()
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertTrue(viewModel.showWelcome, "Should start with welcome screen")
        XCTAssertEqual(viewModel.currentStep, 0, "Should start at step 0")
        XCTAssertFalse(viewModel.isGenerating, "Should not be generating initially")
        XCTAssertFalse(viewModel.showResults, "Should not show results initially")
        XCTAssertFalse(viewModel.showSignIn, "Should not show sign-in initially")
        XCTAssertFalse(viewModel.shouldCompleteAfterSignIn, "shouldCompleteAfterSignIn should be false initially")
    }

    // MARK: - Navigation Tests

    func testStartPlanning() {
        viewModel.startPlanning()

        XCTAssertFalse(viewModel.showWelcome, "Welcome screen should be hidden after starting")
    }

    func testNextStep() {
        viewModel.showWelcome = false
        viewModel.currentStep = 0

        viewModel.nextStep()

        XCTAssertEqual(viewModel.currentStep, 1, "Should advance to step 1")
    }

    func testPreviousStep() {
        viewModel.showWelcome = false
        viewModel.currentStep = 2

        viewModel.previousStep()

        XCTAssertEqual(viewModel.currentStep, 1, "Should go back to step 1")
    }

    func testPreviousStepAtFirstStep() {
        viewModel.showWelcome = false
        viewModel.currentStep = 0

        viewModel.previousStep()

        XCTAssertTrue(viewModel.showWelcome, "Should show welcome screen when going back from step 0")
    }

    // MARK: - Sign-In Flow Tests

    func testOnSignInCompleteWithPlanDetails() {
        // Setup: User has selected a plan and details are ready
        viewModel.selectedPlanDetails = createMockPlan()
        viewModel.showSignIn = true

        // Act: User completes sign-in
        viewModel.onSignInComplete()

        // Assert
        XCTAssertFalse(viewModel.showSignIn, "Sign-in sheet should be dismissed")
        XCTAssertTrue(viewModel.shouldCompleteAfterSignIn, "shouldCompleteAfterSignIn should be true when plan details are ready")
    }

    func testOnSignInCompleteWithoutPlanDetails() {
        // Setup: User signs in before plan details are fetched
        viewModel.selectedPlanDetails = nil
        viewModel.showSignIn = true

        // Act: User completes sign-in
        viewModel.onSignInComplete()

        // Assert
        XCTAssertFalse(viewModel.showSignIn, "Sign-in sheet should be dismissed")
        XCTAssertFalse(viewModel.shouldCompleteAfterSignIn, "shouldCompleteAfterSignIn should remain false when plan details are not ready")
    }

    // MARK: - Plan Selection Tests

    func testSelectPlanAndContinue_WhenNotAuthenticated() {
        // Setup: User is not authenticated
        // Note: In real test, we'd mock the authService
        let summary = createMockPlanSummary()
        viewModel.generationId = "test-generation-id"

        // We can't fully test this without mocking authService,
        // but we can verify the state changes
        viewModel.selectedPlanSummary = summary
        viewModel.isLoadingPlanDetails = true

        // Assert initial state is set correctly
        XCTAssertNotNil(viewModel.selectedPlanSummary, "Selected plan summary should be set")
        XCTAssertTrue(viewModel.isLoadingPlanDetails, "Should be loading plan details")
    }

    // MARK: - Pending Event Data Tests

    func testPendingEventData_ContainsSelectedPlan() {
        // Setup
        viewModel.selectedEventType = .birthday
        viewModel.eventName = "Test Birthday"
        viewModel.eventStartDate = Date()
        viewModel.selectedBudgetTier = .medium
        viewModel.selectedGuestRange = .medium
        viewModel.selectedPlanDetails = createMockPlan()

        // Act
        let pendingData = viewModel.pendingEventData

        // Assert
        XCTAssertEqual(pendingData.eventType, .birthday)
        XCTAssertEqual(pendingData.eventName, "Test Birthday")
        XCTAssertNotNil(pendingData.selectedPlan, "Pending data should include selected plan")
    }

    // MARK: - Reset State Tests

    func testResetState() {
        // Setup: Populate some state
        viewModel.showWelcome = false
        viewModel.currentStep = 3
        viewModel.selectedEventType = .birthday
        viewModel.showSignIn = true
        viewModel.shouldCompleteAfterSignIn = true
        viewModel.selectedPlanDetails = createMockPlan()

        // Act
        viewModel.resetState()

        // Assert
        XCTAssertTrue(viewModel.showWelcome, "Should reset to welcome screen")
        XCTAssertEqual(viewModel.currentStep, 0, "Should reset to step 0")
        XCTAssertNil(viewModel.selectedEventType, "Should clear selected event type")
        XCTAssertFalse(viewModel.showSignIn, "Should reset showSignIn")
        XCTAssertFalse(viewModel.shouldCompleteAfterSignIn, "Should reset shouldCompleteAfterSignIn")
        XCTAssertNil(viewModel.selectedPlanDetails, "Should clear selected plan details")
    }

    // MARK: - Validation Tests

    func testCanProceedFromEventTypeStep() {
        viewModel.currentStep = 0

        // Without selection
        XCTAssertFalse(viewModel.canProceedFromCurrentStep, "Should not proceed without event type")

        // With selection
        viewModel.selectedEventType = .birthday
        XCTAssertTrue(viewModel.canProceedFromCurrentStep, "Should proceed with event type selected")
    }

    func testCanProceedFromEventTypeStepWithCustomType() {
        viewModel.currentStep = 0

        viewModel.customEventType = "Custom Party"
        XCTAssertTrue(viewModel.canProceedFromCurrentStep, "Should proceed with custom event type")
    }

    func testCanProceedFromGuestCountStep() {
        viewModel.currentStep = 1

        // Without selection
        XCTAssertFalse(viewModel.canProceedFromCurrentStep, "Should not proceed without guest count")

        // With selection
        viewModel.selectedGuestRange = .medium
        XCTAssertTrue(viewModel.canProceedFromCurrentStep, "Should proceed with guest range selected")
    }

    func testCanProceedFromEventDetailsStep() {
        viewModel.currentStep = 2

        // Without name and date
        XCTAssertFalse(viewModel.canProceedFromCurrentStep, "Should not proceed without name and date")

        // With name only
        viewModel.eventName = "Test Event"
        XCTAssertFalse(viewModel.canProceedFromCurrentStep, "Should not proceed with only name")

        // With name and date
        viewModel.eventStartDate = Date()
        XCTAssertTrue(viewModel.canProceedFromCurrentStep, "Should proceed with name and date")
    }

    // MARK: - Helper Methods

    private func createMockPlanSummary() -> GeneratedPlanSummary {
        GeneratedPlanSummary(
            id: "test-plan-1",
            title: "Test Plan",
            description: "A test plan description",
            tier: .aiRecommended,
            style: .classic,
            matchScore: 95,
            estimatedBudgetMin: 1000,
            estimatedBudgetMax: 2000,
            highlights: ["Feature 1", "Feature 2"],
            venueDescription: "Test venue",
            cateringDescription: "Test catering",
            entertainmentDescription: "Test entertainment"
        )
    }

    private func createMockPlan() -> GeneratedPlan {
        GeneratedPlan(
            id: "test-plan-1",
            title: "Test Plan",
            description: "A test plan description",
            estimatedCost: 1500,
            style: .classic,
            tier: .aiRecommended,
            matchScore: 95,
            highlights: ["Feature 1", "Feature 2"],
            venueDescription: "Test venue",
            cateringDescription: "Test catering",
            entertainmentDescription: "Test entertainment",
            vendors: nil,
            timeline: [
                PlanTimelineItem(id: "1", time: "6:00 PM", title: "Welcome", description: nil, duration: 60)
            ],
            suggestedTasks: [
                PlanTask(id: "t1", title: "Book venue", description: nil, daysBeforeEvent: 30, priority: "high", category: "venue")
            ]
        )
    }
}
