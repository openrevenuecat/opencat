import SwiftUI

// MARK: - AI Event Planner View

struct AIEventPlannerView: View {
    @ObservedObject private var viewModel = AIEventPlannerViewModel.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Called when the user completes the wizard and selects a plan
    /// Returns the pending event data for the parent to handle
    let onComplete: (PendingEventData) -> Void

    /// Called when the user dismisses the wizard
    var onDismiss: (() -> Void)?

    /// Whether to show a close button (true when opened from home by authenticated user)
    var showCloseButton: Bool = false

    /// Whether to skip the welcome screen and go directly to event type selection
    var skipWelcome: Bool = false

    var body: some View {
        ZStack {
            // Background
            WizardBackground()

            // Content
            VStack(spacing: 0) {
                // Navigation bar (when not on welcome screen)
                if !viewModel.showWelcome && !viewModel.isGenerating && !viewModel.showResults {
                    navigationBar
                }

                // Main content
                if viewModel.showWelcome {
                    welcomeView
                } else if viewModel.isGenerating {
                    generatingView
                } else if viewModel.showResults {
                    resultsView
                } else {
                    stepContent
                }
            }


            // Loading overlay (if needed for future use)
            if viewModel.showResults && viewModel.isLoading && viewModel.activeSheetType == nil {
                loadingOverlay
            }

            // Calendar picker overlay - covers entire screen including header
            if viewModel.showCalendarPickerOverlay {
                calendarPickerOverlay
            }

            // Time picker overlay - covers entire screen including header
            if viewModel.showTimePickerOverlay {
                timePickerOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if skipWelcome && viewModel.showWelcome {
                viewModel.startPlanning()
            }
        }
        // Sync showSignIn to activeSheetType for sheet presentation
        .onChange(of: viewModel.showSignIn) { _, show in
            if show {
                viewModel.activeSheetType = .signIn
            } else if viewModel.activeSheetType == .signIn {
                viewModel.activeSheetType = nil
            }
        }
        // When plan details are ready, complete the wizard and navigate to AIPlanDetailView
        .onChange(of: viewModel.showPlanDetail) { _, show in
            if show && viewModel.selectedPlanDetails != nil {
                // Clean up sign-in state
                viewModel.hasAuthenticatedInSheet = false
                viewModel.showSignIn = false
                viewModel.activeSheetType = nil
                appState.isSigningInFromAIPlanner = false
                // Complete the wizard - this triggers AIPlanDetailView in ContentView
                onComplete(viewModel.pendingEventData)
            }
        }
        // Sign-in full screen presentation (not modal sheet)
        .fullScreenCover(item: $viewModel.activeSheetType) { sheet in
            switch sheet {
            case .signIn:
                // Show loading view if authenticated but waiting for plan details
                if viewModel.hasAuthenticatedInSheet {
                    signInLoadingView
                } else {
                    AuthView()
                        .environmentObject(appState)
                        .onAppear {
                            appState.isSigningInFromAIPlanner = true
                            viewModel.hasAuthenticatedInSheet = false
                        }
                }
            case .planDetail:
                // Not used - we navigate to AIPlanDetailView instead
                EmptyView()
            }
        }
        // Handle sheet dismissal without completing sign-in (user swiped down)
        .onChange(of: viewModel.activeSheetType) { _, newValue in
            if newValue == nil && !viewModel.hasAuthenticatedInSheet {
                // Sheet was dismissed without completing sign-in - reset state
                viewModel.showSignIn = false
                viewModel.isLoading = false
                viewModel.selectedPlanDetails = nil
                appState.isSigningInFromAIPlanner = false
            }
        }
        // Use onReceive for reliable @Published observation across view recreations
        .onReceive(appState.$authState) { newState in
            // Only handle auth changes when sign-in sheet is open and not already authenticated
            guard viewModel.activeSheetType == .signIn && !viewModel.hasAuthenticatedInSheet else { return }

            if case .authenticated = newState {
                viewModel.hasAuthenticatedInSheet = true

                // Dismiss sign-in sheet - go back to Results screen
                // The card will show loading state while details are being fetched
                viewModel.showSignIn = false
                viewModel.activeSheetType = nil
                appState.isSigningInFromAIPlanner = false

                // If details already fetched, complete immediately
                // Otherwise, fetchPlanDetails (running in background) will set shouldCompleteAfterSignIn when done
                if viewModel.selectedPlanDetails != nil {
                    onComplete(viewModel.pendingEventData)
                }
                // Note: If details not ready yet, the existing .onChange(of: shouldCompleteAfterSignIn)
                // will trigger onComplete when fetchPlanDetails completes
            }
        }
        // When shouldCompleteAfterSignIn is set (from fetchPlanDetails after auth), trigger completion
        .onChange(of: viewModel.shouldCompleteAfterSignIn) { _, shouldComplete in
            if shouldComplete, viewModel.selectedPlanDetails != nil {
                viewModel.shouldCompleteAfterSignIn = false
                // Clean up sign-in state
                viewModel.hasAuthenticatedInSheet = false
                viewModel.showSignIn = false
                viewModel.activeSheetType = nil
                appState.isSigningInFromAIPlanner = false
                // Complete the wizard - this triggers AIPlanDetailView in ContentView
                onComplete(viewModel.pendingEventData)
            }
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        WizardProgressBar(
            currentStep: viewModel.currentStep,
            totalSteps: viewModel.totalSteps
        )
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        WelcomeStepView(onStart: {
            viewModel.startPlanning()
        })
    }

    // MARK: - Step Content

    private var stepContent: some View {
        Group {
            switch viewModel.currentStep {
            case 0:
                EventTypeStepView(
                    selectedEventType: $viewModel.selectedEventType,
                    customEventType: $viewModel.customEventType,
                    onContinue: { viewModel.nextStep() },
                    // When showCloseButton is true (opened from home), provide dismiss action
                    // Otherwise, only show back on step > 0
                    onBack: showCloseButton ? {
                        viewModel.reset()
                        onDismiss?()
                    } : nil
                )

            case 1:
                GuestCountStepView(
                    selectedRange: $viewModel.selectedGuestRange,
                    customCount: $viewModel.customGuestCount,
                    onContinue: { viewModel.nextStep() },
                    onBack: { viewModel.previousStep() }
                )

            case 2:
                EventDetailsStepView(
                    eventName: $viewModel.eventName,
                    startDate: $viewModel.eventStartDate,
                    endDate: $viewModel.eventEndDate,
                    venue: $viewModel.eventVenue,
                    eventTypeName: viewModel.selectedEventType?.title ?? (viewModel.customEventType.isEmpty ? nil : viewModel.customEventType),
                    onContinue: { viewModel.nextStep() },
                    onBack: { viewModel.previousStep() }
                )

            case 3:
                VenueTypeStepView(
                    selectedVenueType: $viewModel.selectedVenueType,
                    customVenueName: $viewModel.customVenueName,
                    onContinue: { viewModel.nextStep() },
                    onSkip: { viewModel.skipCurrentStep() },
                    onBack: { viewModel.previousStep() }
                )

            case 4:
                BudgetStepView(
                    selectedTier: $viewModel.selectedBudgetTier,
                    customAmount: $viewModel.customBudgetAmount,
                    onContinue: { viewModel.nextStep() },
                    onBack: { viewModel.previousStep() }
                )

            case 5:
                ServicesStepView(
                    selectedServices: $viewModel.selectedServices,
                    customService: $viewModel.customService,
                    onContinue: { viewModel.nextStep() },
                    onSkip: { viewModel.skipCurrentStep() },
                    onBack: { viewModel.previousStep() }
                )

            case 6:
                PreferencesStepView(
                    preferencesText: $viewModel.preferencesText,
                    selectedTags: $viewModel.selectedTags,
                    onGenerate: { viewModel.nextStep() },
                    onSkip: { viewModel.skipCurrentStep() },
                    onBack: { viewModel.previousStep() }
                )

            default:
                EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - Generating View

    private var generatingView: some View {
        GeneratingStepView(
            currentStep: $viewModel.generationStep,
            progress: $viewModel.generationPercentage,
            isComplete: $viewModel.generationComplete,
            eventType: viewModel.selectedEventType?.title ?? viewModel.customEventType,
            guestCount: generatingGuestCountValue,
            budget: generatingBudgetValue
        )
    }

    /// Guest count value for the generating view - derived from wizard selections
    private var generatingGuestCountValue: String {
        if let range = viewModel.selectedGuestRange {
            return range.range
        } else if let customCount = viewModel.customGuestCount {
            return "\(customCount)"
        }
        return "—" // Fallback (should never be reached - user must select before proceeding)
    }

    /// Budget value for the generating view - derived from wizard selections
    private var generatingBudgetValue: String {
        if let customAmount = viewModel.customBudgetAmount {
            return formatBudget(customAmount)
        } else if let tier = viewModel.selectedBudgetTier {
            return formatBudget(tier.minAmount)
        }
        return "—" // Fallback (should never be reached - user must select before proceeding)
    }

    private func formatBudget(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    // MARK: - Results View

    private var resultsView: some View {
        ResultsStepView(
            plans: viewModel.generatedPlans,
            selectedPlan: $viewModel.selectedPlanDetails,
            isLoading: viewModel.isLoading,
            eventTypeValue: resultsEventTypeValue,
            guestCountValue: resultsGuestCountValue,
            venueValue: resultsVenueValue,
            budgetValue: resultsBudgetValue,
            onSelectPlan: { plan in
                // Select plan and continue - no fetch needed, plan already has tasks
                viewModel.selectPlanAndContinue(plan)
            },
            onCreateEvent: {
                // Complete the wizard with the selected plan
                onComplete(viewModel.pendingEventData)
            },
            onGenerateMore: { adjustment in
                viewModel.regenerateWithAdjustment(adjustment)
            },
            onBack: {
                // Go back to preferences step
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.showResults = false
                    viewModel.currentStep = 6 // Preferences step
                }
            },
            onChangeParameter: { paramType in
                // Navigate to specific step based on parameter type
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.showResults = false
                    switch paramType {
                    case .eventType:
                        viewModel.currentStep = 0
                    case .guestCount:
                        viewModel.currentStep = 1
                    case .venue:
                        viewModel.currentStep = 3
                    case .budget:
                        viewModel.currentStep = 4
                    case .services:
                        viewModel.currentStep = 5
                    case .preferences:
                        viewModel.currentStep = 6
                    }
                }
            }
        )
    }

    // MARK: - Results Parameter Values (from wizard steps)

    private var resultsEventTypeValue: String? {
        if let eventType = viewModel.selectedEventType {
            return eventType.title
        } else if !viewModel.customEventType.isEmpty {
            return viewModel.customEventType
        }
        return nil
    }

    private var resultsGuestCountValue: String? {
        if let guestRange = viewModel.selectedGuestRange {
            return guestRange.range
        } else if let customCount = viewModel.customGuestCount {
            return "\(customCount)"
        }
        return nil
    }

    private var resultsVenueValue: String? {
        if let venueType = viewModel.selectedVenueType {
            return venueType.title
        } else if !viewModel.customVenueName.isEmpty {
            return viewModel.customVenueName
        } else if viewModel.venueSkipped {
            return "Skipped"
        }
        return nil
    }

    private var resultsBudgetValue: String? {
        if let budgetTier = viewModel.selectedBudgetTier {
            return budgetTier.title
        } else if let customAmount = viewModel.customBudgetAmount {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: customAmount)) ?? "$\(customAmount)"
        }
        return nil
    }

    // MARK: - Sign-In Loading View

    private var signInLoadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Loading animation
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "8251EB")))
                    .scaleEffect(1.5)

                Text("Preparing your plan...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Just a moment while we load the details")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("Loading your plan...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "1F2937").opacity(0.95))
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    // MARK: - Calendar Picker Overlay (Full Screen)

    private var calendarPickerOverlay: some View {
        ZStack {
            // Dimmed background - covers entire screen including status bar
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.dismissCalendarPicker()
                }

            // Custom calendar picker - centered
            // Use custom binding to call callback immediately when date changes (including month navigation)
            CustomCalendarPicker(
                selectedDate: Binding(
                    get: { viewModel.calendarPickerDate },
                    set: { newDate in
                        viewModel.calendarPickerDate = newDate
                        // Call the callback immediately when date changes
                        viewModel.calendarPickerOnSelect?(newDate)
                    }
                ),
                minimumDate: viewModel.calendarPickerMinDate,
                rangeStartDate: viewModel.calendarPickerRangeStartDate,
                rangeEndDate: viewModel.calendarPickerRangeEndDate,
                onDismiss: {
                    viewModel.dismissCalendarPicker()
                }
            )
        }
    }

    // MARK: - Time Picker Overlay (Full Screen)

    private var timePickerOverlay: some View {
        ZStack {
            // Dimmed background - covers entire screen including status bar
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.timePickerOnSelect?(viewModel.calendarPickerDate)
                    viewModel.dismissTimePicker()
                }

            // Time picker card - centered
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: $viewModel.calendarPickerDate,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 200)
            }
            .padding(16)
            .frame(width: 280)
            .background(colorScheme == .dark ? Color(hex: "2C2C2E") : .white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "F3F3F4"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 3)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.04), radius: 32, x: 0, y: 32)
            .shadow(color: Color.black.opacity(0.04), radius: 64, x: 0, y: 64)
        }
    }

}

// MARK: - Sheet Presentation Modifier

extension View {
    func aiEventPlannerSheet(
        isPresented: Binding<Bool>,
        showCloseButton: Bool = false,
        onComplete: @escaping (PendingEventData) -> Void
    ) -> some View {
        self.fullScreenCover(isPresented: isPresented) {
            AIEventPlannerView(
                onComplete: { data in
                    isPresented.wrappedValue = false
                    onComplete(data)
                },
                onDismiss: {
                    isPresented.wrappedValue = false
                },
                showCloseButton: showCloseButton
            )
        }
    }
}

// MARK: - Preview

#Preview("AI Event Planner View") {
    AIEventPlannerView(
        onComplete: { _ in }
    )
}

#Preview("AI Event Planner - Step 1") {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = AIEventPlannerViewModel()

        var body: some View {
            ZStack {
                WizardBackground()

                EventTypeStepView(
                    selectedEventType: $viewModel.selectedEventType,
                    customEventType: $viewModel.customEventType,
                    onContinue: {}
                )
            }
            .onAppear {
                viewModel.showWelcome = false
            }
        }
    }

    return PreviewWrapper()
}
