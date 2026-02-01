import Foundation

/// Guest invitation entity for RSVP links
/// Stored in Firestore at: users/{userId}/invitations/{invitationId}
/// Matches Flutter's InvitationModel for compatibility with web viewer
struct GuestInvitation: Codable, Identifiable {
    var id: String?
    let guestId: String
    let userId: String      // Event owner's user ID
    let eventId: String
    var message: String?
    var templateName: String?
    var inviteStatus: String?
    var createAt: Date?
    var updatedAt: Date?

    init(
        id: String? = nil,
        guestId: String,
        userId: String,
        eventId: String,
        message: String? = nil,
        templateName: String? = nil,
        inviteStatus: String? = nil,
        createAt: Date? = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.guestId = guestId
        self.userId = userId
        self.eventId = eventId
        self.message = message
        self.templateName = templateName
        self.inviteStatus = inviteStatus
        self.createAt = createAt
        self.updatedAt = updatedAt
    }

    /// Generate the shareable invite link for this invitation
    /// Format: ${webAppUrl}/invitations/${base64(invitationId/userId)}
    func generateInviteLink() -> String? {
        guard let invitationId = id else { return nil }
        return Guest.generateInviteLink(invitationId: invitationId, ownerId: userId)
    }
}
