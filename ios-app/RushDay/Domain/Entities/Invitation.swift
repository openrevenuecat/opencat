import Foundation

// MARK: - Invitation Status
enum InvitationStatus: String, Codable, CaseIterable {
    case going = "going"
    case notGoing = "notGoing"

    var displayName: String {
        switch self {
        case .going: return "Going"
        case .notGoing: return "Not Going"
        }
    }

    /// Convert from RSVPStatus to InvitationStatus
    static func fromRSVPStatus(_ rsvpStatus: RSVPStatus) -> InvitationStatus? {
        switch rsvpStatus {
        case .confirmed: return .going
        case .declined: return .notGoing
        case .notInvited, .pending, .maybe: return nil
        }
    }
}

// MARK: - Invitation Entity
struct Invitation: Identifiable, Codable, Hashable {
    let id: String
    let guestId: String
    let userId: String
    let eventId: String
    let createdAt: Date
    var message: String?
    var templateName: String?
    var inviteStatus: InvitationStatus?
    var updatedAt: Date?

    init(
        id: String = UUID().uuidString,
        guestId: String,
        userId: String,
        eventId: String,
        createdAt: Date = Date(),
        message: String? = nil,
        templateName: String? = nil,
        inviteStatus: InvitationStatus? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.guestId = guestId
        self.userId = userId
        self.eventId = eventId
        self.createdAt = createdAt
        self.message = message
        self.templateName = templateName
        self.inviteStatus = inviteStatus
        self.updatedAt = updatedAt
    }
}

// MARK: - Invitation Preview Data
/// Data model for the invitation preview screen
struct InvitationPreviewData {
    var event: Event
    var owner: User
    var coverImage: String?
    var localCoverImage: Data?
    var message: String?

    init(
        event: Event,
        owner: User,
        coverImage: String? = nil,
        localCoverImage: Data? = nil,
        message: String? = nil
    ) {
        self.event = event
        self.owner = owner
        self.coverImage = coverImage ?? event.coverImage
        self.localCoverImage = localCoverImage
        self.message = message ?? event.inviteMessage
    }

    /// Check if there are unsaved changes
    func hasChanges() -> Bool {
        return event.coverImage != coverImage ||
               event.inviteMessage != message ||
               localCoverImage != nil
    }

    /// Create updated event with current preview data
    func updatedEvent() -> Event {
        var updated = event
        updated.coverImage = coverImage
        updated.inviteMessage = message
        return updated
    }
}

// MARK: - Mock Data
extension Invitation {
    static let mock = Invitation(
        id: "invitation_123",
        guestId: "guest_123",
        userId: "user_123",
        eventId: "event_123",
        message: "You're invited to celebrate with us!",
        inviteStatus: .going
    )

    static let mockList: [Invitation] = [
        .mock,
        Invitation(
            id: "invitation_456",
            guestId: "guest_456",
            userId: "user_456",
            eventId: "event_123",
            inviteStatus: .notGoing
        ),
        Invitation(
            id: "invitation_789",
            guestId: "guest_789",
            userId: "user_789",
            eventId: "event_123"
        )
    ]
}
