import Foundation
import Combine

// MARK: - DeepLinkType

/// Types of deep links the app can handle
enum DeepLinkType: Equatable {
    case invitation(id: String)         // Public guest invitation (legacy)
    case guest(id: String)              // Guest RSVP invitation
    case event(id: String)              // Direct event access (owner)
    case coHostInvite(secret: String)   // Co-host invitation with one-time secret token
    case debugScreen(name: String)      // Debug: Navigate to specific screen
    case unknown

    var analyticsName: String {
        switch self {
        case .invitation: return "invitation"
        case .guest: return "guest_invite"
        case .event: return "event"
        case .coHostInvite: return "co_host_invite"
        case .debugScreen: return "debug_screen"
        case .unknown: return "unknown"
        }
    }
}

// MARK: - DeepLinkService

/// Service for handling incoming deep links and Universal Links
final class DeepLinkService: ObservableObject {

    // MARK: - Singleton

    static let shared = DeepLinkService()

    // MARK: - Published Properties

    /// The current pending deep link to be handled
    @Published private(set) var pendingDeepLink: DeepLinkType?

    /// Whether the app was opened from a deep link
    @Published private(set) var isFromDeepLink: Bool = false

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {}

    // MARK: - URL Handling

    /// Handle an incoming URL (Universal Link or custom URL scheme)
    /// - Parameter url: The URL to handle
    /// - Returns: True if the URL was handled
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        // Try to parse the URL
        guard let deepLink = parseURL(url) else {
            return false
        }

        // Set the pending deep link
        pendingDeepLink = deepLink
        isFromDeepLink = true

        // Track analytics
        trackDeepLinkOpened(deepLink, url: url)

        return true
    }

    /// Handle user activity (for Universal Links via NSUserActivity)
    /// - Parameter userActivity: The user activity
    /// - Returns: True if the activity was handled
    @discardableResult
    func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        return handleURL(url)
    }

    /// Clear the pending deep link after it's been handled
    func clearPendingDeepLink() {
        pendingDeepLink = nil
        isFromDeepLink = false
    }

    // MARK: - URL Parsing

    /// Parse a URL into a DeepLinkType
    private func parseURL(_ url: URL) -> DeepLinkType? {
        let config = AppConfig.shared

        // Check if it's a valid deep link domain
        guard let host = url.host,
              config.deepLinkDomains.contains(host) || host == "rushday" else {
            // Check for custom URL scheme: rushday://
            if url.scheme == "rushday" {
                return parseCustomScheme(url)
            }
            return nil
        }

        // Parse path components
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // Handle different path patterns
        return parsePath(pathComponents, queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    }

    /// Parse custom URL scheme (rushday://)
    private func parseCustomScheme(_ url: URL) -> DeepLinkType? {
        guard let host = url.host else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        switch host {
        case "invitation":
            // rushday://invitation/{id}
            if let id = pathComponents.first {
                return .invitation(id: id)
            }
        case "guest":
            // rushday://guest?id={guestId}
            if let guestId = queryItems?.first(where: { $0.name == "id" })?.value {
                return .guest(id: guestId)
            }
            // rushday://guest/{id}
            if let id = pathComponents.first {
                return .guest(id: id)
            }
        case "event":
            // rushday://event/{id}
            if let id = pathComponents.first {
                return .event(id: id)
            }
        case "invite":
            // rushday://invite?secret={secret} (one-time token format)
            if let secret = queryItems?.first(where: { $0.name == "secret" })?.value {
                return .coHostInvite(secret: secret)
            }
        #if DEBUG
        case "debug", "screen", "test":
            // rushday://debug/{screenName} or rushday://screen/{screenName}
            // Supported screens: paywall, feature-paywall, onboarding, profile, settings
            if let screenName = pathComponents.first {
                return .debugScreen(name: screenName)
            }
            // rushday://debug?screen={screenName}
            if let screenName = queryItems?.first(where: { $0.name == "screen" })?.value {
                return .debugScreen(name: screenName)
            }
        #endif
        default:
            break
        }

        return .unknown
    }

    /// Parse URL path into DeepLinkType
    private func parsePath(_ pathComponents: [String], queryItems: [URLQueryItem]?) -> DeepLinkType? {
        guard !pathComponents.isEmpty else { return nil }

        let firstComponent = pathComponents[0]

        switch firstComponent {
        case "invitations":
            // /invitations/{base64EncodedData}
            // Flutter format: base64(invitationId/userId)
            if pathComponents.count >= 2 {
                let encodedData = pathComponents[1]
                if let decodedId = decodeInvitationData(encodedData) {
                    return .invitation(id: decodedId)
                }
                // Fallback: treat as raw ID
                return .invitation(id: encodedData)
            }

        case "invitation":
            // /invitation/{id}
            if pathComponents.count >= 2 {
                return .invitation(id: pathComponents[1])
            }

        case "event":
            // /event/{id}
            if pathComponents.count >= 2 {
                return .event(id: pathComponents[1])
            }

        case "invite":
            // /invite?secret={secret} (one-time token format)
            if let secret = queryItems?.first(where: { $0.name == "secret" })?.value {
                return .coHostInvite(secret: secret)
            }
            // Or /invite/{secret} (path-based)
            if pathComponents.count >= 2 {
                return .coHostInvite(secret: pathComponents[1])
            }

        case "guest":
            // /guest?id={guestId} (guest RSVP invite)
            if let guestId = queryItems?.first(where: { $0.name == "id" })?.value {
                return .guest(id: guestId)
            }
            // Or /guest/{guestId} (path-based)
            if pathComponents.count >= 2 {
                return .guest(id: pathComponents[1])
            }

        default:
            // Check query parameters for deep_link_value (AppsFlyer format)
            if let deepLinkValue = queryItems?.first(where: { $0.name == "deep_link_value" })?.value {
                return parseDeepLinkValue(deepLinkValue)
            }
        }

        return .unknown
    }

    /// Parse AppsFlyer deep_link_value format
    private func parseDeepLinkValue(_ value: String) -> DeepLinkType? {
        // Format: /invite?secret={secret} (co-host invite)
        if value.hasPrefix("/invite") {
            if let url = URL(string: "https://temp.com\(value)"),
               let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                // Extract secret parameter (one-time token)
                if let secret = queryItems.first(where: { $0.name == "secret" })?.value {
                    return .coHostInvite(secret: secret)
                }
            }
        }

        // Format: /guest?id={guestId} (guest RSVP invite)
        if value.hasPrefix("/guest") {
            if let url = URL(string: "https://temp.com\(value)"),
               let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                // Extract guest ID parameter
                if let guestId = queryItems.first(where: { $0.name == "id" })?.value {
                    return .guest(id: guestId)
                }
            }
        }

        // Assume it's a secret directly (legacy)
        return .coHostInvite(secret: value)
    }

    /// Decode base64 encoded invitation data (Flutter format: invitationId/userId)
    private func decodeInvitationData(_ encoded: String) -> String? {
        // Add padding if needed
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = base64.count % 4
        if padding > 0 {
            base64 += String(repeating: "=", count: 4 - padding)
        }

        guard let data = Data(base64Encoded: base64),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Format: invitationId/userId
        let components = decoded.split(separator: "/")
        if let invitationId = components.first {
            return String(invitationId)
        }

        return nil
    }

    // MARK: - Analytics

    private func trackDeepLinkOpened(_ deepLink: DeepLinkType, url: URL) {
        // Only log host + path, exclude query params to avoid logging secrets
        // and to stay within Firebase Analytics 100 char limit
        let urlPath = url.host.map { $0 + (url.path.isEmpty ? "" : url.path) } ?? url.path
        AnalyticsService.shared.logEvent("deep_link_opened", parameters: [
            "type": deepLink.analyticsName,
            "url_path": String(urlPath.prefix(100))
        ])
    }
}
