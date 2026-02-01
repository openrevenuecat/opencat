import SwiftUI
import Foundation

// MARK: - Sheet Type (for ViewModel persistence)

enum AISheetType: String, Identifiable {
    case signIn
    case planDetail

    var id: String { rawValue }
}

// MARK: - Plan Variant (for parallel generation)

enum PlanVariant: Int, CaseIterable, Sendable {
    case budget = 0
    case balanced = 1
    case premium = 2

    /// Maps to proto TargetPlanStyle
    var protoStyle: Rushday_V1_TargetPlanStyle {
        switch self {
        case .budget: return .budget
        case .balanced: return .balanced
        case .premium: return .premium
        }
    }

    var displayTitle: String {
        switch self {
        case .budget: return "Budget-Friendly"
        case .balanced: return "Balanced"
        case .premium: return "Premium"
        }
    }
}

// MARK: - Generation Status (for parallel tracking)

enum GenerationStatus: Sendable {
    case pending
    case generating
    case completed
    case failed
}

// MARK: - AI Event Planner ViewModel

@MainActor
class AIEventPlannerViewModel: ObservableObject {

    // MARK: - Shared Instance
    /// Shared instance to preserve state across auth transitions
    static let shared = AIEventPlannerViewModel()

    // MARK: - Navigation State

    @Published var showWelcome: Bool = true
    @Published var currentStep: Int = 0
    @Published var isGenerating: Bool = false
    @Published var generationStep: GenerationStep = .analyzingPreferences
    @Published var generationPercentage: CGFloat = 0
    @Published var generationComplete: Bool = false
    @Published var showResults: Bool = false
    @Published var errorMessage: String?

    // MARK: - Parallel Generation Progress Tracking

    @Published var variantProgress: [PlanVariant: CGFloat] = [:]
    @Published var variantStatus: [PlanVariant: GenerationStatus] = [:]

    /// Combined progress across all parallel streams (average of all variants)
    var combinedProgress: CGFloat {
        guard !variantProgress.isEmpty else { return 0 }
        return variantProgress.values.reduce(0, +) / CGFloat(PlanVariant.allCases.count)
    }

    // MARK: - Step 1: Event Type

    @Published var selectedEventType: AIEventType?
    @Published var customEventType: String = ""

    // MARK: - Step 2: Guest Count

    @Published var selectedGuestRange: GuestCountRange?
    @Published var customGuestCount: Int?

    // MARK: - Step 3: Event Details

    @Published var eventName: String = ""
    @Published var eventStartDate: Date?
    @Published var eventEndDate: Date?
    @Published var eventVenue: String = ""
    @Published var eventIsAllDay: Bool = false

    // MARK: - Calendar/Time Picker Overlay State (for full-screen overlay)

    @Published var showCalendarPickerOverlay: Bool = false
    @Published var showTimePickerOverlay: Bool = false
    @Published var calendarPickerDate: Date = Date()
    @Published var calendarPickerMinDate: Date?
    @Published var calendarPickerOnSelect: ((Date) -> Void)?
    @Published var timePickerOnSelect: ((Date) -> Void)?
    @Published var calendarPickerRangeStartDate: Date?  // For range highlighting (when editing end date)
    @Published var calendarPickerRangeEndDate: Date?    // For range highlighting (when editing start date)

    // MARK: - Step 4: Venue Type

    @Published var selectedVenueType: AIVenueType?
    @Published var customVenueName: String = ""
    @Published var venueSkipped: Bool = false

    // MARK: - Step 5: Budget

    @Published var selectedBudgetTier: BudgetTier?
    @Published var customBudgetAmount: Int?

    // MARK: - Step 6: Services

    @Published var selectedServices: Set<ServiceType> = []
    @Published var customService: String = ""
    @Published var servicesSkipped: Bool = false

    // MARK: - Step 7: Preferences

    @Published var preferencesText: String = ""
    @Published var selectedTags: Set<String> = []
    @Published var preferencesSkipped: Bool = false

    // MARK: - Results (Full plans with tasks - no separate fetch needed)

    @Published var generatedPlans: [GeneratedPlan] = []
    @Published var selectedPlanDetails: GeneratedPlan?
    @Published var isLoading: Bool = false
    @Published var showPlanDetail: Bool = false

    // MARK: - Authentication

    /// Show sign-in sheet when user taps "See Plan" but is not authenticated
    @Published var showSignIn: Bool = false

    /// Tracks if user authenticated while sign-in sheet is open (moved from View for persistence)
    @Published var hasAuthenticatedInSheet: Bool = false

    /// Active sheet type (moved from View for persistence across auth state changes)
    @Published var activeSheetType: AISheetType?

    /// Auth service to check authentication status
    private let authService: AuthServiceProtocol = DIContainer.shared.authService

    // MARK: - Plan Detail (tasks/agenda selection)

    @Published var selectedTasks: Set<String> = []
    @Published var agendaItems: [PlanTimelineItem] = []

    // MARK: - Cover Image

    /// Random abstract cover image URL selected for this plan
    @Published var selectedCoverUrl: String?

    /// Available abstract cover images
    private let abstractCoverImages = [
        "background1.jpg",
        "background2.jpg",
        "background3.jpg",
        "background4.jpg",
        "background5.jpg"
    ]

    // MARK: - Constants

    /// Total wizard steps (0-6), not including generating/results screens
    let totalSteps = 7

    // MARK: - Computed Properties

    var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }

    var canProceedFromCurrentStep: Bool {
        switch currentStep {
        case 0: // Event Type
            return selectedEventType != nil || !customEventType.isEmpty
        case 1: // Guest Count
            return selectedGuestRange != nil || customGuestCount != nil
        case 2: // Event Details
            return !eventName.trimmingCharacters(in: .whitespaces).isEmpty && eventStartDate != nil
        case 3: // Venue Type
            return selectedVenueType != nil || !customVenueName.isEmpty || venueSkipped
        case 4: // Budget
            return selectedBudgetTier != nil || customBudgetAmount != nil
        case 5: // Services
            return !selectedServices.isEmpty || !customService.isEmpty || servicesSkipped
        case 6: // Preferences
            return true // Can always proceed from preferences
        default:
            return true
        }
    }

    // MARK: - Pending Event Data

    var pendingEventData: PendingEventData {
        PendingEventData(
            eventType: selectedEventType,
            customEventType: customEventType.isEmpty ? nil : customEventType,
            guestRange: selectedGuestRange,
            customGuestCount: customGuestCount,
            eventName: eventName.isEmpty ? nil : eventName,
            eventStartDate: eventStartDate,
            eventEndDate: eventEndDate,
            eventVenue: eventVenue.isEmpty ? nil : eventVenue,
            venueType: selectedVenueType,
            customVenueName: customVenueName.isEmpty ? nil : customVenueName,
            venueSkipped: venueSkipped,
            budgetTier: selectedBudgetTier,
            customBudgetAmount: customBudgetAmount,
            selectedServices: Array(selectedServices),
            customService: customService.isEmpty ? nil : customService,
            servicesSkipped: servicesSkipped,
            preferencesText: preferencesText.isEmpty ? nil : preferencesText,
            selectedTags: Array(selectedTags),
            preferencesSkipped: preferencesSkipped,
            selectedPlan: selectedPlanDetails,
            coverUrl: selectedCoverUrl
        )
    }

    // MARK: - Reset State

    /// Resets all state to initial values (call when flow completes or is cancelled)
    func resetState() {
        // Cancel any in-progress generation first
        cancelGeneration()

        showWelcome = true
        currentStep = 0
        isGenerating = false
        generationStep = .analyzingPreferences
        generationPercentage = 0
        generationComplete = false
        showResults = false
        errorMessage = nil

        selectedEventType = nil
        customEventType = ""
        selectedGuestRange = nil
        customGuestCount = nil
        eventName = ""
        eventStartDate = nil
        eventEndDate = nil
        eventVenue = ""
        eventIsAllDay = false
        selectedVenueType = nil
        customVenueName = ""
        venueSkipped = false
        selectedBudgetTier = nil
        customBudgetAmount = nil
        selectedServices = []
        customService = ""
        servicesSkipped = false
        preferencesText = ""
        selectedTags = []
        preferencesSkipped = false

        generatedPlans = []
        generationId = ""
        selectedPlanDetails = nil
        isLoading = false
        showPlanDetail = false
        selectedTasks = []
        agendaItems = []
        selectedCoverUrl = nil
        showSignIn = false
        shouldCompleteAfterSignIn = false
        hasAuthenticatedInSheet = false
        activeSheetType = nil

        // Reset parallel generation tracking
        variantProgress = [:]
        variantStatus = [:]

        // Reset calendar/time picker state
        showCalendarPickerOverlay = false
        showTimePickerOverlay = false
        calendarPickerDate = Date()
        calendarPickerMinDate = nil
        calendarPickerRangeStartDate = nil
        calendarPickerRangeEndDate = nil
        calendarPickerOnSelect = nil
        timePickerOnSelect = nil
    }

    // MARK: - Calendar/Time Picker Actions

    func showCalendarPicker(
        date: Date,
        minDate: Date? = nil,
        rangeStartDate: Date? = nil,
        rangeEndDate: Date? = nil,
        onSelect: @escaping (Date) -> Void
    ) {
        calendarPickerDate = date
        calendarPickerMinDate = minDate
        calendarPickerRangeStartDate = rangeStartDate
        calendarPickerRangeEndDate = rangeEndDate
        calendarPickerOnSelect = onSelect
        showCalendarPickerOverlay = true
    }

    func showTimePicker(date: Date, onSelect: @escaping (Date) -> Void) {
        calendarPickerDate = date
        timePickerOnSelect = onSelect
        showTimePickerOverlay = true
    }

    func dismissCalendarPicker() {
        showCalendarPickerOverlay = false
        calendarPickerOnSelect = nil
        calendarPickerRangeStartDate = nil
        calendarPickerRangeEndDate = nil
    }

    func dismissTimePicker() {
        showTimePickerOverlay = false
        timePickerOnSelect = nil
    }

    // MARK: - Navigation Actions

    func startPlanning() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showWelcome = false
        }
    }

    func nextStep() {
        guard currentStep < totalSteps - 1 else {
            // Last step - start generation
            startGeneration()
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
    }

    func previousStep() {
        if currentStep > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep -= 1
            }
        } else if !showWelcome {
            withAnimation(.easeInOut(duration: 0.3)) {
                showWelcome = true
            }
        }
    }

    func skipCurrentStep() {
        switch currentStep {
        case 3: // Venue Type
            venueSkipped = true
        case 5: // Services
            servicesSkipped = true
        case 6: // Preferences
            preferencesSkipped = true
        default:
            break
        }
        nextStep()
    }

    // MARK: - Generation

    /// Generation ID from the last successful generation (for caching/retrieval)
    @Published var generationId: String?

    /// Adjustment text for regeneration with modifications
    @Published var adjustmentText: String = ""

    /// Active generation task - stored to prevent orphaned streams and allow cancellation
    private var generationTask: Task<Void, Never>?

    func startGeneration() {
        // Cancel any existing generation task before starting a new one
        generationTask?.cancel()

        isGenerating = true
        generationComplete = false
        generationStep = .analyzingPreferences
        generationPercentage = 0
        errorMessage = nil

        // Reset parallel generation tracking
        variantProgress = [:]
        variantStatus = [:]

        generationTask = Task {
            await generatePlans()
        }
    }

    /// Cancel any in-progress generation (call when view disappears or user navigates away)
    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
    }

    private func generatePlans() async {
        // Stop network monitoring during generation to prevent interference with gRPC streams
        await MainActor.run { NetworkMonitor.shared.stopMonitoring() }
        defer {
            Task { @MainActor in NetworkMonitor.shared.startMonitoring() }
        }

        do {
            #if DEBUG
            print("[AIPlanner] generatePlans() started with PARALLEL generation, stopped NetworkMonitor")
            if !adjustmentText.isEmpty {
                print("[AIPlanner] ✨ Adjustment text: '\(adjustmentText)'")
            }
            #endif

            // Reset state for parallel generation
            generatedPlans = []
            variantProgress = [:]
            variantStatus = Dictionary(uniqueKeysWithValues: PlanVariant.allCases.map { ($0, GenerationStatus.pending) })

            #if DEBUG
            print("[AIPlanner] Starting 3 parallel streams for Budget, Balanced, Premium plans")
            #endif

            // Launch 3 parallel streams - one for each plan style
            try await withThrowingTaskGroup(of: (PlanVariant, GeneratedPlan?, String?).self) { group in
                for variant in PlanVariant.allCases {
                    group.addTask { [self] in
                        await MainActor.run { variantStatus[variant] = .generating }
                        let (plan, genId) = try await generateSinglePlan(variant: variant)
                        return (variant, plan, genId)
                    }
                }

                // Collect results progressively as each stream completes
                for try await (variant, plan, genId) in group {
                    if let plan = plan {
                        #if DEBUG
                        print("[AIPlanner] ✅ Variant \(variant.displayTitle) completed with plan: \(plan.id)")
                        #endif
                        generatedPlans.append(plan)
                        variantStatus[variant] = .completed
                        // Use the first generation ID we receive
                        if generationId == nil, let id = genId {
                            generationId = id
                        }
                    } else {
                        #if DEBUG
                        print("[AIPlanner] ⚠️ Variant \(variant.displayTitle) completed with no plan")
                        #endif
                        variantStatus[variant] = .failed
                    }
                }
            }

            #if DEBUG
            print("[AIPlanner] All parallel streams ended, plans count: \(generatedPlans.count)")
            #endif

            // Check if we got any plans
            if generatedPlans.isEmpty {
                throw AIEventPlannerError.noPlansGenerated
            }

            // Sort plans by variant order (budget, balanced, premium) for consistent display
            generatedPlans.sort { plan1, plan2 in
                let order1 = planVariantOrder(for: plan1)
                let order2 = planVariantOrder(for: plan2)
                return order1 < order2
            }

            // Mark generation as complete
            withAnimation(.easeInOut(duration: 0.3)) {
                generationPercentage = 1.0
            }
            generationComplete = true

            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            withAnimation(.easeInOut(duration: 0.3)) {
                isGenerating = false
                showResults = true
            }

        } catch is CancellationError {
            #if DEBUG
            print("[AIPlanner] Task cancelled")
            #endif
            // Task was cancelled (user navigated away or started new generation)
            withAnimation(.easeInOut(duration: 0.3)) {
                isGenerating = false
            }
        } catch {
            #if DEBUG
            print("[AIPlanner] Error caught: \(error)")
            #endif
            // Fall back to mock data in development
            #if DEBUG
            generatedPlans = GeneratedPlan.mockPlans
            withAnimation(.easeInOut(duration: 0.3)) {
                generationPercentage = 1.0
            }
            generationComplete = true

            try? await Task.sleep(nanoseconds: 500_000_000)

            withAnimation(.easeInOut(duration: 0.3)) {
                isGenerating = false
                showResults = true
            }
            #else
            errorMessage = error.localizedDescription
            withAnimation(.easeInOut(duration: 0.3)) {
                isGenerating = false
            }
            #endif
        }
    }

    /// Generate a single plan for a specific variant (budget/balanced/premium)
    private func generateSinglePlan(variant: PlanVariant) async throws -> (GeneratedPlan?, String?) {
        let request = pendingEventData.toGRPCRequest(
            adjustmentText: adjustmentText.isEmpty ? nil : adjustmentText,
            includeTasks: true,
            includeAgenda: false,
            includeVendors: false,
            targetPlanStyle: variant.protoStyle
        )

        var resultPlan: GeneratedPlan?
        var resultGenerationId: String?

        #if DEBUG
        print("[AIPlanner] [\(variant.displayTitle)] Starting stream...")
        #endif

        for try await response in GRPCClientService.shared.generateEventPlansStreaming(request) {
            try Task.checkCancellation()

            switch response.payload {
            case .progress(let progress):
                #if DEBUG
                print("[AIPlanner] [\(variant.displayTitle)] Progress: \(progress.percentage)%")
                #endif
                await MainActor.run {
                    variantProgress[variant] = CGFloat(progress.percentage) / 100.0
                    generationPercentage = combinedProgress

                    // Update step based on progress (use first variant's progress for step display)
                    if variant == .budget {
                        updateProgress(step: progress.step, percentage: Int(progress.percentage), message: progress.message)
                    }
                }

            case .planSummary(let grpcPlan):
                #if DEBUG
                print("[AIPlanner] [\(variant.displayTitle)] Received plan: \(grpcPlan.id) with \(grpcPlan.suggestedTasks.count) tasks")
                #endif
                resultPlan = GeneratedPlan(fromSummary: grpcPlan)

            case .complete(let complete):
                #if DEBUG
                print("[AIPlanner] [\(variant.displayTitle)] Stream complete: generationId=\(complete.generationID)")
                #endif
                resultGenerationId = complete.generationID
                await MainActor.run {
                    variantProgress[variant] = 1.0
                }

            case .error(let error):
                #if DEBUG
                print("[AIPlanner] [\(variant.displayTitle)] Stream error: \(error.message)")
                #endif
                throw AIEventPlannerError.serverError(error.message)

            case .none:
                break
            }
        }

        return (resultPlan, resultGenerationId)
    }

    /// Determine sort order based on plan tier (recommended first, then popular, then standard)
    private func planVariantOrder(for plan: GeneratedPlan) -> Int {
        // Map tiers to display order: Recommended → Popular → Standard
        switch plan.tier {
        case .aiRecommended:  // Best match - show first
            return 0
        case .popular:  // Premium option - show second
            return 1
        case .standard:  // Budget option - show last
            return 2
        }
    }

    /// Updates the generation progress based on backend messages
    private func updateProgress(step: String, percentage: Int, message: String) {
        // Update progress percentage from backend
        withAnimation(.easeInOut(duration: 0.3)) {
            generationPercentage = CGFloat(percentage) / 100.0
        }

        // Map backend step names to our GenerationStep enum
        switch step.lowercased() {
        case "analyzing", "analyzing_preferences":
            generationStep = .analyzingPreferences
        case "finding_venues", "venues":
            generationStep = .findingVenues
        case "creating_program", "program":
            generationStep = .creatingProgram
        case "calculating_budget", "budget":
            generationStep = .calculatingBudget
        case "generating", "generating_plans", "finalizing":
            generationStep = .generatingPlans
        default:
            // Keep current step if unknown
            break
        }
    }

    /// Animates through generation steps with appropriate timing
    private func animateGenerationProgress() async {
        // Step 1: Analyzing preferences
        generationStep = .analyzingPreferences
        try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds

        // Step 2: Finding venues
        generationStep = .findingVenues
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Step 3: Creating program
        generationStep = .creatingProgram
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Step 4: Calculating budget
        generationStep = .calculatingBudget
        try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds

        // Step 5: Generating plans
        generationStep = .generatingPlans
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }

    func regeneratePlans() {
        showResults = false
        generatedPlans = []
        selectedPlanDetails = nil
        generationId = nil
        startGeneration()
    }

    /// Regenerate with additional adjustment text
    func regenerateWithAdjustment(_ adjustment: String) {
        adjustmentText = adjustment
        regeneratePlans()
    }

    // MARK: - Event Creation

    /// Flag to signal that the flow should complete after sign-in
    /// The view observes this and calls onComplete
    @Published var shouldCompleteAfterSignIn: Bool = false

    /// Select a plan - no fetch needed since we already have full plan with tasks
    func selectPlanAndContinue(_ plan: GeneratedPlan) {
        // Prefetch cover image early so it's ready when plan detail view appears
        prefetchCoverImage()

        // Set the selected plan details directly (already have tasks from stream)
        selectedPlanDetails = plan
        initializePlanSelection(from: plan)

        // Check auth status
        if authService.isAuthenticated {
            // Authenticated - complete immediately
            shouldCompleteAfterSignIn = true
        } else {
            // Not authenticated - show sign-in sheet
            showSignIn = true
        }
    }

    /// Called after user successfully signs in from the sign-in sheet
    func onSignInComplete() {
        showSignIn = false

        // After sign-in, complete the wizard flow
        // The view will observe shouldCompleteAfterSignIn and call onComplete
        if selectedPlanDetails != nil {
            shouldCompleteAfterSignIn = true
        }
    }

    private func initializePlanSelection(from plan: GeneratedPlan) {
        // Initialize selected tasks and agenda from the plan
        if let tasks = plan.suggestedTasks {
            selectedTasks = Set(tasks.map { $0.id })
        }
        if let timeline = plan.timeline {
            agendaItems = timeline
        }
    }

    func removeAgendaItem(_ item: PlanTimelineItem) {
        agendaItems.removeAll { $0.id == item.id }
    }

    func goBackFromPlanDetail() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showPlanDetail = false
        }
    }

    // MARK: - Reset

    func reset() {
        // Cancel any in-progress generation first
        cancelGeneration()

        showWelcome = true
        currentStep = 0
        isGenerating = false
        generationStep = .analyzingPreferences
        generationPercentage = 0
        generationComplete = false
        showResults = false
        errorMessage = nil
        generationId = nil
        adjustmentText = ""

        // Reset plans and details
        generatedPlans = []
        selectedPlanDetails = nil
        isLoading = false
        showPlanDetail = false

        // Reset parallel generation tracking
        variantProgress = [:]
        variantStatus = [:]

        selectedEventType = nil
        customEventType = ""
        selectedGuestRange = nil
        customGuestCount = nil
        eventName = ""
        eventStartDate = nil
        eventEndDate = nil
        eventVenue = ""
        eventIsAllDay = false
        selectedVenueType = nil
        customVenueName = ""
        venueSkipped = false
        selectedBudgetTier = nil
        customBudgetAmount = nil
        selectedServices = []
        customService = ""
        servicesSkipped = false
        preferencesText = ""
        selectedTags = []
        preferencesSkipped = false
        selectedTasks = []
        agendaItems = []
    }

    // MARK: - Image Prefetching

    /// Select a random abstract cover image and prefetch it
    private func prefetchCoverImage() {
        let baseUrl = AppConfig.shared.mediaSourceUrl
        let randomImage = abstractCoverImages.randomElement() ?? "background1.jpg"
        let coverUrl = "\(baseUrl)/event_covers/abstract_covers/\(randomImage)"

        // Store the selected cover URL for later use
        selectedCoverUrl = coverUrl

        // Prefetch so it's ready when plan detail appears
        ImageCache.shared.prefetch(url: URL(string: coverUrl))
    }
}

// MARK: - Errors

enum AIEventPlannerError: Error, LocalizedError {
    case noPlansGenerated
    case serverError(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .noPlansGenerated:
            return "No plans were generated. Please try again."
        case .serverError(let message):
            return message.isEmpty ? "Server error occurred. Please try again." : message
        case .notConnected:
            return "Not connected to server. Please check your connection."
        }
    }
}
