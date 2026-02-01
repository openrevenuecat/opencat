import Foundation

// MARK: - InvitationLinkGenerator

/// Helper for generating shareable invitation links
struct InvitationLinkGenerator {

    // MARK: - Link Types

    enum LinkType {
        /// Web URL that opens invitation in browser
        case web
        /// Universal Link that opens app directly
        case universal
    }

    // MARK: - Generate Invitation Link

    /// Generate a shareable link for an invitation
    /// - Parameters:
    ///   - invitationId: The invitation ID
    ///   - userId: The user ID (optional, for Flutter compatibility)
    ///   - type: The type of link to generate
    /// - Returns: The shareable URL string
    static func generateInvitationLink(
        invitationId: String,
        userId: String? = nil,
        type: LinkType = .web
    ) -> String {
        let config = AppConfig.shared

        switch type {
        case .web:
            // Generate web URL with base64 encoded data (Flutter compatible)
            let dataToEncode: String
            if let userId = userId {
                dataToEncode = "\(invitationId)/\(userId)"
            } else {
                dataToEncode = invitationId
            }

            let encodedData = base64URLEncode(dataToEncode)
            return "\(config.webAppUrl)/invitations/\(encodedData)"

        case .universal:
            // Generate Universal Link
            let domain = config.deepLinkDomains.first ?? "rushday.app"
            return "https://\(domain)/invitation/\(invitationId)"
        }
    }

    /// Generate a shareable link for an event (co-host invite)
    /// - Parameters:
    ///   - eventId: The event ID
    ///   - type: The type of link to generate
    /// - Returns: The shareable URL string
    static func generateEventInviteLink(
        eventId: String,
        type: LinkType = .universal
    ) -> String {
        let config = AppConfig.shared

        switch type {
        case .web:
            return "\(config.webAppUrl)/invite?eventId=\(eventId)"

        case .universal:
            let domain = config.deepLinkDomains.first ?? "rushday.app"
            return "https://\(domain)/invite?eventId=\(eventId)"
        }
    }

    /// Generate a direct event link
    /// - Parameter eventId: The event ID
    /// - Returns: The shareable URL string
    static func generateEventLink(eventId: String) -> String {
        let config = AppConfig.shared
        let domain = config.deepLinkDomains.first ?? "rushday.app"
        return "https://\(domain)/event/\(eventId)"
    }

    // MARK: - Base64 URL Encoding

    /// Encode string to base64 URL-safe format
    private static func base64URLEncode(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }

        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decode base64 URL-safe format to string
    static func base64URLDecode(_ encoded: String) -> String? {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding
        let padding = base64.count % 4
        if padding > 0 {
            base64 += String(repeating: "=", count: 4 - padding)
        }

        guard let data = Data(base64Encoded: base64),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }

        return decoded
    }
}

// MARK: - Invitation Extension

extension Rushday_V1_Invitation {

    /// Generate a shareable web link for this invitation
    var shareableLink: String {
        InvitationLinkGenerator.generateInvitationLink(
            invitationId: id,
            userId: userID,
            type: .web
        )
    }

    /// Generate a Universal Link for this invitation
    var universalLink: String {
        InvitationLinkGenerator.generateInvitationLink(
            invitationId: id,
            userId: userID,
            type: .universal
        )
    }
}

// MARK: - Event Extension

extension Event {

    /// Generate a shareable invite link for co-hosts
    var coHostInviteLink: String {
        InvitationLinkGenerator.generateEventInviteLink(eventId: id, type: .universal)
    }

    /// Generate a direct event link
    var eventLink: String {
        InvitationLinkGenerator.generateEventLink(eventId: id)
    }
}
