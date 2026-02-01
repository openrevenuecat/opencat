import Foundation

// MARK: - App Configuration
/// Manages app environment and configuration settings
public final class AppConfig {

    // MARK: - Environment

    public enum Environment: String {
        case development = "dev"
        case production = "prod"

        var displayName: String {
            switch self {
            case .development: return "Development"
            case .production: return "Production"
            }
        }
    }

    // MARK: - Singleton

    public static let shared = AppConfig()

    // MARK: - Properties

    #if DEBUG
    public let environment: Environment = .development
    #else
    public let environment: Environment = .production
    #endif

    public var isDevMode: Bool {
        environment == .development
    }

    // MARK: - gRPC Configuration

    /// Default local development hosts (tried in order)
    private let defaultLocalHosts = ["192.168.1.6", "192.168.68.55", "192.168.88.88", "192.168.1.3"]

    /// Dynamic gRPC host for development (reads from UserDefaults where LocalNetworkDiscoveryService saves it)
    /// In production, uses the static API domain
    public var grpcHost: String {
        switch environment {
        case .development:
            // Read active host from UserDefaults (set by LocalNetworkDiscoveryService)
            // This avoids MainActor isolation issues
            if let activeHost = UserDefaults.standard.string(forKey: "debug_local_network_active_host") {
                return activeHost
            }
            // Default fallback if discovery hasn't run yet
            return defaultLocalHosts.first ?? "192.168.88.88"
        case .production:
            return "api.rush-day.io"
        }
    }

    public var grpcPort: Int {
        switch environment {
        case .development:
            return 50051
        case .production:
            return 443
        }
    }

    public var grpcUseTLS: Bool {
        switch environment {
        case .development:
            return false
        case .production:
            return true
        }
    }

    /// Create gRPC configuration using current settings
    public func makeGRPCConfiguration() -> GRPCClientService.Configuration {
        GRPCClientService.Configuration(
            host: grpcHost,
            port: grpcPort,
            useTLS: grpcUseTLS
        )
    }

    // MARK: - Firebase Configuration

    /// Returns the actual Firebase project ID from the loaded GoogleService-Info.plist
    /// Note: In DEBUG mode we still use rush-day Firebase because rushday-dev doesn't have our bundle ID registered
    public var firebaseProjectId: String {
        // Always use rush-day until rushday-dev has our bundle ID registered
        return "rush-day-10e65"
    }

    // MARK: - Web App URLs

    public var webAppUrl: String {
        switch environment {
        case .development:
            return "https://dev.invitations.rush-day.io"
        case .production:
            return "https://invitations.rush-day.io"
        }
    }

    // MARK: - Media Storage

    /// Media source URL for event covers and other assets
    /// Note: This is different from the Firebase Storage bucket used for user uploads
    public var mediaSourceUrl: String {
        switch environment {
        case .development:
            return "https://storage.googleapis.com/rushday_dev_bucket"
        case .production:
            return "https://storage.googleapis.com/rushday_bucket"
        }
    }

    /// Firebase Storage bucket for user uploads (photos, covers, etc.)
    public var bucketName: String {
        return "rush-day-10e65.appspot.com"
    }

    /// Default fallback cover image URL when event cover is empty or fails to load
    /// Matches Flutter's Constants.defaultCoverUrl: "${appMediaSource}/event_covers/abstract_covers/background1.jpg"
    public var defaultCoverUrl: String {
        return "\(mediaSourceUrl)/event_covers/abstract_covers/background1.jpg"
    }

    // MARK: - Deep Link Domains

    /// Domains for Universal Links / Associated Domains
    public var deepLinkDomains: [String] {
        switch environment {
        case .development:
            // Include app.rush-day.io since we use prod OneLink for dev
            return ["rushday-dev.web.app", "dev.rushday.app", "rush-day-dev.onelink.me", "app.rush-day.io"]
        case .production:
            return ["rush-day.web.app", "rushday.app", "app.rush-day.io"]
        }
    }

    /// Primary deep link domain
    public var primaryDeepLinkDomain: String {
        deepLinkDomains.first ?? "rush-day.web.app"
    }

    /// Custom URL scheme for the app
    public let customURLScheme = "rushday"

    // MARK: - AppsFlyer Configuration

    /// AppsFlyer Dev Key for SDK initialization
    public var appsFlyerDevKey: String {
        // Using the same key for both environments as provided
        return "Z3XJNqoaQCzxARdKvv5BZM"
    }

    /// AppsFlyer Apple App ID (your App Store ID)
    public var appsFlyerAppleAppId: String {
        return "6477700116"
    }

    /// AppsFlyer OneLink domain for deep links
    public var oneLinkDomain: String {
        switch environment {
        case .development:
            return "rush-day-dev.onelink.me"
        case .production:
            return "app.rush-day.io"
        }
    }

    /// AppsFlyer App ID for OneLink URLs (template ID)
    public var appsFlyerOneLinkId: String {
        switch environment {
        case .development:
            return "zpWV/mbmfqyxv"
        case .production:
            return "FvEA/g30123jy"
        }
    }

    // MARK: - Notification Service

    public var notificationServiceUrl: String {
        // Always use production notification service because:
        // 1. iOS app uses rush-day Firebase (bundle ID not registered in rushday-dev)
        // 2. FCM tokens are registered with rush-day sender ID
        // 3. dev.notifications uses rushday-dev Firebase causing SenderId mismatch
        return "https://notifications.rush-day.io"
    }

    /// Base API URL for the notification service
    public var notificationApiUrl: String {
        return "\(notificationServiceUrl)/api"
    }

    // MARK: - OpenCat (Subscription Management)

    public var openCatServerUrl: String {
        return "http://localhost:8080"
    }

    public var openCatApiKey: String {
        return "ocat_rushday_dev_key"
    }

    // MARK: - Privacy & Terms URLs

    public let privacyPolicyUrl = "https://rushday.app/privacy"
    public let termsOfServiceUrl = "https://rushday.app/terms"

    // MARK: - App Info

    public var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    public var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    public var fullVersion: String {
        "\(appVersion) (\(buildNumber))"
    }

    // MARK: - Init

    private init() {}
}
