import Foundation
import SwiftProtobuf    
import FirebaseAuth

// MARK: - Event AI Generation Response Models

/// Generated agenda item from AI
struct GeneratedAgendaItem: Codable, Identifiable {
    let startTime: Date
    let endTime: Date
    let activity: String

    var id: String { "\(startTime.timeIntervalSince1970)-\(activity)" }

    init(startTime: Date, endTime: Date, activity: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.activity = activity
    }
}

/// Generated task from AI (just a title string)
struct GeneratedTask: Codable, Identifiable, Hashable {
    let title: String
    var id: String { title }
    var isSelected: Bool = true

    init(title: String, isSelected: Bool = true) {
        self.title = title
        self.isSelected = isSelected
    }
}

/// Generated budget item from AI
struct GeneratedBudgetItem: Codable, Identifiable {
    let category: String
    let estimatedCost: Double

    var id: String { category }
}

/// Complete AI response for event generation (from full plan details)
struct EventAiResponse: Codable {
    let agenda: [GeneratedAgendaItem]
    let taskList: [GeneratedTask]
    let budgetBreakdown: [GeneratedBudgetItem]
    let totalBudget: Int

    init(agenda: [GeneratedAgendaItem], taskList: [GeneratedTask], budgetBreakdown: [GeneratedBudgetItem], totalBudget: Int) {
        self.agenda = agenda
        self.taskList = taskList
        self.budgetBreakdown = budgetBreakdown
        self.totalBudget = totalBudget
    }
}

// MARK: - Plan Generation Result (Step 1 - Summaries)

/// Result from plan generation streaming - contains light summaries
struct PlanGenerationResult {
    let generationId: String
    let plans: [GeneratedPlanSummary]
    let processingTimeMs: Int64
}

/// Light plan summary for results cards (Step 1)
struct GeneratedPlanSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let tier: PlanTier
    let style: GeneratedPlan.PlanStyle
    let matchScore: Int
    let estimatedBudgetMin: Int
    let estimatedBudgetMax: Int
    let highlights: [String]

    // Short descriptions for results card (matching Figma design)
    let venueDescription: String?
    let cateringDescription: String?
    let entertainmentDescription: String?

    /// Total cost for display (uses max from budget range)
    var totalCost: Int {
        estimatedBudgetMax > 0 ? estimatedBudgetMax : estimatedBudgetMin
    }

    static func == (lhs: GeneratedPlanSummary, rhs: GeneratedPlanSummary) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Event Generation Service Protocol

protocol EventGenerationServiceProtocol {
    /// Generate plan summaries (Step 1 - for results cards)
    func generatePlans(request: EventGenerationRequest) async throws -> PlanGenerationResult

    /// Get full plan details (Step 2 - when user selects a plan)
    func getPlanDetails(generationId: String, planId: String) async throws -> GeneratedPlan

    /// Stream plan generation with progress updates
    func generatePlansStreaming(
        request: EventGenerationRequest,
        onProgress: @escaping (GenerationProgress) -> Void,
        onPlan: @escaping (GeneratedPlanSummary) -> Void
    ) async throws -> PlanGenerationResult

    /// Legacy: Generate event content (for CreateEventFlow backward compatibility)
    func generateEvent(request: EventGenerationRequest) async throws -> EventAiResponse
}

/// Progress update during generation
struct GenerationProgress {
    let step: String
    let percentage: Int
    let message: String
}

// MARK: - Event Generation Request

struct EventGenerationRequest {
    let userId: String
    let eventType: String
    let eventName: String
    let startDate: Date
    let endDate: Date?
    let venue: String?
    let venueDetails: String?
    let guestCount: String?
    let budget: Double?
    let currency: String?
    let services: [String]?
    let customIdea: String?

    /// Convert to gRPC request
    func toGRPCRequest() -> Rushday_V1_GenerateEventPlansRequest {
        var request = Rushday_V1_GenerateEventPlansRequest()

        // Map event type
        request.eventType = mapEventType(eventType)
        request.eventName = eventName
        request.startDate = Google_Protobuf_Timestamp(date: startDate)

        if let endDate = endDate {
            request.endDate = Google_Protobuf_Timestamp(date: endDate)
        }

        if let venue = venue, !venue.isEmpty {
            request.venueLocation = venue
        }

        if let guestCount = guestCount, let count = Int32(guestCount) {
            request.customGuestCount = count
        }

        if let budget = budget {
            request.customBudgetAmount = Int32(budget)
        }

        if let services = services {
            request.selectedServices = services.compactMap { mapServiceType($0) }
        }

        if let customIdea = customIdea, !customIdea.isEmpty {
            request.preferencesText = customIdea
        }

        return request
    }

    private func mapEventType(_ type: String) -> Rushday_V1_AIEventType {
        switch type.lowercased() {
        case "birthday": return .birthday
        case "wedding": return .wedding
        case "business", "corporate": return .business
        case "baby_shower", "babyshower": return .babyShower
        case "graduation": return .graduation
        case "engagement": return .engagement
        case "anniversary": return .anniversary
        default: return .other
        }
    }

    private func mapServiceType(_ service: String) -> Rushday_V1_ServiceType {
        switch service.lowercased() {
        case "catering", "food": return .catering
        case "decoration", "decor": return .decoration
        case "entertainment", "music", "dj": return .entertainment
        case "photo", "video", "photography": return .photoVideo
        case "invitations", "invite": return .invitations
        case "transport", "transportation": return .transport
        default: return .unspecified
        }
    }
}

// MARK: - Event Generation Service Implementation

final class EventGenerationService: EventGenerationServiceProtocol {

    static let shared = EventGenerationService()

    private init() {}

    // MARK: - Token Management

    /// Ensures a valid auth token is set on the gRPC client before making requests
    private func ensureValidToken() async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw EventGenerationError.serverError(message: "Authentication required")
        }

        do {
            // Force refresh the token to ensure it's valid
            let token = try await firebaseUser.getIDToken(forcingRefresh: true)
            GRPCClientService.shared.setAuthToken(token)
        } catch {
            throw EventGenerationError.serverError(message: "Authentication required")
        }
    }

    // MARK: - Step 1: Generate Plan Summaries

    func generatePlans(request: EventGenerationRequest) async throws -> PlanGenerationResult {
        // Ensure valid auth token before making gRPC calls
        try await ensureValidToken()

        let grpcRequest = request.toGRPCRequest()

        do {
            let result = try await GRPCClientService.shared.generateEventPlans(grpcRequest)

            let summaries = result.plans.map { mapGRPCSummary($0) }

            return PlanGenerationResult(
                generationId: result.generationId,
                plans: summaries,
                processingTimeMs: result.processingTimeMs
            )
        } catch {
            throw EventGenerationError.networkError(error)
        }
    }

    // MARK: - Step 1 with Streaming

    func generatePlansStreaming(
        request: EventGenerationRequest,
        onProgress: @escaping (GenerationProgress) -> Void,
        onPlan: @escaping (GeneratedPlanSummary) -> Void
    ) async throws -> PlanGenerationResult {
        // Ensure valid auth token before making gRPC calls
        try await ensureValidToken()

        let grpcRequest = request.toGRPCRequest()

        var plans: [GeneratedPlanSummary] = []
        var generationId = ""
        var processingTimeMs: Int64 = 0

        for try await response in GRPCClientService.shared.generateEventPlansStreaming(grpcRequest) {
            switch response.payload {
            case .progress(let progress):
                let progressUpdate = GenerationProgress(
                    step: progress.step,
                    percentage: Int(progress.percentage),
                    message: progress.message
                )
                await MainActor.run { onProgress(progressUpdate) }

            case .planSummary(let grpcPlan):
                let summary = mapGRPCSummary(grpcPlan)
                plans.append(summary)
                await MainActor.run { onPlan(summary) }

            case .complete(let complete):
                generationId = complete.generationID
                processingTimeMs = complete.processingTimeMs

            case .error(let error):
                throw EventGenerationError.serverError(message: error.message)

            case .none:
                break
            }
        }

        guard !plans.isEmpty else {
            throw EventGenerationError.noPlansGenerated
        }

        return PlanGenerationResult(
            generationId: generationId,
            plans: plans,
            processingTimeMs: processingTimeMs
        )
    }

    // MARK: - Legacy: Generate Event (for CreateEventFlow backward compatibility)

    /// Legacy method for the old create event flow
    /// Generates plans via streaming, takes the first plan, fetches full details, and returns EventAiResponse
    func generateEvent(request: EventGenerationRequest) async throws -> EventAiResponse {
        // Ensure valid auth token before making gRPC calls
        try await ensureValidToken()

        let grpcRequest = request.toGRPCRequest()

        // Generate plans (non-streaming for simplicity)
        let result = try await GRPCClientService.shared.generateEventPlans(grpcRequest)

        guard let firstSummary = result.plans.first else {
            throw EventGenerationError.noPlansGenerated
        }

        // Fetch full plan details
        let fullPlan = try await GRPCClientService.shared.getPlanDetails(
            generationId: result.generationId,
            planId: firstSummary.id
        )

        // Convert to EventAiResponse format
        return mapGRPCPlanToEventAiResponse(fullPlan, eventStartDate: request.startDate)
    }

    private func mapGRPCPlanToEventAiResponse(_ plan: Rushday_V1_EventPlan, eventStartDate: Date) -> EventAiResponse {
        // Map agenda items
        let agenda = plan.suggestedAgenda.map { item -> GeneratedAgendaItem in
            let startTime = item.startTime.date
            let endTime = startTime.addingTimeInterval(TimeInterval(item.durationMinutes * 60))
            return GeneratedAgendaItem(
                startTime: startTime,
                endTime: endTime,
                activity: item.title
            )
        }

        // Map tasks
        let taskList = plan.suggestedTasks.map { task -> GeneratedTask in
            GeneratedTask(title: task.title, isSelected: true)
        }

        // No expenses generated - user can calculate them later manually
        let estimatedBudget = Int(plan.estimatedBudget.maxAmount > 0 ? plan.estimatedBudget.maxAmount : plan.estimatedBudget.minAmount)

        return EventAiResponse(
            agenda: agenda,
            taskList: taskList,
            budgetBreakdown: [],  // Empty - user calculates expenses later
            totalBudget: estimatedBudget
        )
    }

    // MARK: - Step 2: Get Full Plan Details

    func getPlanDetails(generationId: String, planId: String) async throws -> GeneratedPlan {
        // Ensure valid auth token before making gRPC calls
        try await ensureValidToken()

        do {
            let grpcPlan = try await GRPCClientService.shared.getPlanDetails(
                generationId: generationId,
                planId: planId
            )
            return mapGRPCPlanToGeneratedPlan(grpcPlan)
        } catch {
            throw EventGenerationError.networkError(error)
        }
    }

    // MARK: - Mapping Helpers

    private func mapGRPCSummary(_ summary: Rushday_V1_EventPlanSummary) -> GeneratedPlanSummary {
        GeneratedPlanSummary(
            id: summary.id,
            title: summary.title,
            description: summary.description_p,
            tier: mapPlanTier(summary.tier),
            style: mapPlanStyle(summary.style),
            matchScore: Int(summary.matchScore),
            estimatedBudgetMin: Int(summary.estimatedBudget.minAmount),
            estimatedBudgetMax: Int(summary.estimatedBudget.maxAmount),
            highlights: summary.highlights,
            venueDescription: summary.venueDescription.isEmpty ? nil : summary.venueDescription,
            cateringDescription: summary.cateringDescription.isEmpty ? nil : summary.cateringDescription,
            entertainmentDescription: summary.entertainmentDescription.isEmpty ? nil : summary.entertainmentDescription
        )
    }

    private func mapGRPCPlanToGeneratedPlan(_ plan: Rushday_V1_EventPlan) -> GeneratedPlan {
        // Map timeline from suggested agenda
        let timeline: [PlanTimelineItem]? = plan.suggestedAgenda.isEmpty ? nil : plan.suggestedAgenda.map { item in
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: item.startTime.date)

            return PlanTimelineItem(
                id: item.id,
                time: timeString,
                title: item.title,
                description: item.description_p.isEmpty ? nil : item.description_p,
                duration: Int(item.durationMinutes)
            )
        }

        // Map suggested tasks
        let suggestedTasks: [PlanTask]? = plan.suggestedTasks.isEmpty ? nil : plan.suggestedTasks.map { task in
            PlanTask(
                id: task.id,
                title: task.title,
                description: task.description_p.isEmpty ? nil : task.description_p,
                daysBeforeEvent: Int(task.daysBeforeEvent),
                priority: task.priority.isEmpty ? nil : task.priority,
                category: task.category.isEmpty ? nil : task.category
            )
        }

        // Map vendors
        let vendors: [PlanVendor]? = plan.suggestedVendors.isEmpty ? nil : plan.suggestedVendors.map { vendor in
            PlanVendor(
                id: vendor.id,
                name: vendor.name,
                category: vendor.category,
                price: Int(vendor.estimatedCost),
                rating: vendor.rating > 0 ? vendor.rating : nil,
                imageUrl: vendor.imageURL.isEmpty ? nil : vendor.imageURL
            )
        }

        let minAmount = Int(plan.estimatedBudget.minAmount)
        let maxAmount = Int(plan.estimatedBudget.maxAmount)
        let estimatedCost = maxAmount > 0 ? maxAmount : minAmount

        return GeneratedPlan(
            id: plan.id,
            title: plan.title,
            description: plan.description_p,
            estimatedCost: estimatedCost,
            estimatedBudgetMin: minAmount,
            estimatedBudgetMax: maxAmount,
            style: mapPlanStyle(plan.style),
            tier: mapPlanTier(plan.tier),
            matchScore: Int(plan.matchScore),
            highlights: plan.highlights,
            venueDescription: plan.venueDescription.isEmpty ? nil : plan.venueDescription,
            cateringDescription: plan.cateringDescription.isEmpty ? nil : plan.cateringDescription,
            entertainmentDescription: plan.entertainmentDescription.isEmpty ? nil : plan.entertainmentDescription,
            vendors: vendors,
            timeline: timeline,
            suggestedTasks: suggestedTasks
        )
    }

    private func mapPlanTier(_ tier: Rushday_V1_PlanTier) -> PlanTier {
        switch tier {
        case .aiRecommended: return .aiRecommended
        case .popular: return .popular
        case .standard, .unspecified: return .standard
        case .UNRECOGNIZED: return .standard
        }
    }

    private func mapPlanStyle(_ style: Rushday_V1_PlanStyle) -> GeneratedPlan.PlanStyle {
        switch style {
        case .classic: return .classic
        case .modern: return .modern
        case .natural: return .natural
        case .luxury: return .luxury
        case .custom, .unspecified: return .custom
        case .UNRECOGNIZED: return .custom
        }
    }
}

// MARK: - Event Generation Errors

enum EventGenerationError: LocalizedError {
    case noPlansGenerated
    case serverError(message: String)
    case networkError(Error)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .noPlansGenerated:
            return "No plans were generated. Please try again."
        case .serverError(let message):
            return message.isEmpty ? "Server error occurred. Please try again." : message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .notConnected:
            return "Not connected to server. Please check your connection."
        }
    }
}
