import SwiftUI

// MARK: - Guest Count Range

enum GuestCountRange: String, CaseIterable, Codable, Identifiable {
    case intimate      // 1-10
    case small         // 10-25
    case medium        // 25-50
    case large         // 50-100
    case massive       // 100+

    var id: String { rawValue }

    var title: String {
        switch self {
        case .intimate: return "1-10 guests"
        case .small: return "10-25 guests"
        case .medium: return "25-50 guests"
        case .large: return "50-100 guests"
        case .massive: return "100+ guests"
        }
    }

    var subtitle: String {
        switch self {
        case .intimate: return "Intimate gathering"
        case .small: return "Small party"
        case .medium: return "Medium scale"
        case .large: return "Large event"
        case .massive: return "Major celebration"
        }
    }

    var range: String {
        switch self {
        case .intimate: return "1-10"
        case .small: return "10-25"
        case .medium: return "25-50"
        case .large: return "50-100"
        case .massive: return "100+"
        }
    }

    var minGuests: Int {
        switch self {
        case .intimate: return 1
        case .small: return 10
        case .medium: return 25
        case .large: return 50
        case .massive: return 100
        }
    }

    var maxGuests: Int? {
        switch self {
        case .intimate: return 10
        case .small: return 25
        case .medium: return 50
        case .large: return 100
        case .massive: return nil
        }
    }

    var icon: String {
        switch self {
        case .intimate: return "guests_1_icon"           // 1-10: single person
        case .small: return "guests_2_icon"              // 10-25: two people
        case .medium: return "guests_group_icon"         // 25-50: group of people
        case .large: return "guests_group_icon"          // 50-100: group of people
        case .massive: return "guests_group_icon"        // 100+: group of people
        }
    }

    /// Whether the icon is a custom asset (true) or SF Symbol (false)
    var isCustomIcon: Bool {
        return true  // All guest count icons are custom assets
    }

    var gradientColors: [Color] {
        // All use the same purple gradient per Figma design
        return [Color(hex: "8251EB"), Color(hex: "6366F1")]
    }
}

// MARK: - Venue Type

enum AIVenueType: String, CaseIterable, Codable, Identifiable {
    case indoorVenue
    case outdoorSpace
    case atHome
    case hotel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indoorVenue: return "Indoor Venue"
        case .outdoorSpace: return "Outdoor Space"
        case .atHome: return "At Home"
        case .hotel: return "Hotel"
        }
    }

    var subtitle: String {
        switch self {
        case .indoorVenue: return "Banquet hall, restaurant"
        case .outdoorSpace: return "Park, terrace, garden"
        case .atHome: return "Your place or a friend's"
        case .hotel: return "Hotel conference hall"
        }
    }

    var icon: String {
        switch self {
        case .indoorVenue: return "indoor_venue_icon"
        case .outdoorSpace: return "outdoor_space_icon"
        case .atHome: return "at_home_icon"
        case .hotel: return "hotel_icon"
        }
    }

    /// Whether the icon is a custom asset (true) or SF Symbol (false)
    var isCustomIcon: Bool {
        return true  // All venue type icons are custom assets
    }

    var gradientColors: [Color] {
        // All venue types use the same purple gradient per Figma design
        return [Color(hex: "8251EB"), Color(hex: "6366F1")]
    }
}

// MARK: - Budget Tier

enum BudgetTier: String, CaseIterable, Codable, Identifiable {
    case economy
    case standard
    case premium
    case luxury

    var id: String { rawValue }

    var title: String {
        switch self {
        case .economy: return "Economy"
        case .standard: return "Standard"
        case .premium: return "Premium"
        case .luxury: return "Luxury"
        }
    }

    var subtitle: String {
        switch self {
        case .economy: return "Basic solutions with great results"
        case .standard: return "Optimal price-quality ratio"
        case .premium: return "High level service and comfort"
        case .luxury: return "VIP service without limits"
        }
    }

    var range: String {
        switch self {
        case .economy: return "up to $1,500"
        case .standard: return "$1,500 - $4,500"
        case .premium: return "$4,500 - $7,500"
        case .luxury: return "from $7,500"
        }
    }

    var minAmount: Int {
        switch self {
        case .economy: return 0
        case .standard: return 1500
        case .premium: return 4500
        case .luxury: return 7500
        }
    }

    var maxAmount: Int? {
        switch self {
        case .economy: return 1500
        case .standard: return 4500
        case .premium: return 7500
        case .luxury: return nil
        }
    }

    var icon: String {
        // All budget tiers use the same custom dollar icon
        return "budget_icon"
    }

    /// Whether the icon is a custom asset (true) or SF Symbol (false)
    var isCustomIcon: Bool {
        return true
    }

    var gradientColors: [Color] {
        switch self {
        case .economy: return [Color(hex: "00C950"), Color(hex: "009966")]   // Green
        case .standard: return [Color(hex: "2B7FFF"), Color(hex: "0092B8")]  // Blue
        case .premium: return [Color(hex: "AD46FF"), Color(hex: "E60076")]   // Purple to Pink
        case .luxury: return [Color(hex: "FE9A00"), Color(hex: "F54900")]    // Orange
        }
    }
}

// MARK: - Service Type

enum ServiceType: String, CaseIterable, Codable, Identifiable {
    case catering
    case decoration
    case entertainment
    case photoVideo
    case invitations
    case transport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .catering: return "Catering"
        case .decoration: return "Decoration"
        case .entertainment: return "Entertainment"
        case .photoVideo: return "Photo/Video"
        case .invitations: return "Invitations"
        case .transport: return "Transport"
        }
    }

    var subtitle: String {
        switch self {
        case .catering: return "Food service organization"
        case .decoration: return "Space design & setup"
        case .entertainment: return "Music, show program"
        case .photoVideo: return "Professional shooting"
        case .invitations: return "Design and printing"
        case .transport: return "Guest transfer service"
        }
    }

    var icon: String {
        switch self {
        case .catering: return "catering_icon"
        case .decoration: return "decoration_icon"
        case .entertainment: return "entertainment_icon"
        case .photoVideo: return "photo_video_icon"
        case .invitations: return "invitations_icon"
        case .transport: return "transport_icon"
        }
    }

    /// Whether the icon is a custom asset (true) or SF Symbol (false)
    var isCustomIcon: Bool {
        return true  // All service icons are now custom assets
    }
}

// MARK: - AI Event Type (for wizard, different from domain EventType)

enum AIEventType: String, CaseIterable, Codable, Identifiable {
    case birthday
    case wedding
    case business
    case babyShower
    case graduation
    case engagement
    case anniversary
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .birthday: return "Birthday Party"
        case .wedding: return "Wedding"
        case .business: return "Business Event"
        case .babyShower: return "Baby Shower"
        case .graduation: return "Graduation"
        case .engagement: return "Engagement"
        case .anniversary: return "Anniversary"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .birthday: return "birthday_icon"
        case .wedding: return "wedding_icon"
        case .business: return "business_icon"
        case .babyShower: return "babyshower_icon"
        case .graduation: return "graduation_icon"
        case .engagement: return "engagement_icon"
        case .anniversary: return "anniversary_icon"
        case .other: return "other_icon"
        }
    }

    /// Whether the icon is a custom asset (true) or SF Symbol (false)
    var isCustomIcon: Bool {
        return true  // All event type icons are now custom assets
    }

    var gradientColors: [Color] {
        switch self {
        case .birthday: return [Color(hex: "AD46FF"), Color(hex: "9810FA")]  // Purple
        case .wedding: return [Color(hex: "FF637E"), Color(hex: "FFB900")]   // Pink to gold
        case .business: return [Color(hex: "51A2FF"), Color(hex: "615FFF")]  // Blue to purple
        case .babyShower: return [Color(hex: "FFDF20"), Color(hex: "FDC700")] // Yellow
        case .graduation: return [Color(hex: "00D492"), Color(hex: "00BBA7")] // Teal
        case .engagement: return [Color(hex: "FB64B6"), Color(hex: "F6339A")] // Pink
        case .anniversary: return [Color(hex: "C27AFF"), Color(hex: "E9D4FF")] // Lavender
        case .other: return [Color(hex: "53EAFD"), Color(hex: "00D3F2")]      // Cyan
        }
    }
}

// MARK: - Quick Idea Category

struct QuickIdeaCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let tags: [String]

    static let atmosphere = QuickIdeaCategory(
        title: "Atmosphere",
        icon: "atmosphere_icon",
        color: Color(hex: "FF2056"),
        tags: ["Relaxed vibe", "Formal elegance", "Romantic mood", "Energetic party", "Cozy & intimate", "Grand celebration"]
    )

    static let style = QuickIdeaCategory(
        title: "Style",
        icon: "style_icon",
        color: Color(hex: "AD46FF"),
        tags: ["Eco-friendly theme", "Minimalist design", "Luxury & premium", "Vintage classic", "Modern chic", "Bohemian style"]
    )

    static let decor = QuickIdeaCategory(
        title: "Decor",
        icon: "decor_icon",
        color: Color(hex: "00BC7D"),
        tags: ["Lots of flowers", "Candles & lights", "Balloon arrangements", "Natural greenery", "Elegant drapery", "LED installations"]
    )

    static let entertainment = QuickIdeaCategory(
        title: "Entertainment",
        icon: "entertainment_idea_icon",
        color: Color(hex: "2B7FFF"),
        tags: ["Live music band", "DJ performance", "Photo booth area", "Interactive games", "Dance floor", "Karaoke setup"]
    )

    static let timing = QuickIdeaCategory(
        title: "Timing",
        icon: "timing_icon",
        color: Color(hex: "FE9A00"),
        tags: ["Sunset timing", "Evening event", "Brunch party", "Night celebration", "Afternoon tea", "Morning gathering"]
    )

    static let specialFeatures = QuickIdeaCategory(
        title: "Special Features",
        icon: "special_features_icon",
        color: Color(hex: "00B8DB"),
        tags: ["Outdoor setting", "Pet-friendly", "Kids activities", "Fireworks display", "Surprise elements", "Custom cocktails"]
    )

    static let allCategories: [QuickIdeaCategory] = [atmosphere, style, decor, entertainment, timing, specialFeatures]
}

// MARK: - AI Tip Style

enum AITipStyle {
    case purple
    case blue
    case green
    case orange

    var backgroundColor: Color {
        switch self {
        case .purple: return Color(hex: "8251EB").opacity(0.1)
        case .blue: return Color(hex: "2B7FFF").opacity(0.1)
        case .green: return Color(hex: "00BC7D").opacity(0.1)
        case .orange: return Color(hex: "FE9A00").opacity(0.1)
        }
    }

    var borderColor: Color {
        switch self {
        case .purple: return Color(hex: "8251EB").opacity(0.2)
        case .blue: return Color(hex: "2B7FFF").opacity(0.2)
        case .green: return Color(hex: "00BC7D").opacity(0.2)
        case .orange: return Color(hex: "FE9A00").opacity(0.2)
        }
    }

    var iconBackgroundColor: Color {
        switch self {
        case .purple: return Color(hex: "8251EB").opacity(0.2)
        case .blue: return Color(hex: "2B7FFF").opacity(0.2)
        case .green: return Color(hex: "00BC7D").opacity(0.2)
        case .orange: return Color(hex: "FE9A00").opacity(0.2)
        }
    }

    var iconColor: Color {
        switch self {
        case .purple: return Color(hex: "8251EB")
        case .blue: return Color(hex: "51A2FF")
        case .green: return Color(hex: "00D492")
        case .orange: return Color(hex: "FFB900")
        }
    }

    var titleColor: Color {
        switch self {
        case .purple: return Color(hex: "8251EB")
        case .blue: return Color(hex: "51A2FF")
        case .green: return Color(hex: "00D492")
        case .orange: return Color(hex: "FFB900")
        }
    }

    var icon: String {
        switch self {
        case .purple, .blue, .green: return "ai_tip_icon"
        case .orange: return "ai_tip_orange_icon"
        }
    }

    var isCustomIcon: Bool {
        return true
    }
}
