import Foundation
import SwiftUI

// MARK: - Generated Plan Model

struct GeneratedPlan: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let estimatedCost: Int
    let estimatedBudgetMin: Int
    let estimatedBudgetMax: Int
    let style: PlanStyle
    let tier: PlanTier
    let matchScore: Int // 0-100 percentage
    let highlights: [String]
    let venueDescription: String?
    let cateringDescription: String?
    let entertainmentDescription: String?
    let vendors: [PlanVendor]?
    let timeline: [PlanTimelineItem]?
    let suggestedTasks: [PlanTask]?

    /// Total cost for display (uses max from budget range, falls back to estimatedCost)
    var totalCost: Int {
        estimatedBudgetMax > 0 ? estimatedBudgetMax : (estimatedBudgetMin > 0 ? estimatedBudgetMin : estimatedCost)
    }

    enum PlanStyle: String, Codable {
        case classic
        case modern
        case natural
        case luxury
        case custom

        var displayName: String {
            switch self {
            case .classic: return "Elegant Classic"
            case .modern: return "Minimalism & Tech"
            case .natural: return "Eco & Organic"
            case .luxury: return "Premium Luxury"
            case .custom: return "Custom Style"
            }
        }

        var tagColor: Color {
            switch self {
            case .classic: return Color(hex: "8251EB")
            case .modern: return Color(hex: "2B7FFF")
            case .natural: return Color(hex: "00BC7D")
            case .luxury: return Color(hex: "FE9A00")
            case .custom: return Color(hex: "EC4899")
            }
        }

        var gradientColors: [Color] {
            switch self {
            case .classic: return [Color(hex: "A78BFA"), Color(hex: "8251EB")]
            case .modern: return [Color(hex: "60A5FA"), Color(hex: "3B82F6")]
            case .natural: return [Color(hex: "4ADE80"), Color(hex: "22C55E")]
            case .luxury: return [Color(hex: "FE9A00"), Color(hex: "F54900")]
            case .custom: return [Color(hex: "F472B6"), Color(hex: "EC4899")]
            }
        }

        var icon: String {
            switch self {
            case .classic: return "crown.fill"
            case .modern: return "cube.fill"
            case .natural: return "leaf.fill"
            case .luxury: return "star.fill"
            case .custom: return "wand.and.stars"
            }
        }
    }

    static func == (lhs: GeneratedPlan, rhs: GeneratedPlan) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Plan Vendor

struct PlanVendor: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let price: Int?
    let rating: Double?
    let imageUrl: String?
}

// MARK: - Plan Timeline Item

struct PlanTimelineItem: Codable, Identifiable {
    let id: String
    let time: String
    let title: String
    let description: String?
    let duration: Int? // in minutes
}

// MARK: - Plan Task (suggested task from AI)

struct PlanTask: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let daysBeforeEvent: Int?
    let priority: String?
    let category: String?
}

// MARK: - Pending Event Data (for unauth flow)

struct PendingEventData: Codable {
    // Step 1: Event Type
    var eventType: AIEventType?
    var customEventType: String?

    // Step 2: Guest Count
    var guestRange: GuestCountRange?
    var customGuestCount: Int?

    // Step 3: Event Details
    var eventName: String?
    var eventStartDate: Date?
    var eventEndDate: Date?
    var eventVenue: String?

    // Step 4: Venue Type
    var venueType: AIVenueType?
    var customVenueName: String?
    var venueSkipped: Bool = false

    // Step 5: Budget
    var budgetTier: BudgetTier?
    var customBudgetAmount: Int?

    // Step 6: Services
    var selectedServices: [ServiceType] = []
    var customService: String?
    var servicesSkipped: Bool = false

    // Step 7: Preferences
    var preferencesText: String?
    var selectedTags: [String] = []
    var preferencesSkipped: Bool = false

    // Selected plan from results
    var selectedPlan: GeneratedPlan?

    // Cover image (random abstract image)
    var coverUrl: String?

    // Computed properties
    var effectiveGuestCount: Int {
        if let custom = customGuestCount {
            return custom
        }
        return guestRange?.minGuests ?? 50
    }

    var effectiveBudget: Int {
        if let custom = customBudgetAmount {
            return custom
        }
        return budgetTier?.minAmount ?? 1000
    }

    var effectiveEventType: String {
        if let custom = customEventType, !custom.isEmpty {
            return custom
        }
        return eventType?.title ?? "Event"
    }
}

// MARK: - Generation Progress

enum GenerationStep: Int, CaseIterable {
    case analyzingPreferences
    case findingVenues
    case creatingProgram
    case calculatingBudget
    case generatingPlans

    var title: String {
        switch self {
        case .analyzingPreferences: return "Analyzing your preferences"
        case .findingVenues: return "Finding perfect venues"
        case .creatingProgram: return "Creating event program"
        case .calculatingBudget: return "Calculating budget & services"
        case .generatingPlans: return "Generating final plans"
        }
    }

    var icon: String {
        switch self {
        case .analyzingPreferences: return "search_step_icon"
        case .findingVenues: return "location_step_icon"
        case .creatingProgram: return "calendar_step_icon"
        case .calculatingBudget: return "dollar_step_icon"
        case .generatingPlans: return "sparkle_step_icon"
        }
    }

    /// Whether the icon is a custom asset (true) or SF Symbol (false)
    var isCustomIcon: Bool {
        return true
    }
}

// MARK: - Plan Tier (for AI recommendations)

enum PlanTier: String, Codable {
    case aiRecommended
    case popular
    case standard

    @MainActor
    var badgeText: String? {
        switch self {
        case .aiRecommended: return L10n.planTierRecommended
        case .popular: return L10n.planTierPopular
        case .standard: return nil
        }
    }

    @MainActor
    var displayTitle: String {
        switch self {
        case .aiRecommended: return L10n.planTitleRecommended
        case .popular: return L10n.planTitlePopular
        case .standard: return L10n.planTitleStandard
        }
    }

    var badgeIcon: String? {
        switch self {
        case .aiRecommended: return "ai_recommended_badge"
        case .popular: return "popular_badge"
        case .standard: return nil
        }
    }

    var badgeColors: [Color] {
        switch self {
        case .aiRecommended: return [Color(hex: "8251EB"), Color(hex: "6366F1")]
        case .popular: return [Color(hex: "FF6900"), Color(hex: "FE9A00")] // Orange gradient per Figma
        case .standard: return []
        }
    }
}

// MARK: - Mock Data for Development

extension GeneratedPlan {
    static let mockClassic = GeneratedPlan(
        id: "classic-1",
        title: "Classic Celebration",
        description: "Perfect blend of tradition and modernity",
        estimatedCost: 8500,
        estimatedBudgetMin: 8000,
        estimatedBudgetMax: 8500,
        style: .classic,
        tier: .aiRecommended,
        matchScore: 95,
        highlights: ["Elegant decor", "Professional catering", "Live music"],
        venueDescription: "Imperial Banquet Hall",
        cateringDescription: "European cuisine, 5 courses",
        entertainmentDescription: "Live music, DJ",
        vendors: nil,
        timeline: [
            PlanTimelineItem(id: "1", time: "6:00 PM", title: "Guest Arrival and Welcome Drinks", description: nil, duration: 60),
            PlanTimelineItem(id: "2", time: "7:00 PM", title: "Opening Remarks", description: nil, duration: 15),
            PlanTimelineItem(id: "3", time: "7:15 PM", title: "Dinner Service", description: nil, duration: 90),
            PlanTimelineItem(id: "4", time: "8:45 PM", title: "Cake Cutting and Dessert", description: nil, duration: 30),
            PlanTimelineItem(id: "5", time: "9:15 PM", title: "Dancing and Entertainment", description: nil, duration: 105),
            PlanTimelineItem(id: "6", time: "11:00 PM", title: "Farewell", description: nil, duration: 30)
        ],
        suggestedTasks: [
            PlanTask(id: "t1", title: "Order the cake", description: nil, daysBeforeEvent: 7, priority: "high", category: "catering"),
            PlanTask(id: "t2", title: "Send invitations", description: nil, daysBeforeEvent: 30, priority: "high", category: "guests"),
            PlanTask(id: "t3", title: "Book photographer", description: nil, daysBeforeEvent: 14, priority: "medium", category: "services"),
            PlanTask(id: "t4", title: "Finalize menu", description: nil, daysBeforeEvent: 10, priority: "high", category: "catering"),
            PlanTask(id: "t5", title: "Arrange decorations", description: nil, daysBeforeEvent: 3, priority: "medium", category: "decor"),
            PlanTask(id: "t6", title: "Confirm guest count", description: nil, daysBeforeEvent: 5, priority: "high", category: "guests"),
            PlanTask(id: "t7", title: "Create playlist", description: nil, daysBeforeEvent: 7, priority: "low", category: "entertainment"),
            PlanTask(id: "t8", title: "Organize seating", description: nil, daysBeforeEvent: 2, priority: "medium", category: "venue")
        ]
    )

    static let mockModern = GeneratedPlan(
        id: "modern-1",
        title: "Modern Style",
        description: "Modern solutions for an unforgettable event",
        estimatedCost: 8000,
        estimatedBudgetMin: 7500,
        estimatedBudgetMax: 8000,
        style: .modern,
        tier: .popular,
        matchScore: 88,
        highlights: ["Minimalist design", "Tech-forward setup", "Trending cuisine"],
        venueDescription: "Art House Loft Space",
        cateringDescription: "Food courts and fusion cuisine",
        entertainmentDescription: "LED show, interactive zones",
        vendors: nil,
        timeline: nil,
        suggestedTasks: [
            PlanTask(id: "t1", title: "Book DJ/Entertainment", description: nil, daysBeforeEvent: 14, priority: "high", category: "entertainment"),
            PlanTask(id: "t2", title: "Set up LED equipment", description: nil, daysBeforeEvent: 2, priority: "high", category: "decor"),
            PlanTask(id: "t3", title: "Coordinate food stations", description: nil, daysBeforeEvent: 7, priority: "medium", category: "catering")
        ]
    )

    static let mockNatural = GeneratedPlan(
        id: "natural-1",
        title: "Natural Harmony",
        description: "Unity with nature and sustainability",
        estimatedCost: 7500,
        estimatedBudgetMin: 7000,
        estimatedBudgetMax: 7500,
        style: .natural,
        tier: .standard,
        matchScore: 82,
        highlights: ["Eco-friendly", "Organic catering", "Garden setting"],
        venueDescription: "Green Garden Outdoor Terrace",
        cateringDescription: "Organic products, farm-to-table",
        entertainmentDescription: "Acoustic music, outdoor activities",
        vendors: nil,
        timeline: nil,
        suggestedTasks: [
            PlanTask(id: "t1", title: "Source organic catering", description: nil, daysBeforeEvent: 14, priority: "high", category: "catering"),
            PlanTask(id: "t2", title: "Arrange garden decorations", description: nil, daysBeforeEvent: 3, priority: "medium", category: "decor"),
            PlanTask(id: "t3", title: "Book acoustic musicians", description: nil, daysBeforeEvent: 21, priority: "high", category: "entertainment")
        ]
    )

    static let mockPlans: [GeneratedPlan] = [mockClassic, mockModern, mockNatural]
}
