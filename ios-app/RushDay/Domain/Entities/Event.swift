import Foundation
import SwiftUI

enum EventType: String, Codable, CaseIterable, Identifiable {
    case birthday = "birthday"
    case wedding = "wedding"
    case corporate = "corporate"
    case babyShower = "baby_shower"
    case graduation = "graduation"
    case anniversary = "anniversary"
    case holiday = "holiday"
    case conference = "conference"
    case vacation = "vacation"
    case custom = "custom"

    var id: String { rawValue }

    @MainActor
    var displayName: String {
        switch self {
        case .birthday: return L10n.eventTypeBirthday
        case .wedding: return L10n.eventTypeWedding
        case .corporate: return L10n.eventTypeCorporate
        case .babyShower: return L10n.eventTypeBabyShower
        case .graduation: return L10n.eventTypeGraduation
        case .anniversary: return L10n.eventTypeAnniversary
        case .holiday: return L10n.eventTypeHoliday
        case .conference: return L10n.eventTypeConference
        case .vacation: return L10n.eventTypeVacation
        case .custom: return L10n.eventTypeCustom
        }
    }

    var icon: String {
        switch self {
        case .birthday: return "birthday.cake.fill"
        case .wedding: return "heart.fill"
        case .corporate: return "briefcase.fill"
        case .babyShower: return "teddybear.fill"
        case .graduation: return "graduationcap.fill"
        case .anniversary: return "gift.fill"
        case .holiday: return "party.popper.fill"
        case .conference: return "person.3.fill"
        case .vacation: return "airplane"
        case .custom: return "pencil.and.outline"
        }
    }

    var color: Color {
        switch self {
        case .birthday: return .birthday
        case .wedding: return .wedding
        case .corporate: return .corporate
        case .babyShower: return .babyShower
        case .graduation: return .graduation
        case .anniversary: return .anniversary
        case .holiday: return .holiday
        case .conference: return .conference
        case .vacation: return .vacation
        case .custom: return .custom
        }
    }
}

// MARK: - Event Entity (matches Flutter Firestore structure)
/// Firestore collection: "events"
/// Field names match Flutter's event_model.dart for cross-platform compatibility
struct Event: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var startDate: Date                    // Flutter: startDate (ISO 8601 string)
    var createAt: Date                     // Flutter: createAt (ISO 8601 string)
    var eventTypeId: String                // Flutter: eventTypeId (stores EventType.rawValue)
    var ownerId: String                    // Flutter: ownerId (user ID)
    var ownerName: String?                 // Owner's display name (from backend)

    // Local-only state (not persisted to backend)
    var isCreating: Bool = false           // True when event is being created in background

    // Optional fields
    var isAllDay: Bool                     // Flutter: isAllDay (default: false)
    var isMovedToDraft: Bool               // Flutter: isMovedToDraft (default: false)
    var endDate: Date?                     // Flutter: endDate (nullable ISO 8601)
    var venue: String?                     // Flutter: venue
    var customIdea: String?                // Flutter: customIdea
    var themeIdea: String?                 // Flutter: themeIdea
    var coverImage: String?                // Flutter: coverImage (URL string)
    var inviteMessage: String?             // Flutter: inviteMessage
    var updatedAt: Date?                   // Flutter: updatedAt (nullable ISO 8601)

    // Co-hosts (from gRPC shared field)
    var shared: [SharedUser]               // Co-hosts invited to this event

    // CodingKeys to match exact Firestore field names
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startDate
        case createAt
        case eventTypeId
        case ownerId
        case ownerName
        case isAllDay
        case isMovedToDraft
        case endDate
        case venue
        case customIdea
        case themeIdea
        case coverImage
        case inviteMessage
        case updatedAt
        case shared
    }

    // Computed properties
    var isUpcoming: Bool {
        startDate > Date()
    }

    var isPast: Bool {
        startDate < Date()
    }

    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
    }

    /// Get the EventType enum from eventTypeId string
    var eventType: EventType {
        EventType(rawValue: eventTypeId) ?? .custom
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        startDate: Date,
        createAt: Date = Date(),
        eventTypeId: String,
        ownerId: String,
        ownerName: String? = nil,
        isCreating: Bool = false,
        isAllDay: Bool = false,
        isMovedToDraft: Bool = false,
        endDate: Date? = nil,
        venue: String? = nil,
        customIdea: String? = nil,
        themeIdea: String? = nil,
        coverImage: String? = nil,
        inviteMessage: String? = nil,
        updatedAt: Date? = nil,
        shared: [SharedUser] = []
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.createAt = createAt
        self.eventTypeId = eventTypeId
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.isCreating = isCreating
        self.isAllDay = isAllDay
        self.isMovedToDraft = isMovedToDraft
        self.endDate = endDate
        self.venue = venue
        self.customIdea = customIdea
        self.themeIdea = themeIdea
        self.coverImage = coverImage
        self.inviteMessage = inviteMessage
        self.updatedAt = updatedAt
        self.shared = shared
    }

    /// Convenience initializer with EventType enum
    init(
        id: String = UUID().uuidString,
        name: String,
        startDate: Date,
        createAt: Date = Date(),
        eventType: EventType,
        ownerId: String,
        ownerName: String? = nil,
        isAllDay: Bool = false,
        isMovedToDraft: Bool = false,
        endDate: Date? = nil,
        venue: String? = nil,
        customIdea: String? = nil,
        themeIdea: String? = nil,
        coverImage: String? = nil,
        inviteMessage: String? = nil,
        updatedAt: Date? = nil,
        shared: [SharedUser] = []
    ) {
        self.init(
            id: id,
            name: name,
            startDate: startDate,
            createAt: createAt,
            eventTypeId: eventType.rawValue,
            ownerId: ownerId,
            ownerName: ownerName,
            isAllDay: isAllDay,
            isMovedToDraft: isMovedToDraft,
            endDate: endDate,
            venue: venue,
            customIdea: customIdea,
            themeIdea: themeIdea,
            coverImage: coverImage,
            inviteMessage: inviteMessage,
            updatedAt: updatedAt,
            shared: shared
        )
    }
}

// MARK: - SharedUser Entity (co-hosts from gRPC SharedUser)
/// Represents a co-host who has been invited to collaborate on an event
struct SharedUser: Identifiable, Codable, Hashable {
    var id: String { secret }  // Use secret as identifier since SharedUser doesn't have its own ID
    let name: String
    let accepted: Bool
    let userId: String?
    let secret: String
    var accessRole: AccessRole

    enum AccessRole: String, Codable, CaseIterable, Identifiable {
        case admin = "admin"
        case viewer = "viewer"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .admin: return "Admin"
            case .viewer: return "Viewer"
            }
        }
    }

    init(
        name: String,
        accepted: Bool = false,
        userId: String? = nil,
        secret: String = UUID().uuidString,
        accessRole: AccessRole = .admin
    ) {
        self.name = name
        self.accepted = accepted
        self.userId = userId
        self.secret = secret
        self.accessRole = accessRole
    }
}

// MARK: - JoinedUser Entity (subcollection under events - legacy Firestore)
/// Firestore path: events/{eventId}/joinedUser
struct JoinedUser: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var email: String
    var userId: String
    var isOwner: Bool
    var photoUrl: String?
    var accessRole: AccessRole
    var createAt: Date
    var updatedAt: Date?

    enum AccessRole: String, Codable {
        case owner = "owner"
        case editor = "editor"  // Maps to "Admin" in UI
        case viewer = "viewer"  // Maps to "Viewer" in UI
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        email: String,
        userId: String,
        isOwner: Bool = false,
        photoUrl: String? = nil,
        accessRole: AccessRole = .viewer,
        createAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.userId = userId
        self.isOwner = isOwner
        self.photoUrl = photoUrl
        self.accessRole = accessRole
        self.createAt = createAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Preview & Mock Data
extension Event {
    static let preview = Event(
        id: "event_123",
        name: "John's Birthday Bash",
        startDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
        eventType: .birthday,
        ownerId: "user_123",
        venue: "Central Park, New York",
        customIdea: "Tropical theme with luau decorations",
        inviteMessage: "You're invited to celebrate John's 30th birthday!"
    )

    static let mock = preview

    static let mockList: [Event] = [
        .mock,
        Event(
            id: "event_456",
            name: "Summer Wedding",
            startDate: Calendar.current.date(byAdding: .month, value: 2, to: Date())!,
            eventType: .wedding,
            ownerId: "user_123",
            venue: "Grand Ballroom"
        ),
        Event(
            id: "event_789",
            name: "Team Building",
            startDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())!,
            eventType: .corporate,
            ownerId: "user_123"
        )
    ]

    /// Returns the default cover image URL based on event type
    /// Uses type-specific covers from GCS bucket
    var defaultCoverImage: String {
        let baseUrl = AppConfig.shared.mediaSourceUrl

        guard let eventType = EventType(rawValue: eventTypeId) else {
            return "\(baseUrl)/event_covers/abstract_covers/background1.jpg"
        }

        switch eventType {
        case .birthday:
            return "\(baseUrl)/event_covers/birthday/img-1.webp"
        case .wedding:
            return "\(baseUrl)/event_covers/wedding_and_engagement/img-1.webp"
        case .corporate:
            return "\(baseUrl)/event_covers/business/img-1.webp"
        case .conference:
            return "\(baseUrl)/event_covers/business/img-3.webp"
        case .graduation:
            return "\(baseUrl)/event_covers/graduation/img-1.webp"
        case .anniversary:
            return "\(baseUrl)/event_covers/anniversary/img-1.webp"
        case .vacation:
            return "\(baseUrl)/event_covers/vacation/img-1.webp"
        case .babyShower:
            return "\(baseUrl)/event_covers/abstract_covers/background2.jpg"
        case .holiday:
            return "\(baseUrl)/event_covers/abstract_covers/background5.jpg"
        case .custom:
            return "\(baseUrl)/event_covers/collection/img-1.webp"
        }
    }

    /// Returns the cover image URL - uses custom cover if set, otherwise returns default
    var effectiveCoverImage: String {
        if let cover = coverImage, !cover.isEmpty {
            return cover
        }
        return defaultCoverImage
    }
}
