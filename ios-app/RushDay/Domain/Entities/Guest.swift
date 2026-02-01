import Foundation
import SwiftUI

enum RSVPStatus: String, Codable, CaseIterable {
    case notInvited = "not_invited"
    case pending = "pending"
    case confirmed = "confirmed"
    case declined = "declined"
    case maybe = "maybe"

    var displayName: String {
        switch self {
        case .notInvited: return "Not Invited"
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .declined: return "Declined"
        case .maybe: return "Maybe"
        }
    }

    var icon: String {
        switch self {
        case .notInvited: return "envelope.badge"
        case .pending: return "clock"
        case .confirmed: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notInvited: return .rdTextSecondary
        case .pending: return .rdWarning
        case .confirmed: return .rdSuccess
        case .declined: return .rdError
        case .maybe: return .rdPrimary
        }
    }
}

enum GuestRole: String, Codable, CaseIterable {
    case guest = "guest"
    case vip = "vip"
    case family = "family"
    case vendor = "vendor"

    var displayName: String {
        switch self {
        case .guest: return "Guest"
        case .vip: return "VIP"
        case .family: return "Family"
        case .vendor: return "Vendor"
        }
    }
}

struct Guest: Identifiable, Codable, Hashable {
    let id: String
    var eventId: String?  // Optional - may not be stored in subcollection documents
    var userId: String?
    var contactId: String?  // Device contact identifier for tracking imported contacts
    var name: String
    var email: String?
    var phoneNumber: String?
    var photoURL: String?
    var rsvpStatus: RSVPStatus
    var role: GuestRole
    var plusOnes: Int
    var dietaryRestrictions: [String]
    var notes: String?
    var inviteLink: String?  // Unique invitation link for this guest
    var invitedAt: Date
    var respondedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        eventId: String? = nil,
        userId: String? = nil,
        contactId: String? = nil,
        name: String,
        email: String? = nil,
        phoneNumber: String? = nil,
        photoURL: String? = nil,
        rsvpStatus: RSVPStatus = .pending,
        role: GuestRole = .guest,
        plusOnes: Int = 0,
        dietaryRestrictions: [String] = [],
        notes: String? = nil,
        inviteLink: String? = nil,
        invitedAt: Date = Date(),
        respondedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.userId = userId
        self.contactId = contactId
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.photoURL = photoURL
        self.rsvpStatus = rsvpStatus
        self.role = role
        self.plusOnes = plusOnes
        self.dietaryRestrictions = dietaryRestrictions
        self.notes = notes
        self.inviteLink = inviteLink
        self.invitedAt = invitedAt
        self.respondedAt = respondedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Generates a unique invite link for the guest
    /// Format matches Flutter: ${webAppUrl}/invitations/${base64(invitationId/userId)}
    /// - Parameters:
    ///   - invitationId: The invitation ID from backend
    ///   - ownerId: The event owner's user ID
    /// - Returns: The shareable invitation URL
    static func generateInviteLink(invitationId: String, ownerId: String) -> String {
        let config = AppConfig.shared
        let webAppUrl = config.webAppUrl

        // Base64 URL encode "invitationId/ownerId" (matches Flutter format)
        let dataToEncode = "\(invitationId)/\(ownerId)"
        let encodedData = base64URLEncode(dataToEncode)

        return "\(webAppUrl)/invitations/\(encodedData)"
    }

    /// Legacy method - generates link with just guest ID (deprecated)
    /// Use generateInviteLink(invitationId:ownerId:) instead
    static func generateInviteLink(id: String) -> String {
        let config = AppConfig.shared
        let webAppUrl = config.webAppUrl

        // Fallback: just encode the guest ID
        let encodedData = base64URLEncode(id)
        return "\(webAppUrl)/invitations/\(encodedData)"
    }

    /// Base64 URL encode a string (URL-safe variant)
    private static func base64URLEncode(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }

        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    var totalAttending: Int {
        rsvpStatus == .confirmed ? 1 + plusOnes : 0
    }
}

extension Guest {
    static let mock = Guest(
        id: "guest_123",
        eventId: "event_123",
        name: "Jane Smith",
        email: "jane@example.com",
        rsvpStatus: .confirmed,
        plusOnes: 1
    )

    static let mockList: [Guest] = [
        .mock,
        Guest(
            id: "guest_456",
            eventId: "event_123",
            name: "Bob Johnson",
            email: "bob@example.com",
            rsvpStatus: .pending
        ),
        Guest(
            id: "guest_789",
            eventId: "event_123",
            name: "Alice Williams",
            email: "alice@example.com",
            rsvpStatus: .declined
        ),
        Guest(
            id: "guest_012",
            eventId: "event_123",
            name: "Charlie Brown",
            email: "charlie@example.com",
            rsvpStatus: .maybe,
            plusOnes: 2
        )
    ]
}
