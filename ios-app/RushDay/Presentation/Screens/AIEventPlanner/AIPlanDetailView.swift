import SwiftUI

// MARK: - AI Plan Detail View
/// Wrapper view that displays the AI-generated event plan using GeneratedEventResultView.
/// This view is shown after the user:
/// 1. Completes the AI Event Planner wizard
/// 2. Signs in (if they weren't authenticated)
///
/// It converts PendingEventData to CreateEventViewModel format and displays
/// the event preview using the existing GeneratedEventResultView component.
///
/// Design reference: Figma node 830:39009 "Create Event Event generated >1 day + expenses"
struct AIPlanDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CreateEventViewModel()
    @State private var isInitialized = false

    var body: some View {
        NavigationStack {
            GeneratedEventResultView(
                viewModel: viewModel,
                onDismiss: {
                    // Clear pending data and go to home
                    appState.clearPendingEventData()
                    appState.completeAIEventPreviewFlow()
                }
            )
        }
        .onAppear {
            if !isInitialized {
                populateViewModelFromPendingData()
                isInitialized = true

                // Create draft event in background (auth token already set by AppState)
                Task {
                    await viewModel.createDraftEventSilently()
                }
            }
        }
    }

    /// Converts PendingEventData to CreateEventViewModel format
    private func populateViewModelFromPendingData() {
        guard let pendingData = appState.pendingEventData else {
            return
        }

        // Map event type
        if let aiEventType = pendingData.eventType {
            viewModel.selectedEventType = aiEventType.toEventType()
        } else if pendingData.customEventType != nil {
            // If custom event type, use .custom
            viewModel.selectedEventType = .custom
        }
        if let customType = pendingData.customEventType {
            viewModel.customTypeName = customType
        }

        // Map basic info
        viewModel.eventName = pendingData.eventName ?? "My Event"
        viewModel.startDate = pendingData.eventStartDate ?? Date()
        viewModel.endDate = pendingData.eventEndDate
        viewModel.venue = pendingData.eventVenue ?? ""

        // Map venue
        if let venueType = pendingData.venueType {
            viewModel.selectedVenueOption = venueType.toVenueOption()
        }
        if let customVenue = pendingData.customVenueName {
            viewModel.customVenueName = customVenue
        }

        // Map budget
        if let budgetAmount = pendingData.customBudgetAmount {
            viewModel.budgetAmount = String(budgetAmount)
            // For custom budget, use the amount as both min and max
            viewModel.budgetMin = Int64(budgetAmount)
            viewModel.budgetMax = Int64(budgetAmount)
        } else if let tier = pendingData.budgetTier {
            // Use max amount as the budget (so expenses stay within budget)
            viewModel.budgetAmount = String(tier.maxAmount ?? tier.minAmount * 2)
            viewModel.budgetMin = Int64(tier.minAmount)
            viewModel.budgetMax = Int64(tier.maxAmount ?? tier.minAmount * 2)
        }

        // Map guest count
        if let guestRange = pendingData.guestRange {
            viewModel.selectedGuestCount = guestRange.toGuestCountOption()
        }

        // Set cover image (random abstract image selected during wizard)
        if let coverUrl = pendingData.coverUrl {
            viewModel.selectedCoverUrl = coverUrl
        }

        // Convert GeneratedPlan to EventAiResponse
        if let plan = pendingData.selectedPlan {
            let eventResponse = convertPlanToEventAiResponse(plan: plan, startDate: viewModel.startDate)
            viewModel.generatedResponse = eventResponse

            // Select all tasks by default
            viewModel.selectedTasks = Set(eventResponse.taskList.map { $0.title })
        }
    }

    /// Converts GeneratedPlan to EventAiResponse format
    private func convertPlanToEventAiResponse(plan: GeneratedPlan, startDate: Date) -> EventAiResponse {
        // Convert timeline to agenda items
        var agendaItems: [GeneratedAgendaItem] = []
        if let timeline = plan.timeline {
            for item in timeline {
                if let times = parseTimelineItem(item, baseDate: startDate) {
                    agendaItems.append(GeneratedAgendaItem(
                        startTime: times.start,
                        endTime: times.end,
                        activity: formatAIText(item.title)
                    ))
                }
            }
        }

        // Convert tasks
        var taskList: [GeneratedTask] = []
        if let tasks = plan.suggestedTasks {
            for task in tasks {
                taskList.append(GeneratedTask(title: formatAIText(task.title)))
            }
        }

        // No expenses generated - user can add them later manually
        // This keeps the AI generation focused on tasks only
        return EventAiResponse(
            agenda: agendaItems,
            taskList: taskList,
            budgetBreakdown: [],  // Empty - user calculates expenses later
            totalBudget: plan.estimatedCost
        )
    }

    /// Formats AI-generated text by replacing underscores with spaces and capitalizing words properly
    private func formatAIText(_ text: String) -> String {
        // Replace underscores with spaces
        let formatted = text.replacingOccurrences(of: "_", with: " ")

        // Handle common patterns
        let slashPatterns = [
            "food catering": "Food/Catering",
            "food and catering": "Food/Catering",
            "audio visual": "Audio/Visual",
            "audio video": "Audio/Video"
        ]

        for (pattern, replacement) in slashPatterns {
            if formatted.lowercased() == pattern {
                return replacement
            }
        }

        // Capitalize each word
        return formatted.capitalized
    }

    /// Parses a timeline item's time string to actual dates
    private func parseTimelineItem(_ item: PlanTimelineItem, baseDate: Date) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        guard let timeDate = formatter.date(from: item.time) else {
            return nil
        }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        guard let startDate = calendar.date(from: components) else {
            return nil
        }

        let duration = item.duration ?? 60 // Default 60 minutes
        let endDate = startDate.addingTimeInterval(TimeInterval(duration * 60))

        return (startDate, endDate)
    }
}

// MARK: - Type Conversions

extension AIEventType {
    /// Converts AIEventType to EventType for CreateEventViewModel
    func toEventType() -> EventType {
        switch self {
        case .birthday: return .birthday
        case .wedding: return .wedding
        case .business: return .corporate
        case .babyShower: return .babyShower
        case .graduation: return .graduation
        case .engagement: return .anniversary // Closest match
        case .anniversary: return .anniversary
        case .other: return .custom
        }
    }
}

extension AIVenueType {
    /// Converts AIVenueType to VenueOption for CreateEventViewModel
    func toVenueOption() -> VenueOption {
        switch self {
        case .indoorVenue: return .venue
        case .outdoorSpace: return .outdoor
        case .atHome: return .home
        case .hotel: return .hotel
        }
    }
}

extension GuestCountRange {
    /// Converts GuestCountRange to GuestCountOption for CreateEventViewModel
    func toGuestCountOption() -> GuestCountOption {
        switch self {
        case .intimate: return .lessThan10
        case .small: return .tenTo20
        case .medium: return .twentyTo50
        case .large: return .fiftyTo100
        case .massive: return .moreThan200
        }
    }
}

extension BudgetTier {
    /// Returns the middle amount of the budget tier range
    var midAmount: Int {
        return (minAmount + (maxAmount ?? minAmount * 2)) / 2
    }
}

// MARK: - Preview

#Preview("AI Plan Detail") {
    AIPlanDetailView()
        .environmentObject(AppState())
}
